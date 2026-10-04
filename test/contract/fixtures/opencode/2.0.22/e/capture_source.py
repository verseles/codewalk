#!/usr/bin/env python3
"""Archived V2-005E collector with post-review safeguards; fresh preflight required.

The retrospective provider-step count is observation, not a hard guarantee against
native automatic continuations/retries. Establish live accounting and interruption
before any new capture. This archive does not execute during offline validation.
"""
import base64
import collections
import concurrent.futures
import datetime
import hashlib
import http.server
import io
import json
import os
from pathlib import Path
import secrets
import socket
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

ROOT = Path('/workspace/.cloud-runtime/opencode-v2/capture-e')
PROJECT = ROOT / 'project'
OUTSIDE = ROOT / 'outside'
OUT = Path('/workspace/codewalk/test/contract/fixtures/opencode/2.0.22/e')
BASE = 'http://127.0.0.1:49374'
CLI = '/workspace/.cloud-tools/bin/opencode2'
MODEL = {'id': 'space-bunny-free', 'providerID': 'opencode', 'variant': 'low'}
TERMINAL = {'session.execution.succeeded', 'session.execution.failed', 'session.execution.interrupted'}


def now():
    return datetime.datetime.now(datetime.timezone.utc).isoformat()


def uid(prefix):
    return prefix + format(int(time.time() * 1000) * 4096, '012x') + secrets.token_hex(7)


def clean(value):
    if isinstance(value, dict):
        return {k: '[REDACTED]' if k.lower() in {'authorization', 'password', 'token', 'apikey', 'api_key', 'access_token', 'refresh_token', 'client_secret', 'providerstate', 'providerresultstate', 'providercontext'}
                or (k == 'state' and value.get('type') in {'text', 'reasoning'}) else clean(v) for k, v in value.items()}
    if isinstance(value, list):
        return [clean(v) for v in value]
    return value


def save(name, value):
    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / name).write_text(json.dumps(clean(value), indent=2, ensure_ascii=False) + '\n')


def artifact(name, value):
    (ROOT / 'artifacts' / name).write_text(json.dumps(value, indent=2) + '\n')


class Client:
    def __init__(self):
        result = subprocess.run([CLI, 'service', 'get', 'password'], capture_output=True, text=True,
                                cwd=PROJECT, timeout=30)
        assert result.returncode == 0 and result.stdout.strip(), 'native password retrieval failed'
        self.password = result.stdout.strip()
        self.auth = 'Basic ' + base64.b64encode(('opencode:' + self.password).encode()).decode()
        self.calls = []
        self.sessions = set()

    def request(self, name, method, path, data=None, raw=None, origin=None, extra=None, auth=True):
        headers = {'Accept': 'application/json'}
        if auth:
            headers['Authorization'] = self.auth
        if data is not None:
            body = json.dumps(data).encode()
            headers['Content-Type'] = 'application/json'
        else:
            body = raw
            if raw is not None:
                headers['Content-Type'] = 'application/octet-stream'
        if origin:
            headers['Origin'] = origin
        headers.update(extra or {})
        started = now()
        request = urllib.request.Request(BASE + path, data=body, headers=headers, method=method)
        try:
            response = urllib.request.urlopen(request, timeout=45)
        except urllib.error.HTTPError as exc:
            response = exc
        content = response.read()
        status = response.status
        selected_headers = {k.lower(): v for k, v in response.headers.items()
                            if k.lower() in {'content-type', 'access-control-allow-origin', 'access-control-allow-methods',
                                             'access-control-allow-headers', 'access-control-allow-credentials', 'vary'}}
        try:
            value = json.loads(content) if content else None
        except (ValueError, UnicodeDecodeError):
            value = {'rawUtf8': content.decode('utf-8', errors='replace'), 'sha256': hashlib.sha256(content).hexdigest()}
        self.calls.append({'name': name, 'startedAt': started, 'completedAt': now(), 'method': method,
                           'path': path, 'request': data if data is not None else None,
                           'requestRawSha256': hashlib.sha256(raw).hexdigest() if raw is not None else None,
                           'requestOrigin': origin, 'status': status, 'responseHeaders': selected_headers,
                           'responseBytes': len(content), 'response': clean(value)})
        return status, value

    def create(self, name, model=None):
        payload = {'id': uid('ses_'), 'title': 'V2-005E ' + name, 'location': {'directory': str(PROJECT)}}
        if model:
            payload.update(model=model, permissions=[{'action': '*', 'resource': '*', 'effect': 'deny'}])
        status, value = self.request(name + 'Create', 'POST', '/api/session', payload)
        assert status == 200, name + ' creation failed'
        sid = value['data']['id']
        self.sessions.add(sid)
        ledger_path = ROOT / 'artifacts' / 'owned-session-ledger.json'
        owned = set(json.loads(ledger_path.read_text())['sessionIDs']) if ledger_path.exists() else set()
        owned.add(sid)
        artifact('owned-session-ledger.json', {'sessionIDs': sorted(owned), 'updatedAt': now()})
        return sid

    def snapshot(self, name, sid):
        return {kind: self.request(name + kind, 'GET', '/api/session/' + sid + suffix)[1]
                for kind, suffix in [('session', ''), ('inbox', '/inbox'), ('history', '/message?order=asc&limit=200')]}

    def finish(self, name):
        info = self.request(name + 'FinalInfo', 'GET', '/api/info')[1]
        active = self.request(name + 'FinalActive', 'GET', '/api/session/active')[1]
        owned_active = [sid for sid in self.sessions if sid in active.get('data', [])]
        for sid in owned_active:
            self.request('InterruptOwnedUnfinished', 'POST', '/api/session/' + sid + '/interrupt')
        states = {sid: self.snapshot('Final', sid) for sid in sorted(self.sessions)}
        assert info['version'] == '2.0.22'
        return {'connectedInfo': info, 'ownedActiveBeforeCleanup': owned_active, 'ownedSessionState': states,
                'disposableGit': {'initialCommit': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=PROJECT, text=True).strip(),
                                  'status': subprocess.check_output(['git', 'status', '--porcelain'], cwd=PROJECT, text=True)}}


