"""Owned remote processes and guarded control API. Protocol never logs credentials."""
import copy
import hashlib
import http.client
import json
import os
from pathlib import Path
import re
import secrets
import select
import signal
import shutil
import socket
import subprocess
import sys
import time
import threading

BINARY_SHA = 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815'
IP = '100.123.123.3'
ORIGIN = 'https://coolify.uaru-nase.ts.net:8443'
BASE = 'http://' + IP + ':45131'
root: Path
children = []
native = None
static = None
static_exe = None
static_sha = None
cleanup_end = None
session_id = None
pty_id = None
pty_pid = None
pty_birth = None
pty_attempted = False
authorization = ''
serve = None
foreground_id = None
phase = 'preflight'
baseline = None
calls = []


class ServeController:
    """No unprivileged signals to root: the supervisor owns termination/reaping."""
    def __init__(self):
        self.process = subprocess.Popen(
            ['/usr/bin/sudo', '-n', '/usr/bin/python3', '-I', '-S', str(root / 'serve_supervisor.py')],
            cwd='/', env={'PATH': '/usr/bin:/bin', 'LANG': 'C.UTF-8'},
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
            start_new_session=True)
        self.buffer = b''
        self.started = None
        self.finished = threading.Event()
        os.set_blocking(self.process.stdin.fileno(), False)
        self.thread = threading.Thread(target=self.heartbeat, daemon=True)
        self.thread.start()

    def heartbeat(self):
        while not self.finished.is_set():
            try:
                os.write(self.process.stdin.fileno(), b'.')
            except (OSError, ValueError):
                return
            self.finished.wait(1)

    def receive(self, end):
        while b'\n' not in self.buffer:
            left = end - time.monotonic()
            assert left > 0, 'supervisor response timeout'
            readable, _, _ = select.select([self.process.stdout], [], [], left)
            assert readable, 'supervisor response timeout'
            part = os.read(self.process.stdout.fileno(), 4096)
            assert part, 'supervisor response EOF'
            self.buffer += part
            assert len(self.buffer) <= 8192, 'supervisor response oversized'
        line, self.buffer = self.buffer.split(b'\n', 1)
        return json.loads(line)

    def ready(self):
        self.started = self.receive(time.monotonic() + 10)
        assert self.started['event'] == 'started' and self.started['uid'] == 0
        assert type(self.started['pid']) is int and self.started['pid'] > 0

    def poll(self):
        return self.process.poll()

    def stop(self):
        self.finished.set()
        self.thread.join(timeout=1)
        try:
            os.write(self.process.stdin.fileno(), b'q')
        except (OSError, ValueError):
            pass
        self.process.stdin.close()
        end = time.monotonic() + timeout(15)
        # Startup may fail before ready() consumed its first record.
        report = self.receive(end)
        if report.get('event') == 'started':
            self.started = report
            report = self.receive(end)
        assert report['event'] == 'stopped' and report['childReaped'] is True
        assert self.started and report['pid'] == self.started['pid']
        assert self.process.wait(timeout=max(.01, end - time.monotonic())) == 0
        self.process.stdout.close()
        return report


def foreground_config():
    return {'TCP': {'8443': {'HTTPS': True}},
            'Web': {ORIGIN.removeprefix('https://'): {
                'Handlers': {'/': {'Proxy': 'http://127.0.0.1:45130'}}}}}


def route_free(status):
    foreground = status.get('Foreground', {})
    assert isinstance(foreground, dict), 'invalid foreground map'
    for config in [status, *foreground.values()]:
        assert isinstance(config, dict), 'invalid Serve configuration'
        assert '8443' not in config.get('TCP', {}), 'Serve port already configured'
        assert ORIGIN.removeprefix('https://') not in config.get('Web', {}), 'Serve origin already configured'


def admit_foreground(before, after):
    if after == before:
        return None
    previous = before.get('Foreground', {})
    current = after.get('Foreground', {})
    assert isinstance(previous, dict) and isinstance(current, dict), 'invalid foreground map'
    added = set(current) - set(previous)
    assert len(added) == 1, 'expected one new foreground session'
    identifier = added.pop()
    assert isinstance(identifier, str) and 0 < len(identifier) <= 256
    assert current[identifier] == foreground_config(), 'unexpected foreground configuration'
    remaining = copy.deepcopy(after)
    del remaining['Foreground'][identifier]
    if 'Foreground' not in before and not remaining['Foreground']:
        del remaining['Foreground']
    assert remaining == before, 'Serve baseline changed'
    return identifier


def wait_foreground(process, before):
    end = time.monotonic() + 15
    while True:
        assert process.poll() is None, 'foreground process exited'
        identifier = admit_foreground(before, serve_status())
        if identifier:
            assert process.poll() is None, 'foreground process exited'
            return identifier
        assert time.monotonic() < end, 'foreground admission timeout'
        time.sleep(.1)


