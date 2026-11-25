#!/usr/bin/env python3
"""Exercise public TextInput native sessions through a real POSIX PTY.

Every scenario in this harness launches the fixture through its explicit
`public-` route, so a passing scenario is public theme-instance lifecycle
evidence: the prompt is created through exported theme instances over
`TerminalEnvironment.nativeThemeDefault`, never through the internal
compatibility seam. Scenario output names identify both the route and the
behavior, for example `public-route/resize: PASS`.

Failure diagnostics are phase-annotated and persisted to an artifact
directory (env `PTY_ARTIFACT_DIR`, or a fresh temporary directory) so a CI
operator can distinguish product defects from harness or environment failure
without rerunning blindly. Artifacts are written only on failure.
"""
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
import tempfile
import termios
import time

# Darwin's tty layer owns PENDIN in c_lflag. Re-enabling ICANON through
# tcsetattr -- exactly what a prompt does when it restores the state it
# received -- makes the kernel OR that bit into its own copy of the flags:
# `tp->t_lflag = t->c_lflag | ISSET(tp->t_lflag, PENDIN)` in bsd/kern/tty.c.
# A later tcgetattr therefore reports one extra flag even though the
# application wrote back the exact bytes it captured, and userland cannot
# clear it while ICANON is being re-enabled; the kernel clears it on the next
# input read or flush. Linux has no equivalent flag. Only this kernel-owned
# bit is excluded from the restoration comparison.
KERNEL_PENDING_LFLAG = 0x20000000
# iflag, oflag, cflag, lflag, ispeed, ospeed, control characters.
LFLAG_INDEX = 3


def user_state(attributes):
    """The terminal state the application is responsible for restoring."""
    if sys.platform != 'darwin':
        return attributes
    state = list(attributes)
    state[LFLAG_INDEX] &= ~KERNEL_PENDING_LFLAG
    return state


class Resize:
    """A window change delivered between two input steps."""

    def __init__(self, columns, rows):
        self.columns = columns
        self.rows = rows


def set_geometry(descriptor, columns, rows):
    fcntl.ioctl(
        descriptor, termios.TIOCSWINSZ,
        struct.pack('HHHH', rows, columns, 0, 0),
    )


def stop(process):
    """Stop the launched command and any process it started."""
    if process.poll() is not None:
        return
    for sent in (signal.SIGTERM, signal.SIGKILL):
        try:
            # The child leads its own process group, so this also stops a VM
            # child that outlived its launcher.
            os.killpg(process.pid, sent)
        except (ProcessLookupError, PermissionError):
            return
        try:
            process.wait(timeout=5)
            return
        except subprocess.TimeoutExpired:
            continue


class Failure(Exception):
    """A phase-annotated scenario failure."""

    def __init__(self, scenario, phase, message):
        super().__init__(message)
        self.scenario = scenario
        self.phase = phase


def write_artifacts(directory, scenario, phase, transcript, stdout,
                    returncode, before, after, error):
    """Persist failure evidence and return the artifact directory path."""
    os.makedirs(directory, exist_ok=True)
    prefix = os.path.join(directory, scenario)
    with open(prefix + '-transcript.bin', 'wb') as stream:
        stream.write(bytes(transcript))
    if stdout is not None:
        with open(prefix + '-stdout.bin', 'wb') as stream:
            stream.write(stdout)
    with open(prefix + '-detail.txt', 'w') as stream:
        stream.write(
            f'scenario={scenario}\n'
            f'phase={phase}\n'
            f'returncode={returncode}\n'
            f'termios-before={before!r}\n'
            f'termios-after={after!r}\n'
            f'error={error}\n'
        )
    return directory