class Stream:
    def __init__(self, client, path='/api/event', allowed=None):
        self.client = client
        self.path = path
        self.allowed = allowed if allowed is not None else client.sessions
        self.events = []
        self.lines = []
        self.total_bytes = 0
        self.owned_bytes = 0
        self.ambient_event_count = 0
        self.heartbeat_bytes = 0
        self.comment_frames = []
        self.started = now()
        self.done = threading.Event()
        self.opened = threading.Event()
        self.stop = threading.Event()
        self.response = None
        self.failure = None
        self.thread = threading.Thread(target=self.run, daemon=True)
        self.thread.start()
        assert self.opened.wait(15) and not self.failure, 'SSE stream failed to open'

    def run(self):
        try:
            request = urllib.request.Request(BASE + self.path,
                                             headers={'Accept': 'text/event-stream', 'Authorization': self.client.auth})
            self.response = urllib.request.urlopen(request, timeout=35)
            self.status = self.response.status
            self.opened.set()
            frame = []
            frame_bytes = 0
            for raw in self.response:
                self.total_bytes += len(raw)
                frame_bytes += len(raw)
                line = raw.decode().rstrip('\r\n')
                if line:
                    frame.append(line)
                else:
                    payload = '\n'.join(line[5:].lstrip() for line in frame if line.startswith('data:'))
                    if payload:
                        event = json.loads(payload)
                        sid = event.get('data', {}).get('sessionID') or event.get('durable', {}).get('aggregateID') or event.get('aggregateID')
                        if self.path != '/api/event' or event['type'] == 'server.connected' or sid in self.allowed:
                            self.events.append(event)
                            self.lines.append(frame)
                            self.owned_bytes += frame_bytes
                        else:
                            self.ambient_event_count += 1
                    elif any(line.startswith(':') for line in frame):
                        self.heartbeat_bytes += frame_bytes
                        self.comment_frames.append({'lines': frame, 'bytes': frame_bytes, 'observedAt': now()})
                    frame = []
                    frame_bytes = 0
                if self.stop.is_set():
                    break
        except Exception as exc:
            if not self.stop.is_set():
                self.failure = type(exc).__name__
            self.opened.set()
        finally:
            if self.response:
                self.response.close()
            self.done.set()

    def close(self):
        self.stop.set()
        if self.response:
            try:
                self.response.fp.raw._sock.shutdown(socket.SHUT_RDWR)
            except (AttributeError, OSError):
                pass
        self.thread.join(5)

    def dump(self):
        return {'path': self.path, 'openedAt': self.started, 'closedAt': now(), 'status': getattr(self, 'status', None),
                'events': clean(self.events), 'frames': self.lines if self.path != '/api/event' else None,
                'totalHttpBodyBytes': self.total_bytes, 'ownedEventFrameBytes': self.owned_bytes,
                'heartbeatBytes': self.heartbeat_bytes, 'ambientEventCount': self.ambient_event_count,
                'commentFrames': self.comment_frames,
                'failure': self.failure}


def wait_until(predicate, timeout=30):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if predicate():
            return True
        time.sleep(0.1)
    return False


