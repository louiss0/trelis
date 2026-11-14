#!/usr/bin/env python3
"""Exercise public TextInput native sessions through a real POSIX PTY."""
import fcntl
import os
import pty
import select
import signal
import struct
import subprocess
import sys
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


def run(scenario, inputs, expected, term=None):
    master, slave = pty.openpty()
    # A fresh PTY commonly has zero geometry. Configure the real terminal;
    # rich prompts correctly refuse an output with no measurable viewport.
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack('HHHH', 24, 80, 0, 0))
    before = termios.tcgetattr(slave)
    process = subprocess.Popen(
        ['dart', 'run', 'test/text_input_native_app.dart', scenario],
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
    signalled = False
    try:
        for prompt, data in inputs:
            deadline = time.monotonic() + 30
            while prompt not in transcript:
                if process.poll() is not None:
                    stdout, _ = process.communicate()
                    raise AssertionError(f'{scenario}: process exited before {prompt!r}: stdout={stdout!r}, terminal={bytes(terminal_output)!r}')
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise AssertionError(f'timed out waiting for {prompt!r}: {bytes(terminal_output)!r}')
                if select.select([master], [], [], min(remaining, 0.1))[0]:
                    chunk = os.read(master, 65536)
                    transcript.extend(chunk)
                    terminal_output.extend(chunk)
            transcript.clear()
            if data is None:
                signalled = True
                os.killpg(process.pid, signal.SIGINT)
            else:
                os.write(master, data)
        stdout, _ = process.communicate(timeout=30)
        while select.select([master], [], [], 0)[0]:
            terminal_output.extend(os.read(master, 65536))
        after = termios.tcgetattr(slave)
        # A group interrupt can also reach the launcher, which may exit with
        # the signal status while the application handles the interrupt and
        # prints its own result. A process that failed to handle the interrupt
        # prints nothing, so the printed result stays the real assertion.
        statuses = {0, -signal.SIGINT} if signalled else {0}
        if (process.returncode not in statuses
                or stdout.decode().strip() != expected):
            raise AssertionError(f'{scenario}: exit={process.returncode}, stdout={stdout!r}, terminal={bytes(terminal_output)!r}')
        if term == 'dumb' and b'\x1b' in terminal_output:
            raise AssertionError(f'{scenario}: unexpected escape sequence: {bytes(terminal_output)!r}')
        if user_state(before) != user_state(after):
            raise AssertionError(f'{scenario}: terminal attributes not restored: {before!r} -> {after!r}')
        print(f'{scenario}: PASS ({expected})')
    finally:
        stop(process)
        os.close(master)
        os.close(slave)


def main():
    for scenario, inputs, expected in [
        ('rich', [(b'Name', b'\r')], 'alpha'),
        ('escape', [(b'Name', b'\x1b')], 'cancel'),
        ('interrupt', [(b'Name', b'\x03')], 'interrupt'),
        # An external interrupt is only meaningful once the prompt is reading
        # input: the native reader installs its SIGINT watcher when it starts
        # listening, which happens after the opening frame paints. Typing and
        # waiting for the echoed draft proves the reader is live, so the
        # signal cannot race the opening.
        ('signal', [(b'Name', b'qx'), (b'alphaqx', None)], 'interrupt'),
        ('eof', [(b'Name', b'\x04')], 'eof'),
        ('error', [(b'Failure', b'\r'), (b'Name', b'\r')], 'alpha'),
        ('repeat', [(b'Name', b'\r'), (b'Name', b'\r')], 'alpha,alpha'),
        # A session-owned reader over the real console must end an idle prompt
        # when its shared writer fails, without waiting for a keystroke.
        ('session-retire', [], 'retired'),
    ]:
        run(scenario, inputs, expected)
    run('dumb-auto', [(b'Name', b'\r')], 'alpha', term='dumb')
    run('dumb-rich', [], 'unavailable:Rich interaction unavailable on the selected output; use linear or automatic mode.', term='dumb')


if __name__ == '__main__':
    if os.name != 'posix':
        sys.exit('POSIX PTY required')
    main()