def run(scenario, behavior, inputs, expected, term=None, use_trigger=False,
        artifact_dir=None):
    """Run one explicitly public scenario.

    `scenario` is the fixture argument including the `public-` prefix;
    `behavior` is the behavioral name used in evidence output, so every line
    identifies both the route and the behavior it proves.
    """
    label = f'public-route/{behavior}'
    master, slave = pty.openpty()
    # A fresh PTY commonly has zero geometry. Configure the real terminal;
    # rich prompts correctly refuse an output with no measurable viewport.
    set_geometry(slave, 80, 24)
    before = termios.tcgetattr(slave)
    trigger_path = None
    if use_trigger:
        trigger_path = os.path.join(
            tempfile.mkdtemp(prefix='posix-pty-trigger-'), 'trigger')
    command = ['dart', 'run', 'test/text_input_native_app.dart', scenario]
    if trigger_path is not None:
        command.append(trigger_path)
    process = subprocess.Popen(
        command,
        stdin=slave, stderr=slave, stdout=subprocess.PIPE,
        env={**os.environ, 'TERM': term or 'xterm'},
        # The launched command is not necessarily the process that owns the
        # prompt: `dart` runs the script in a child VM process (observed as
        # dart.exe -> dartvm.exe). Giving the child its own process group lets
        # an external interrupt address the application the way a terminal
        # does, instead of only the launcher. It also keeps a group signal away
        # from this harness and its CI shell.
        start_new_session=True,
    )
    transcript = bytearray()
    terminal_output = bytearray()
    stdout = None
    phase = 'startup'
    signalled = False
    started = time.monotonic()

    def fail(phase_name, message):
        error = Failure(scenario, phase_name, message)
        artifact = write_artifacts(
            artifact_dir or tempfile.mkdtemp(prefix='posix-pty-artifacts-'),
            scenario, phase_name, terminal_output, stdout,
            process.poll(), before,
            termios.tcgetattr(slave), error,
        )
        raise Failure(
            scenario, phase_name,
            f'{label}: phase={phase_name} '
            f'elapsed={time.monotonic() - started:.1f}s {message} '
            f'(artifacts: {artifact})',
        )

    def drain(timeout=0.0):
        while select.select([master], [], [], timeout)[0]:
            chunk = os.read(master, 65536)
            transcript.extend(chunk)
            terminal_output.extend(chunk)
            timeout = 0.0

    try:
        for prompt, data in inputs:
            phase = f'awaiting prompt paint {prompt!r}'
            deadline = time.monotonic() + 30
            while prompt not in transcript:
                if process.poll() is not None:
                    stdout, _ = process.communicate()
                    fail(phase, f'process exited before {prompt!r}: '
                                f'stdout={stdout!r}, '
                                f'terminal={bytes(terminal_output)!r}')
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    fail(phase, f'timed out waiting for {prompt!r}: '
                                f'{bytes(terminal_output)!r}')
                drain(min(remaining, 0.1))
            transcript.clear()
            phase = f'sending input after {prompt!r}'
            if isinstance(data, Resize):
                # A terminal emulator resizing its window sets the PTY geometry
                # and the kernel then signals the foreground process group. This
                # harness owns the PTY and the child is not a session leader with
                # a controlling terminal, so the same notification is delivered
                # explicitly; the prompt still reads the geometry itself.
                set_geometry(slave, data.columns, data.rows)
                os.killpg(process.pid, signal.SIGWINCH)
                continue
            if data is None:
                signalled = True
                os.killpg(process.pid, signal.SIGINT)
            else:
                os.write(master, data)
        if trigger_path is not None:
            # The fixture parks its prompt on the native read and waits for
            # this file before injecting the shared-writer failure. Releasing
            # it only after the PTY line discipline visibly changed proves the
            # console was genuinely acquired while the failure lands, rather
            # than the failure racing the opening paint.
            phase = 'awaiting console acquisition'
            deadline = time.monotonic() + 30
            while user_state(termios.tcgetattr(slave)) == user_state(before):
                if process.poll() is not None:
                    stdout, _ = process.communicate()
                    fail(phase, 'process exited before acquiring the console: '
                                f'stdout={stdout!r}, '
                                f'terminal={bytes(terminal_output)!r}')
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    fail(phase, 'console state never left the baseline: '
                                f'{bytes(terminal_output)!r}')
                drain(min(remaining, 0.1))
            with open(trigger_path, 'w') as stream:
                stream.write('go')
        phase = 'process completion'
        try:
            stdout, _ = process.communicate(timeout=30)
        except subprocess.TimeoutExpired:
            fail(phase, 'process did not exit within 30 seconds: '
                        f'terminal={bytes(terminal_output)!r}')
        drain()
        after = termios.tcgetattr(slave)
        phase = 'result comparison'
        # A group interrupt can also reach the launcher, which may exit with
        # the signal status while the application handles the interrupt and
        # prints its own result. A process that failed to handle the interrupt
        # prints nothing, so the printed result stays the real assertion.
        statuses = {0, -signal.SIGINT} if signalled else {0}
        if (process.returncode not in statuses
                or stdout.decode().strip() != expected):
            fail(phase, f'exit={process.returncode}, stdout={stdout!r}, '
                        f'expected={expected!r}, '
                        f'terminal={bytes(terminal_output)!r}')
        if term == 'dumb' and b'\x1b' in terminal_output:
            fail(phase, 'unexpected escape sequence: '
                        f'{bytes(terminal_output)!r}')
        phase = 'terminal restoration'
        if user_state(before) != user_state(after):
            fail(phase, f'terminal attributes not restored: '
                        f'{before!r} -> {after!r}')
        print(f'{label}: PASS ({expected})')
    except Failure:
        raise
    except Exception as error:
        fail(phase, f'harness error: {error!r}')
    finally:
        stop(process)
        os.close(master)
        os.close(slave)