def sources():
    pin = '05018b8862a8fc198ec9810aafd397c96bb7d86e'
    paths = ['packages/core/src/bus.ts', 'packages/core/src/filesystem.ts', 'packages/core/src/session/runner/to-llm-message.ts',
             'packages/core/src/session/prompt.ts', 'packages/schema/src/prompt-input.ts', 'packages/protocol/src/groups/fs.ts',
             'packages/protocol/src/groups/session.ts', 'packages/server/src/routes.ts', 'packages/server/src/cors.ts',
             'packages/server/src/process.ts', 'packages/cli/src/server-process.ts', 'packages/cli/src/services/service-config.ts',
             'packages/cli/src/commands/handlers/service/get.ts']
    result = {}
    for path in paths:
        url = 'https://raw.githubusercontent.com/anomalyco/opencode/' + pin + '/' + path
        content = urllib.request.urlopen(url, timeout=25).read()
        lines = content.decode().splitlines()
        indexes = {i for i, line in enumerate(lines) if any(s in line for s in ['application/pdf', 'persist =', 'persist:',
                                                                                              'path.resolve(location.directory, input.path)',
                                                                                              'writeWithDirs(target', 'case "password"',
                                                                                              'session.log', 'isAllowedCorsOrigin'])}
        snippet_indices = sorted({j for i in indexes for j in range(max(0, i-2), min(len(lines), i+5))})
        result[path] = {'url': url, 'sha256': hashlib.sha256(content).hexdigest(),
                        'excerpts': [{'line': j + 1, 'text': lines[j]} for j in snippet_indices]}
    older_path = 'packages/core/src/session/runner/to-llm-message.ts'
    older_pin = '8a8bd622a3d7dc29ccf30ec17f84e363ed95ed72'
    content = urllib.request.urlopen('https://raw.githubusercontent.com/anomalyco/opencode/' + older_pin + '/' + older_path, timeout=25).read()
    save('source-evidence.json', {'capturedAt': now(), 'sourcePin': pin, 'sources': result,
                                  'olderPdfForwarding': {'sourcePin': older_pin, 'path': older_path,
                                                        'sha256': hashlib.sha256(content).hexdigest(),
                                                        'containsPdfForwarding': b'file.mime === "application/pdf"' in content},
                                  'sourceEvidenceOnly': True})


