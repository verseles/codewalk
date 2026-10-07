"""Fixed private Serve route; controller EOF/lease always stops and reaps its child."""
import json
import os
import select
import signal
import subprocess
import sys
import time

ARGV = ['/usr/bin/tailscale', 'serve', '--https=8443', 'http://127.0.0.1:45130']
ENV = {'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'}


def emit(report):
    try:
        print(json.dumps(report), flush=True)
    except BrokenPipeError:
        pass


def supervise(argv, control_fd, *, lease=10, lifetime=180, grace=3):
    child = None
    reason = 'error'
    previous = {}
    stopping = False

    def interrupted(*_):
        nonlocal stopping
        stopping = True

    for sig in [signal.SIGTERM, signal.SIGHUP, signal.SIGINT]:
        previous[sig] = signal.signal(sig, interrupted)
    try:
        child = subprocess.Popen(argv, cwd='/', env=ENV, stdin=subprocess.DEVNULL,
                                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                 start_new_session=True)
        emit({'event': 'started', 'pid': child.pid, 'uid': os.geteuid()})
        started = heartbeat = time.monotonic()
        while True:
            now = time.monotonic()
            if stopping:
                reason = 'signal'
                break
            if child.poll() is not None:
                reason = 'child-exit'
                break
            if now - started >= lifetime:
                reason = 'deadline'
                break
            if now - heartbeat >= lease:
                reason = 'lease'
                break
            readable, _, _ = select.select([control_fd], [], [],
                                            min(.2, lifetime - (now - started), lease - (now - heartbeat)))
            if readable:
                data = os.read(control_fd, 128)
                if not data or b'q' in data:
                    reason = 'stop' if data else 'eof'
                    break
                if data.strip(b'.'):
                    reason = 'invalid-control'
                    break
                heartbeat = time.monotonic()
    finally:
        if child is not None:
            if child.poll() is None:
                try:
                    os.killpg(child.pid, signal.SIGTERM)
                except ProcessLookupError:
                    pass
                try:
                    child.wait(timeout=grace)
                except subprocess.TimeoutExpired:
                    os.killpg(child.pid, signal.SIGKILL)
                    child.wait(timeout=2)
            # wait/poll reaps the direct owned child even on early CLI failure.
            code = child.wait(timeout=2)
            emit({'event': 'stopped', 'pid': child.pid, 'childReaped': True,
                  'exitCode': code, 'reason': reason})
        for sig, handler in previous.items():
            signal.signal(sig, handler)


if __name__ == '__main__':
    if len(sys.argv) != 1 or os.geteuid() != 0:
        sys.exit(2)
    supervise(ARGV, sys.stdin.fileno())