def main():
    scenarios = [
        # (behavior, inputs, expected, term, use_trigger)
        ('rich', [(b'Name', b'\r')], 'alpha', None, False),
        ('escape', [(b'Name', b'\x1b')], 'cancel', None, False),
        ('interrupt', [(b'Name', b'\x03')], 'interrupt', None, False),
        # An external interrupt is only meaningful once the prompt is reading
        # input: the native reader installs its SIGINT watcher when it starts
        # listening, which happens after the opening frame paints. Typing and
        # waiting for the echoed draft proves the reader is live, so the
        # signal cannot race the opening.
        ('signal', [(b'Name', b'qx'), (b'alphaqx', None)], 'interrupt',
         None, False),
        ('eof', [(b'Name', b'\x04')], 'eof', None, False),
        ('error', [(b'Failure', b'\r'), (b'Name', b'\r')], 'alpha',
         None, False),
        # The public repeat route prompts twice through one reusable prompt
        # and then reacquires through a second exported theme, so the harness
        # completes all three prompts; the fixture prints the first pair.
        (
            'repeat',
            [(b'Name', b'\r'), (b'Name', b'\r'), (b'Name', b'\r')],
            'alpha,alpha', None, False,
        ),
        # An idle prompt must reflow on a window change alone: no key is sent
        # between the resize and the repaint. The draft is wide enough to fit at
        # 80 columns and to need an overflow marker once the PTY is 30 wide.
        (
            'resize',
            [(b'Name', Resize(30, 12)), (b'> <', b'\r')],
            '0123456789' * 6, None, False,
        ),
        # A session-owned reader over the real console must end an idle prompt
        # when its shared writer fails, without waiting for a keystroke. The
        # harness releases the injected failure only after the acquired
        # console state is observed, so retirement cannot race acquisition.
        ('session-retire', [], 'retired', None, True),
        ('dumb-auto', [(b'Name', b'\r')], 'alpha', 'dumb', False),
        (
            'dumb-rich', [],
            'unavailable:Rich interaction is unavailable on the selected '
            'output.', 'dumb', False,
        ),
    ]
    artifact_dir = os.environ.get('PTY_ARTIFACT_DIR')
    failures = []
    for behavior, inputs, expected, term, use_trigger in scenarios:
        scenario = 'public-' + behavior
        try:
            run(scenario, behavior, inputs, expected, term=term,
                use_trigger=use_trigger, artifact_dir=artifact_dir)
        except Failure as error:
            print(error)
            failures.append(behavior)
    if failures:
        sys.exit(f'public lifecycle scenarios failed: {failures}')


if __name__ == '__main__':
    if os.name != 'posix':
        sys.exit('POSIX PTY required')
    main()