def base_capture():
    c = Client()
    started = now()
    info = c.request('ServicePasswordAuthenticatedInfo', 'GET', '/api/info')[1]
    assert info['version'] == '2.0.22'
    denied = c.request('NoCredentialInfo', 'GET', '/api/info', auth=False)[0]
    models = c.request('CurrentModelCatalog', 'GET', '/api/model?location%5Bdirectory%5D=' + urllib.parse.quote(str(PROJECT), safe=''))[1]
    selected = next(model for model in models['data'] if model['providerID'] == MODEL['providerID'] and model['modelID'] == MODEL['id'])
    assert selected['enabled'] and selected['cost'] and all(price['input'] == price['output'] == 0 for price in selected['cost'])
    save('model.json', selected)
    safe_calls = [call for call in c.calls if call['name'] != 'CurrentModelCatalog']
    save('service-credentials.json', {'capturedAt': started, 'calls': safe_calls, 'retrievalCommand': [CLI, 'service', 'get', 'password'],
                                    'credentialReturnedOnlyInMemory': True, 'unauthenticatedStatus': denied,
                                    'registrationMode': oct((Path('/workspace/.cloud-runtime/opencode-v2/state/opencode/service.json')).stat().st_mode & 0o777),
                                    'configMode': oct((Path('/workspace/.cloud-runtime/opencode-v2/config/opencode/service.json')).stat().st_mode & 0o777)})
    c.calls = []
    sid = c.create('durable-log')
    global_stream = Stream(c)
    assert wait_until(lambda: any(e['type'] == 'server.connected' for e in global_stream.events)), 'missing connected event'
    c.request('RenameBeforeLog', 'PATCH', '/api/session/' + sid, {'title': 'V2-005E log renamed once'})
    assert wait_until(lambda: any(e['type'] == 'session.renamed' for e in global_stream.events)), 'rename not observed'
    c.request('ReadRenamedSession', 'GET', '/api/session/' + sid)
    watermark = max(e['durable']['seq'] for e in global_stream.events if e.get('durable', {}).get('aggregateID') == sid)
    logs = []
    for query in ['', '?after=0&follow=false', '?after=' + str(watermark) + '&follow=false']:
        stream = Stream(c, '/api/experimental/session/' + sid + '/log' + query)
        assert stream.done.wait(20), 'non-following log did not terminate'
        logs.append(stream.dump())
    follow = Stream(c, '/api/experimental/session/' + sid + '/log?after=' + str(watermark) + '&follow=true')
    assert wait_until(lambda: any(e['type'] == 'log.synced' for e in follow.events)), 'no follow marker'
    c.request('RenameWhileFollowing', 'PATCH', '/api/session/' + sid, {'title': 'V2-005E log renamed twice'})
    assert wait_until(lambda: sum(e['type'] == 'session.renamed' for e in global_stream.events) >= 2), 'second rename not observed'
    time.sleep(2)
    c.request('ReadTwiceRenamedSession', 'GET', '/api/session/' + sid)
    follow.close()
    global_stream.close()
    save('durable-log.json', {'capturedAt': now(), 'sessionID': sid, 'calls': c.calls,
                             'observedWatermark': watermark, 'globalStream': global_stream.dump(), 'logReads': logs,
                             'followStream': follow.dump(), 'capability': 'unavailable' if all(all(e['type'] == 'log.synced' for e in s['events']) for s in logs) else 'needs-review'})
    artifact('base-session.json', {'sessionID': sid})
    c.calls = []
    prefix = '?location%5Bdirectory%5D=' + urllib.parse.quote(str(PROJECT), safe='')
    (PROJECT / 'inside').mkdir(exist_ok=True)
    (OUTSIDE / 'read-marker.txt').write_text('OUTSIDE_DISPOSABLE_READ_MARKER\n')
    link = PROJECT / 'link'
    if not link.exists() and not link.is_symlink():
        link.symlink_to(OUTSIDE, target_is_directory=True)
    tests = [('NormalWrite', 'inside/normal.txt'), ('TraversalWrite', '../outside/traversal.txt'),
             ('AbsoluteWrite', str(OUTSIDE / 'absolute.txt')), ('SymlinkWrite', 'link/symlink.txt')]
    file_results = []
    for name, target in tests:
        marker = ('V2-005E ' + name + '\n').encode()
        status, value = c.request(name, 'POST', '/api/experimental/fs/write' + prefix + '&path=' + urllib.parse.quote(target, safe=''), raw=marker)
        lexical = Path(os.path.abspath(PROJECT / target))
        file_results.append({'name': name, 'pathInput': target, 'lexicalPath': str(lexical), 'realPathAfter': str(lexical.resolve()),
                             'status': status, 'actualBytes': lexical.read_text() if lexical.exists() else None,
                             'expectedBytes': marker.decode(), 'insideProjectAfter': lexical.resolve().is_relative_to(PROJECT.resolve())})
    c.request('ReadInternal', 'GET', '/api/fs/read/inside%2Fnormal.txt' + prefix)
    c.request('ReadSymlinkOutside', 'GET', '/api/fs/read/link%2Fread-marker.txt' + prefix)
    c.request('ReadTraversalOutside', 'GET', '/api/fs/read/..%2Foutside%2Fread-marker.txt' + prefix)
    c.request('ListProject', 'GET', '/api/fs/list' + prefix)
    c.request('ListOutsideSibling', 'GET', '/api/fs/list' + prefix + '&path=..%2Foutside')
    c.request('FindNormalFile', 'GET', '/api/fs/find' + prefix + '&query=normal&limit=10')
    swap = PROJECT / 'swap'
    temp = PROJECT / 'swap-next'
    if swap.is_symlink():
        swap.unlink()
    swap.symlink_to(PROJECT / 'inside', target_is_directory=True)
    done = threading.Event()
    swaps = [0]
    def toggle():
        while not done.is_set():
            for target in (OUTSIDE, PROJECT / 'inside'):
                if done.is_set():
                    break
                try:
                    temp.symlink_to(target, target_is_directory=True)
                    os.replace(temp, swap)
                    swaps[0] += 1
                except FileExistsError:
                    temp.unlink(missing_ok=True)
                time.sleep(0.0005)
    racer = threading.Thread(target=toggle, daemon=True)
    racer.start()
    races = []
    for i in range(100):
        resolved_before = (swap / ('race-' + str(i) + '.txt')).resolve()
        if not resolved_before.is_relative_to(PROJECT.resolve()):
            wait_until(lambda: swap.resolve().is_relative_to(PROJECT.resolve()), 2)
            resolved_before = (swap / ('race-' + str(i) + '.txt')).resolve()
        if not resolved_before.is_relative_to(PROJECT.resolve()):
            continue
        target = 'swap/race-' + str(i) + '.txt'
        marker = ('TOCTOU_' + str(i) + '\n').encode()
        status, body = c.request('TOCTOUWrite' + str(i), 'POST', '/api/experimental/fs/write' + prefix + '&path=' + urllib.parse.quote(target, safe=''), raw=marker)
        outside = OUTSIDE / ('race-' + str(i) + '.txt')
        inside = PROJECT / 'inside' / ('race-' + str(i) + '.txt')
        races.append({'iteration': i, 'resolvedBeforeWithinProject': str(resolved_before), 'status': status,
                      'outsideExists': outside.exists(), 'outsideBytes': outside.read_text() if outside.exists() else None,
                      'insideExists': inside.exists(), 'insideBytes': inside.read_text() if inside.exists() else None,
                      'marker': marker.decode()})
    done.set()
    racer.join(3)
    temp.unlink(missing_ok=True)
    save('filesystem.json', {'capturedAt': now(), 'projectDirectory': str(PROJECT), 'outsideOwnedDirectory': str(OUTSIDE),
                            'writes': file_results, 'calls': c.calls, 'toctou': {'writes': races, 'atomicLinkReplacements': swaps[0],
                            'outsideWriteCount': sum(r['outsideExists'] for r in races)}, 'writeCapability': 'unavailable',
                            'readBoundaryScope': 'observed normal/symlink/traversal cases only; no race-containment claim',
                            'windowsJunction': 'pending native Windows resource'})
    c.calls = []
    final = c.finish('Base')
    save('base-final-state.json', {'capturedAt': now(), 'calls': c.calls, 'state': final})
    print(json.dumps({'phase': 'base', 'durableLog': 'watermark-only', 'filesystemOutsideWrites': [r['name'] for r in file_results if not r['insideProjectAfter']],
                      'toctouWrites': len(races), 'toctouOutsideCount': sum(r['outsideExists'] for r in races)}), flush=True)


