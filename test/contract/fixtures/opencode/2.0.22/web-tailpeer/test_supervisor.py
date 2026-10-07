"""Real local disposable processes only; no sudo, Tailscale, browser or SSH."""
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import sys
import time
import unittest


class SupervisorTests(unittest.TestCase):
    def run_case(self, action, reason, *, command=None, lease=1, lifetime=3):
        command = command or [sys.executable, '-c', 'import time; time.sleep(30)']
        code = ('from serve_supervisor import supervise; '
                f'supervise({command!r}, 0, lease={lease}, lifetime={lifetime}, grace=.2)')
        process = subprocess.Popen([sys.executable, '-B', '-c', code],
                                   cwd=Path(__file__).parent, stdin=subprocess.PIPE,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        child_pid = None
        try:
            self.assertTrue(select.select([process.stdout], [], [], 3)[0])
            started = json.loads(process.stdout.readline())
            child_pid = started['pid']
            self.assertEqual(started['event'], 'started')
            self.assertEqual(started['uid'], os.geteuid())
            action(process)
            process.wait(timeout=5)
            stopped = json.loads(process.stdout.read())
            self.assertEqual(process.returncode, 0, process.stderr.read().decode())
            self.assertEqual(stopped['reason'], reason)
            self.assertTrue(stopped['childReaped'])
            self.assertEqual(stopped['pid'], child_pid)
            self.assertFalse(Path(f'/proc/{child_pid}').exists())
            return stopped
        finally:
            if process.poll() is None:
                process.stdin.close()
                process.wait(timeout=5)
            for pipe in [process.stdin, process.stdout, process.stderr]:
                pipe.close()

    def test_explicit_stop(self):
        self.run_case(lambda p: (p.stdin.write(b'q'), p.stdin.flush()), 'stop')

    def test_controller_eof(self):
        self.run_case(lambda p: p.stdin.close(), 'eof')

    def test_missing_heartbeat(self):
        self.run_case(lambda p: None, 'lease', lease=.3)

    def test_absolute_deadline_despite_heartbeat(self):
        def beats(p):
            while p.poll() is None:
                try:
                    p.stdin.write(b'.')
                    p.stdin.flush()
                except BrokenPipeError:
                    break
                time.sleep(.05)
        self.run_case(beats, 'deadline', lease=1, lifetime=.4)

    def test_supervisor_signal(self):
        self.run_case(lambda p: p.send_signal(signal.SIGTERM), 'signal')

    def test_child_early_exit(self):
        stopped = self.run_case(lambda p: None, 'child-exit', command=['/bin/sh', '-c', 'exit 7'])
        self.assertEqual(stopped['exitCode'], 7)

    def test_term_ignored_escalates_and_reaps(self):
        stopped = self.run_case(lambda p: time.sleep(.2), 'lease', lease=.4,
                                command=['/bin/sh', '-c', 'trap "" TERM; exec sleep 30'])
        self.assertEqual(stopped['exitCode'], -signal.SIGKILL)

    def test_invalid_control_stops_child(self):
        self.run_case(lambda p: (p.stdin.write(b'x'), p.stdin.flush()), 'invalid-control')


if __name__ == '__main__':
    unittest.main()
