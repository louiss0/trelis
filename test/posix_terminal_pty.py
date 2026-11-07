#!/usr/bin/env python3
"""Exercise public TextInput native sessions through a real POSIX PTY."""
import os
import pty
import select
import signal
import subprocess
import sys
import termios
import time


def run(scenario, inputs, expected, term=None):
    master, slave = pty.openpty()
    before = termios.tcgetattr(slave)
    process = subprocess.Popen(
        ['dart', 'run', 'test/text_input_native_app.dart', scenario],
        stdin=slave, stderr=slave, stdout=subprocess.PIPE,
        env={**os.environ, 'TERM': term or 'xterm'},
    )
    transcript = bytearray()
    terminal_output = bytearray()
    try:
        for prompt, data in inputs:
            deadline = time.monotonic() + 30
            while prompt not in transcript:
                if process.poll() is not None:
                    raise AssertionError(f'process exited before {prompt!r}: {transcript!r}')
                remaining = deadline - time.monotonic()
                if remaining <= 0:
                    raise AssertionError(f'timed out waiting for {prompt!r}: {transcript!r}')
                if select.select([master], [], [], min(remaining, 0.1))[0]:
                    chunk = os.read(master, 65536)
                    transcript.extend(chunk)
                    terminal_output.extend(chunk)
            transcript.clear()
            if data is None:
                os.kill(process.pid, signal.SIGINT)
            else:
                os.write(master, data)
        stdout, _ = process.communicate(timeout=30)
        while select.select([master], [], [], 0)[0]:
            terminal_output.extend(os.read(master, 65536))
        after = termios.tcgetattr(slave)
        if process.returncode != 0 or stdout.decode().strip() != expected:
            raise AssertionError(f'{scenario}: exit={process.returncode}, stdout={stdout!r}, terminal={transcript!r}')
        if term == 'dumb' and b'\x1b' in terminal_output:
            raise AssertionError(f'{scenario}: unexpected escape sequence: {terminal_output!r}')
        if before != after:
            raise AssertionError(f'{scenario}: terminal attributes not restored: {before!r} -> {after!r}')
        print(f'{scenario}: PASS ({expected})')
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        os.close(master)
        os.close(slave)


def main():
    for scenario, inputs, expected in [
        ('rich', [(b'Name', b'\r')], 'alpha'),
        ('escape', [(b'Name', b'\x1b')], 'cancel'),
        ('interrupt', [(b'Name', b'\x03')], 'interrupt'),
        ('signal', [(b'Name', None)], 'interrupt'),
        ('eof', [(b'Name', b'\x04')], 'eof'),
        ('error', [(b'Failure', b'\r'), (b'Name', b'\r')], 'alpha'),
        ('repeat', [(b'Name', b'\r'), (b'Name', b'\r')], 'alpha,alpha'),
    ]:
        run(scenario, inputs, expected)
    run('dumb-auto', [(b'Name', b'\r')], 'alpha', term='dumb')
    run('dumb-rich', [], 'unavailable:Rich interaction unavailable on the selected output; use linear or automatic mode.', term='dumb')


if __name__ == '__main__':
    if os.name != 'posix':
        sys.exit('POSIX PTY required')
    main()