def provider_capture():
    from PIL import Image, ImageDraw, ImageFont
    from reportlab.pdfgen import canvas
    from pypdf import PdfReader
    budget_file = ROOT / 'artifacts' / 'provider-budget.json'
    assert not budget_file.exists(), 'provider phase already ran; inspect preserved budget instead of replaying'
    budget = {'limit': 6, 'submitted': 0, 'observedProviderSteps': 0, 'startedAt': now()}
    artifact('provider-budget.json', budget)
    c = Client()
    catalog = c.request('ModelCatalogBeforeProvider', 'GET', '/api/model?location%5Bdirectory%5D=' + urllib.parse.quote(str(PROJECT), safe=''))[1]['data']
    by_id = {m['modelID']: m for m in catalog if m['providerID'] == 'opencode' and m['enabled'] and m['cost']
             and all(p['input'] == p['output'] == 0 for p in m['cost'])}
    assert 'image' in by_id['space-bunny-free']['capabilities']['input']
    pdf_id = 'muse-spark-1.3-contributor-free'
    assert 'pdf' in by_id[pdf_id]['capabilities']['input']
    save('model-pdf.json', by_id[pdf_id])
    c.calls = []
    marker_png = 'CW_PNG_' + secrets.token_hex(6).upper()
    marker_pdf = 'CW_PDF_' + secrets.token_hex(6).upper()
    png = Image.new('RGB', (1000, 180), 'white')
    draw = ImageDraw.Draw(png)
    font = ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf', 45)
    draw.text((25, 55), marker_png, fill='black', font=font)
    png.save(OUT / 'attachment.png')
    pdf_bytes = io.BytesIO()
    page = canvas.Canvas(pdf_bytes, pagesize=(612, 792), invariant=True)
    page.setFont('Courier', 24)
    page.drawString(40, 700, marker_pdf)
    page.save()
    (OUT / 'attachment.pdf').write_bytes(pdf_bytes.getvalue())
    assert marker_pdf in PdfReader(io.BytesIO(pdf_bytes.getvalue())).pages[0].extract_text()
    attachments = [('png', 'image/png', marker_png, MODEL),
                   ('pdf', 'application/pdf', marker_pdf, {'providerID': 'opencode', 'id': pdf_id, 'variant': 'minimal'})]
    for kind, mime, marker, model in attachments:
        assert budget['submitted'] < budget['limit']
        c.calls = []
        sid = c.create('attachment-' + kind, model=model)
        stream = Stream(c, allowed={sid})
        assert wait_until(lambda: any(e['type'] == 'server.connected' for e in stream.events)), 'missing SSE connection'
        content = (OUT / ('attachment.' + kind)).read_bytes()
        payload = {'id': uid('msg_'), 'text': 'Read the attached file. Return only the marker written in it. Do not use any tools. If you cannot read it, reply UNAVAILABLE.',
                   'files': [{'uri': 'data:' + mime + ';base64,' + base64.b64encode(content).decode(), 'name': 'capture.' + kind}]}
        budget['submitted'] += 1
        artifact('provider-budget.json', budget)
        c.request('AttachmentPromptAdmission', 'POST', '/api/session/' + sid + '/prompt', payload)
        ended = wait_until(lambda: any(e['type'] in TERMINAL for e in stream.events), 180)
        if not ended:
            c.request('TimeoutInterruptOwnSession', 'POST', '/api/session/' + sid + '/interrupt')
        state = c.snapshot('AttachmentAfter', sid)
        stream.close()
        steps = sum(e['type'] == 'session.step.started' for e in stream.events)
        budget['observedProviderSteps'] += steps
        artifact('provider-budget.json', budget)
        history = state['history'].get('data', [])
        assistant_text = '\n'.join(part['text'] for m in history if m['type'] == 'assistant' for part in m.get('content', []) if part['type'] == 'text')
        tool_count = sum(part['type'] == 'tool' for m in history if m['type'] == 'assistant' for part in m.get('content', []))
        result = {'capturedAt': now(), 'kind': kind, 'sessionID': sid, 'model': model, 'mime': mime,
                  'attachmentSha256': hashlib.sha256(content).hexdigest(), 'decodedBytes': len(content),
                  'expectedAttachmentOnlyMarker': marker, 'markerWasAbsentFromPromptText': marker not in payload['text'],
                  'calls': c.calls, 'state': state, 'stream': stream.dump(), 'nativeTerminalObserved': ended,
                  'modelReturnedExactMarker': assistant_text.strip() == marker, 'assistantText': assistant_text,
                  'assistantToolCount': tool_count, 'observedProviderStepCount': steps,
                  'productPdfPolicy': 'disabled; observation does not authorize enabling product PDF'}
        save('attachment-' + kind + '.json', result)
        print(json.dumps({'phase': 'attachment', 'kind': kind, 'terminalObserved': ended,
                          'markerRecognized': result['modelReturnedExactMarker'], 'providerSteps': steps}), flush=True)
        assert budget['observedProviderSteps'] <= budget['limit'], 'provider step budget exceeded'
    c.calls = []
    c.sessions = set()
    sessions = [c.create('bandwidth-' + str(i), model=MODEL) for i in range(3)]
    stream = Stream(c, allowed=set(sessions))
    assert wait_until(lambda: any(e['type'] == 'server.connected' for e in stream.events)), 'missing bandwidth SSE connection'
    started = time.monotonic()
    submitted_at = now()
    assert budget['submitted'] + 3 <= budget['limit'], 'stop new admissions before exceeding budget'
    budget['submitted'] += 3
    artifact('provider-budget.json', budget)
    def submit(pair):
        index, sid = pair
        payload = {'id': uid('msg_'), 'text': 'Write exactly ten brief lines numbered 1 through 10 about counting. Do not use any tools.'}
        return c.request('BandwidthPrompt' + str(index), 'POST', '/api/session/' + sid + '/prompt', payload)
    with concurrent.futures.ThreadPoolExecutor(max_workers=3) as executor:
        admissions = list(executor.map(submit, enumerate(sessions)))
    terminal_ids = lambda: {e['data']['sessionID'] for e in stream.events if e['type'] in TERMINAL}
    ended = wait_until(lambda: set(sessions).issubset(terminal_ids()), 180)
    if not ended:
        for sid in set(sessions) - terminal_ids():
            c.request('BandwidthTimeoutInterrupt', 'POST', '/api/session/' + sid + '/interrupt')
    duration = time.monotonic() - started
    states = {sid: c.snapshot('BandwidthAfter', sid) for sid in sessions}
    stream.close()
    steps = sum(e['type'] == 'session.step.started' for e in stream.events)
    budget['observedProviderSteps'] += steps
    artifact('provider-budget.json', budget)
    intervals = []
    for sid in sessions:
        starts = [e['created'] for e in stream.events if e['type'] == 'session.execution.started' and e['data']['sessionID'] == sid]
        ends = [e['created'] for e in stream.events if e['type'] in TERMINAL and e['data']['sessionID'] == sid]
        intervals.append({'sessionID': sid, 'startedMs': min(starts) if starts else None, 'endedMs': max(ends) if ends else None})
    valid = [i for i in intervals if i['startedMs'] is not None and i['endedMs'] is not None]
    overlap = max(0, min(i['endedMs'] for i in valid) - max(i['startedMs'] for i in valid)) if len(valid) == 3 else None
    save('loopback-bandwidth.json', {'capturedAt': now(), 'transport': 'loopback Linux HTTP; not cellular',
                                    'submittedAt': submitted_at, 'sessionIDs': sessions, 'calls': c.calls, 'stream': stream.dump(),
                                    'states': states, 'allNativeTerminalObserved': ended, 'durationSeconds': duration,
                                    'observedProviderStepCount': steps, 'executionIntervals': intervals,
                                    'threeExecutionOverlapMs': overlap,
                                    'wireMeasurementBoundary': 'HTTP body bytes consumed by this urllib SSE stream, excluding HTTP headers/TCP/IP; ambient native event bytes included in total but counted separately; owned frame bytes isolate selected session events',
                                    'cellularAcceptance': 'pending: no cellular interface or real mobile network'})
    assert budget['observedProviderSteps'] <= budget['limit']
    c.calls = []
    c.sessions.update(json.loads((OUT / ('attachment-' + kind + '.json')).read_text())['sessionID'] for kind in ('png', 'pdf'))
    base_sid = json.loads((ROOT / 'artifacts' / 'base-session.json').read_text())['sessionID']
    c.sessions.add(base_sid)
    final = c.finish('Provider')
    save('provider-final-state.json', {'capturedAt': now(), 'calls': c.calls, 'state': final, 'budget': budget})
    print(json.dumps({'phase': 'bandwidth', 'threeConcurrentOverlapMs': overlap, 'durationSeconds': duration,
                      'providerSteps': steps, 'totalSubmitted': budget['submitted'], 'totalObservedProviderSteps': budget['observedProviderSteps']}), flush=True)