def wait_baseline(before):
    end = time.monotonic() + timeout(5)
    while serve_status() != before:
        assert time.monotonic() < end, 'Serve baseline not restored'
        time.sleep(.1)


def sha(path):
    with open(path, 'rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def serve_status():
    return json.loads(subprocess.run(['tailscale', 'serve', 'status', '--json'],
                      check=True, capture_output=True, text=True, timeout=timeout(3 if cleanup_end else 10)).stdout)


def timeout(cap):
    if cleanup_end is None:
        return cap
    left = cleanup_end - time.monotonic()
    if left <= 0:
        raise TimeoutError('remote cleanup deadline')
    return min(cap, left)


def listener_owned(process, ip, port, executable, expected_sha):
    assert process is not None and process.poll() is None, 'owned process exited'
    assert os.readlink(f'/proc/{process.pid}/exe') == executable
    assert sha(f'/proc/{process.pid}/exe') == expected_sha
    links = set()
    for fd in Path(f'/proc/{process.pid}/fd').iterdir():
        try:
            links.add(os.readlink(fd))
        except FileNotFoundError:
            pass
    address = socket.inet_aton(ip)[::-1].hex().upper() + ':' + format(port, '04X')
    rows = [line.split() for line in Path('/proc/net/tcp').read_text().splitlines()[1:]]
    matches = [row for row in rows if row[1] == address and row[3] == '0A' and f'socket:[{row[9]}]' in links]
    assert len(matches) == 1, 'exact listener ownership not proven'
    return {'pid': process.pid, 'socket': matches[0][9], 'binarySHA256': expected_sha,
            'address': ip, 'port': port, 'listenerOwned': True}


def owned():
    return listener_owned(native, IP, 45131, str(root / 'package/bin/opencode'), BINARY_SHA)


def api(label, method, path, body=None):
    proof = owned()
    assert path in ['/api/info', '/api/session', '/api/pty'] or (
        session_id and path == '/api/session/' + session_id) or (pty_id and path == '/api/pty/' + pty_id)
    assert method in ['GET', 'POST', 'PATCH', 'DELETE']
    query = ''
    if path.startswith('/api/pty'):
        from urllib.parse import urlencode
        query = '?' + urlencode({'location[directory]': str(root / 'runtime/project')})
    headers = {'Authorization': authorization, 'Accept': 'application/json'}
    if body is not None:
        headers['Content-Type'] = 'application/json'
    connection = http.client.HTTPConnection(IP, 45131, timeout=timeout(5 if cleanup_end else 12))
    try:
        connection.request(method, path + query, json.dumps(body) if body is not None else None, headers)
        response = connection.getresponse()
        raw = response.read(1_048_577)
        assert len(raw) <= 1_048_576
        calls.append({'label': label, 'method': method, 'path': path, 'status': response.status, **proof})
        assert response.status in [200, 204, 404], 'unexpected control API status'
        return {'status': response.status, 'data': json.loads(raw) if raw else None}
    finally:
        connection.close()


def child(argv, env=None):
    p = subprocess.Popen(argv, cwd=root / 'runtime/project', env=env,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL,
                         stderr=subprocess.DEVNULL, start_new_session=True)
    children.append(p)
    return p


def stop(p):
    if p.poll() is not None:
        return
    if cleanup_end and time.monotonic() >= cleanup_end:
        os.killpg(p.pid, signal.SIGKILL)
        p.wait(timeout=1)
        return
    os.killpg(p.pid, signal.SIGTERM)
    try:
        p.wait(timeout=timeout(3))
    except (subprocess.TimeoutExpired, TimeoutError):
        os.killpg(p.pid, signal.SIGKILL)
        p.wait(timeout=1)


def start(o):
    global native, static, static_exe, static_sha, baseline, authorization, serve, foreground_id, phase
    assert not children
    baseline = serve_status()
    route_free(baseline)
    for port, address in [(45130, '127.0.0.1'), (45131, IP), (8443, IP)]:
        with socket.socket() as probe:
            probe.bind((address, port))
    assert sha(root / 'package/bin/opencode') == BINARY_SHA
    env = {'PATH': '/usr/local/bin:/usr/bin:/bin', 'LANG': 'C.UTF-8'}
    runtime = root / 'runtime'
    (runtime / 'project').mkdir(parents=True, mode=0o700)
    for key, name in [('HOME', 'home'), ('TMPDIR', 'tmp'), ('XDG_RUNTIME_DIR', 'run'),
                      *[(f'XDG_{k}_HOME', k.lower()) for k in ['CONFIG', 'DATA', 'CACHE', 'STATE']]]:
        p = runtime / name
        p.mkdir(parents=True, mode=0o700, exist_ok=True)
        env[key] = str(p)
    env.update(OPENCODE_DISABLE_MODELS_FETCH='1', OPENCODE_CONFIG_PROJECT_DISABLE='1',
               OPENCODE_FILEWATCHER_DISABLE='1', OPENCODE_DISABLE_FFF='1')
    import base64
    authorization = 'Basic ' + base64.b64encode(('opencode:' + o['password']).encode()).decode()
    binary = str(root / 'package/bin/opencode')
    version = subprocess.run([binary, '--version'], env=env, cwd=runtime / 'project',
                             check=True, capture_output=True, text=True, timeout=30).stdout.strip()
    assert version == 'opencode v2.0.22'
    help_text = subprocess.run([binary, 'serve', '--help'], env=env, cwd=runtime / 'project',
                              check=True, capture_output=True, text=True, timeout=30).stdout
    assert all(flag in help_text for flag in ['--hostname', '--port', '--cors'])
    python = shutil.which('python3', path=env['PATH'])
    assert python is not None
    static_exe = os.path.realpath(python)
    static_sha = sha(static_exe)
    signal.alarm(180)
    phase = 'native-start'
    static = child(['python3', '-B', '-m', 'http.server', '45130', '--bind', '127.0.0.1',
            '--directory', str(root / 'app/build/web')], env)
    native = child([binary, 'serve', '--hostname', IP, '--port', '45131', '--cors', ORIGIN],
                   {**env, 'OPENCODE_SERVER_PASSWORD': o['password']})
    phase = 'native-readiness'
    end = time.monotonic() + 30
    while True:
        try:
            proof = owned()
            info = api('ReadinessInfo', 'GET', '/api/info')
            assert info['data']['pid'] == native.pid and info['data']['version'] == '2.0.22'
            assert info['data']['paths']['tmp'].startswith(str(runtime / 'tmp') + '/')
            break
        except (AssertionError, OSError):
            assert time.monotonic() < end and native.poll() is None
            time.sleep(.1)
    # Foreground route belongs to this child, never use a global reset.
    phase = 'static-readiness'
    end = time.monotonic() + 5
    while True:
        try:
            static_proof = listener_owned(static, '127.0.0.1', 45130, static_exe, static_sha)
            break
        except (AssertionError, OSError):
            assert time.monotonic() < end and static.poll() is None
            time.sleep(.1)
    assert serve_status() == baseline, 'Serve baseline changed before own route'
    phase = 'foreground-admission'
    serve = ServeController()
    serve.ready()
    foreground_id = wait_foreground(serve, baseline)
    return {'version': '2.0.22', 'cliVersionStdout': version, 'base': BASE, 'origin': ORIGIN, 'directory': str(runtime / 'project'),
            'peerIPs': json.loads(subprocess.run(['tailscale', 'status', '--json'], check=True,
                capture_output=True, text=True, timeout=10).stdout)['Self']['TailscaleIPs'],
            'static': static_proof, 'baselinePreserved': True,
            'foreground': {'layer': 'Foreground', 'sessionId': foreground_id, 'config': foreground_config(),
                           'supervisor': serve.started},
            'isolation': {'privateEnvironment': True, 'inheritedProviderCredentials': False}, **proof}


def dispatch(o):
    global session_id, pty_id, pty_pid, pty_birth, pty_attempted, phase
    if o['op'] == 'start':
        return start(o)
    if o['op'] == 'guard':
        phase = 'foreground-guard'
        assert serve is not None and serve.poll() is None, 'foreground process exited'
        assert admit_foreground(baseline, serve_status()) == foreground_id
        listener_owned(static, '127.0.0.1', 45130, static_exe, static_sha)
        return owned()
    phase = 'control'
    if o['op'] == 'createSession':
        assert session_id is None
        session_id = 'ses_' + format(int(time.time() * 1000) * 4096, '012x') + secrets.token_hex(7)
        result = api('CreateSession', 'POST', '/api/session', {'id': session_id, 'title': 'SP04 Tailpeer',
                     'location': {'directory': str(root / 'runtime/project')}})
        assert result['status'] == 200 and result['data']['data']['id'] == session_id
        return {'session': session_id}
    if o['op'] == 'createPty':
        assert pty_id is None
        pty_attempted = True
        result = api('CreatePty', 'POST', '/api/pty', {'command': '/bin/sh',
                     'args': ['-c', 'printf "TAILPEER_READY\\n"; while IFS= read -r line; do printf "ECHO:%s\\n" "$line"; done'],
                     'cwd': str(root / 'runtime/project'), 'title': 'SP04 tailpeer owned terminal'})
        pty_id = result['data']['data']['id']
        assert re.fullmatch(r'pty_[A-Za-z0-9]+', pty_id)
        pty_pid = result['data']['data']['pid']
        assert type(pty_pid) is int and pty_pid > 0
        pty_birth = Path(f'/proc/{pty_pid}/stat').read_text().split(') ', 1)[1].split()[19]
        return {'pty': pty_id, 'pid': pty_pid}
    if o['op'] == 'rename':
        assert session_id is not None
        assert o['title'] == 'Tailpeer native 🚀'
        return {'status': api('NativeRename', 'PATCH', '/api/session/' + session_id, {'title': o['title']})['status']}
    raise ValueError('unsupported control operation')


def cleanup():
    global cleanup_end
    started = time.monotonic()
    cleanup_end = started + 50
    report: dict = {'errors': [], 'calls': calls, 'serveNotAttempted': serve is None,
                   'sessionNotAttempted': session_id is None, 'ptyNotAttempted': not pty_attempted}
    if pty_attempted and pty_id is None:
        report['errors'].append('PTY creation outcome unknown; preserve root')
    for label, identifier, prefix in [('Pty', pty_id, '/api/pty/'), ('Session', session_id, '/api/session/')]:
        if not identifier:
            continue
        try:
            result = api('Delete' + label, 'DELETE', prefix + identifier)
            assert result['status'] in [200, 204]
            assert api('Verify' + label + 'Absent', 'GET', prefix + identifier)['status'] == 404
            report[label.lower() + 'Absent'] = True
            if label == 'Pty':
                assert type(pty_pid) is int and pty_pid > 0 and type(pty_birth) is str, 'PTY process identity unavailable'
                end = time.monotonic() + timeout(5)
                while True:
                    try:
                        birth = Path(f'/proc/{pty_pid}/stat').read_text().split(') ', 1)[1].split()[19]
                    except FileNotFoundError:
                        break
                    if birth != pty_birth:
                        break
                    assert time.monotonic() < end, 'owned PTY process remains'
                    time.sleep(.05)
                report['ptyProcessAbsent'] = True
        except Exception as e:
            report['errors'].append(label + ':' + type(e).__name__)
    if serve is not None:
        try:
            report['serveSupervisor'] = serve.stop()
        except Exception as e:
            report['errors'].append('supervisor:' + type(e).__name__)
    for p in reversed(children):
        try:
            stop(p)
        except Exception as e:
            report['errors'].append('process:' + type(e).__name__)
    try:
        wait_baseline(baseline)
        report['serveBaselineRestored'] = serve_status() == baseline
        assert report['serveBaselineRestored']
        for port, address in [(45130, '127.0.0.1'), (45131, IP)]:
            with socket.socket() as probe:
                probe.bind((address, port))
        report['portsAbsent'] = True
        report['ownedProcessesStopped'] = all(p.poll() is not None for p in children) and (
            serve is None or serve.poll() is not None and report.get('serveSupervisor', {}).get('childReaped') is True)
    except Exception as e:
        report['errors'].append('baseline:' + type(e).__name__)
    report['elapsedSeconds'] = time.monotonic() - started
    report['budgetSeconds'] = 50
    return report


def interrupted(*_):
    raise TimeoutError('remote invocation lease ended')


if __name__ == '__main__':
    root = Path(sys.argv[1])
    assert re.fullmatch(r'/tmp/opencode/codewalk-sp04-tailpeer-[a-z0-9_-]+', str(root))
    assert not root.is_symlink() and root.resolve() == root
    assert root.stat().st_uid == os.getuid() and root.stat().st_mode & 0o777 == 0o700
    signal.signal(signal.SIGALRM, interrupted)
    signal.signal(signal.SIGTERM, interrupted)
    signal.signal(signal.SIGHUP, interrupted)
    signal.alarm(300)
    command = {}
    try:
        for line in sys.stdin:
            command = json.loads(line)
            if command['op'] == 'cleanup':
                break
            result = dispatch(command)
            print(json.dumps({'id': command['id'], 'ok': True, 'result': result}), flush=True)
    except BaseException as error:
        # Fixed phase/type/numeric facts avoid exporting exception text or CLI secrets.
        print(json.dumps({'id': command.get('id'), 'ok': False, 'errorType': type(error).__name__,
                          'phase': phase, 'serveExitCode': serve.poll() if serve else None}), flush=True)
    finally:
        signal.alarm(0)
        # An SSH disconnect or repeated termination must not interrupt teardown.
        signal.signal(signal.SIGHUP, signal.SIG_IGN)
        signal.signal(signal.SIGTERM, signal.SIG_IGN)
        # Hard interrupt also bounds a response that keeps trickling bytes.
        signal.alarm(50)
        report = cleanup()
        signal.alarm(0)
        try:
            print(json.dumps({'cleanup': report}), flush=True)
        except BrokenPipeError:
            pass