def cors_capture():
    from playwright.sync_api import sync_playwright
    c = Client()
    class Page(http.server.BaseHTTPRequestHandler):
        def do_GET(self):
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(b'<!doctype html><title>Disposable CodeWalk CORS capture</title>')
        def log_message(self, *args):
            pass
    server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Page)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    port = server.server_port
    allowed = 'http://localhost:' + str(port)
    denied = 'http://cw-e-denied.test:' + str(port)
    try:
        for name, origin in [('Allowed', allowed), ('Denied', denied)]:
            c.request(name + 'Preflight', 'OPTIONS', '/api/info', origin=origin, auth=False,
                      extra={'Access-Control-Request-Method': 'GET', 'Access-Control-Request-Headers': 'authorization'})
            c.request(name + 'NativeInfoWithOrigin', 'GET', '/api/info', origin=origin)
        browser_results = []
        with sync_playwright() as p:
            browser = p.chromium.launch(executable_path='/usr/bin/chromium', headless=True,
                                       args=['--no-sandbox', '--disable-dev-shm-usage', '--no-proxy-server',
                                             '--host-resolver-rules=MAP cw-e-denied.test 127.0.0.1'])
            chromium_version = browser.version
            context = browser.new_context()
            for name, origin in [('allowed', allowed), ('denied', denied)]:
                page = context.new_page()
                errors = []
                page.on('console', lambda event: errors.append(event.text) if event.type == 'error' else None)
                page.goto(origin, wait_until='domcontentloaded', timeout=15000)
                info = page.evaluate('''async ({base, authorization}) => {
                    const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), 10000);
                    try { const response = await fetch(base + '/api/info', {headers: {Authorization: authorization}, signal: controller.signal});
                        const json = await response.json(); return {readable: true, status: response.status, version: json.version,
                            allowOrigin: response.headers.get('access-control-allow-origin')};
                    } catch (error) { return {readable: false, errorName: error.name}; }
                    finally { clearTimeout(timer); }
                }''', {'base': BASE, 'authorization': c.auth})
                event = page.evaluate('''async ({base, authorization}) => {
                    const controller = new AbortController(); const timer = setTimeout(() => controller.abort(), 10000);
                    try { const response = await fetch(base + '/api/event', {headers: {Authorization: authorization}, signal: controller.signal});
                        const reader = response.body.getReader(); const decoder = new TextDecoder(); let text = '';
                        while (!text.includes('\\n\\n')) { const value = await reader.read(); if (value.done) break; text += decoder.decode(value.value, {stream:true}); }
                        const frame = text.split('\\n\\n')[0]; const data = frame.split('\\n').filter(line => line.startsWith('data:')).map(line=>line.slice(5).trim()).join('\\n');
                        const json = JSON.parse(data); controller.abort(); return {readable: true, status: response.status, firstType: json.type};
                    } catch (error) { return {readable: false, errorName: error.name}; }
                    finally { clearTimeout(timer); controller.abort(); }
                }''', {'base': BASE, 'authorization': c.auth})
                browser_results.append({'name': name, 'actualPageOrigin': page.evaluate('location.origin'),
                                        'info': info, 'firstSseFrame': event, 'consoleErrors': errors})
                page.close()
            context.close()
            browser.close()
        final = c.request('CORSFinalInfo', 'GET', '/api/info')[1]
        save('cors.json', {'capturedAt': now(), 'calls': c.calls, 'browser': 'Chromium', 'browserVersion': chromium_version,
                          'browserResults': browser_results, 'nativeServiceConfigChanged': False,
                          'interpretationBoundary': 'allowed/rejected Origin and browser readability on loopback; no Safari, HTTPS-to-LAN mixed-content or configured-custom-origin acceptance',
                          'finalInfo': final})
        print(json.dumps({'phase': 'cors', 'browser': chromium_version,
                          'results': [{'origin': r['name'], 'infoReadable': r['info']['readable'],
                                       'sseReadable': r['firstSseFrame']['readable']} for r in browser_results]}), flush=True)
    finally:
        server.shutdown()
        server.server_close()


def idle_capture():
    c = Client()
    stream = Stream(c, allowed=set())
    started = time.monotonic()
    time.sleep(32)
    stream.close()
    duration = time.monotonic() - started
    save('loopback-idle.json', {'capturedAt': now(), 'durationSeconds': duration, 'stream': stream.dump(),
                               'transport': 'loopback Linux HTTP; not cellular', 'measurementBoundary': 'HTTP body bytes; comments distinguished from selected event frames; ambient native events excluded from persisted content'})
    print(json.dumps({'phase': 'idle', 'durationSeconds': duration, 'bodyBytes': stream.total_bytes,
                      'commentBytes': stream.heartbeat_bytes, 'comments': len(stream.comment_frames),
                      'ambientEventCount': stream.ambient_event_count}), flush=True)


def cleanup_capture():
    import shutil
    c = Client()
    prefix = '?location%5Bdirectory%5D=' + urllib.parse.quote(str(PROJECT), safe='')
    c.request('FindCommittedBaseline', 'GET', '/api/fs/find' + prefix + '&query=baseline&limit=10')
    c.request('FindCreatedNormalAfterSettlement', 'GET', '/api/fs/find' + prefix + '&query=normal&limit=10')
    initial = c.request('CleanupBeforeInfo', 'GET', '/api/info')[1]
    ids = set(json.loads((OUT / 'loopback-bandwidth.json').read_text())['sessionIDs'])
    ids.update(json.loads((OUT / ('attachment-' + kind + '.json')).read_text())['sessionID'] for kind in ('png', 'pdf'))
    ids.add(json.loads((OUT / 'durable-log.json').read_text())['sessionID'])
    c.sessions.update(ids)
    states = {sid: c.snapshot('CleanupBefore', sid) for sid in sorted(ids)}
    active = c.request('CleanupBeforeActive', 'GET', '/api/session/active')[1]
    assert not ids.intersection(active.get('data', [])), 'owned execution still active'
    for sid in sorted(ids):
        c.request('DeleteOwnedSession', 'DELETE', '/api/session/' + sid)
        assert c.request('DeletedOwnedSessionAbsent', 'GET', '/api/session/' + sid)[0] == 404
    for name in ('link', 'swap', 'swap-next'):
        path = PROJECT / name
        if path.is_symlink():
            path.unlink()
    shutil.rmtree(PROJECT / 'inside')
    for path in OUTSIDE.iterdir():
        assert path.is_file() and not path.is_symlink()
        path.unlink()
    status = subprocess.check_output(['git', 'status', '--porcelain'], cwd=PROJECT, text=True)
    assert not status, 'disposable project worktree is not clean'
    final = c.request('CleanupAfterInfo', 'GET', '/api/info')[1]
    active_after = c.request('CleanupAfterActive', 'GET', '/api/session/active')[1]
    assert final['pid'] == initial['pid'], 'native service process changed during cleanup'
    assert not ids.intersection(active_after.get('data', []))
    save('cleanup.json', {'capturedAt': now(), 'calls': c.calls, 'ownedSessionIDs': sorted(ids), 'ownedStateBeforeDeletion': states,
                         'disposableProjectGitStatusAfterCleanup': status, 'outsideOwnedDirectoryEntriesAfterCleanup': [],
                         'nativeServiceProcessPreserved': True, 'sharedServiceReconfiguredOrRestarted': False,
                         'credentialReturnedOnlyInMemory': True})
    print(json.dumps({'phase': 'cleanup', 'ownedSessionsDeleted': len(ids), 'disposableProjectGitClean': True,
                      'nativeServiceProcessPreserved': True}), flush=True)


def provider_finally_cleanup():
    """Best-effort stop/reconcile owned active work, including on failed assertions.

This limits further observed work; it cannot guarantee a native provider has not
started a continuation before the client sees its event. A fresh preflight must
establish that boundary and live provider accounting, not rely on this archive.
"""
    ledger = ROOT / 'artifacts' / 'owned-session-ledger.json'
    if not ledger.exists():
        return
    c = Client()
    owned = set(json.loads(ledger.read_text())['sessionIDs'])
    try:
        active = c.request('FinallyActive', 'GET', '/api/session/active')[1].get('data', [])
        for sid in owned.intersection(active):
            c.request('FinallyInterruptOwned', 'POST', '/api/session/' + sid + '/interrupt')
        states = {sid: c.snapshot('FinallySnapshot', sid) for sid in sorted(owned)}
        artifact('provider-finally-cleanup.json', {'capturedAt': now(), 'calls': clean(c.calls), 'ownedState': clean(states)})
    except Exception as error:
        artifact('provider-finally-cleanup.json', {'capturedAt': now(), 'failureType': type(error).__name__,
                                                 'calls': clean(c.calls), 'remainingOwnedSessionIDs': sorted(owned)})


if __name__ == '__main__':
    if sys.argv[1] == 'source':
        sources()
        print('Pinned source evidence captured; no native request')
    elif sys.argv[1] == 'base':
        base_capture()
    elif sys.argv[1] == 'provider':
        try:
            provider_capture()
        finally:
            provider_finally_cleanup()
    elif sys.argv[1] == 'cors':
        cors_capture()
    elif sys.argv[1] == 'idle':
        idle_capture()
    elif sys.argv[1] == 'cleanup':
        cleanup_capture()
    else:
        raise SystemExit('Unknown phase')
