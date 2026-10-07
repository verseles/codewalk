"""Fail-closed evidence validation. A policy block is an observation, not a pass."""
import hashlib
import json
from pathlib import Path
import sys

ARCHIVE_SHA = '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b'
BINARY_SHA = 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815'
ORIGIN = 'https://coolify.uaru-nase.ts.net:8443'
BASE = 'http://100.123.123.3:45131'


def sha(path):
    with path.open('rb') as f:
        return hashlib.file_digest(f, 'sha256').hexdigest()


def validate(c):
    assert c['result'] == 'observed'
    assert type(c['nativeInferenceTurns']) is int and c['nativeInferenceTurns'] == 0
    assert type(c['inferenceCostUSD']) in [int, float] and c['inferenceCostUSD'] == 0
    assert c['securityOverrides'] == []
    assert c['budgets']['setupSeconds'] == 1200 and c['budgets']['collectionSeconds'] == 180 and c['budgets']['cleanupSeconds'] == 120
    assert type(c['budgets']['preparationDebitSeconds']) is int and 0 < c['budgets']['preparationDebitSeconds'] < 1200
    assert 0 <= c['collectionElapsedMs'] <= 180000
    assert 0 <= c['setupElapsedMs']
    assert c['budgets']['preparationDebitSeconds'] * 1000 + c['setupElapsedMs'] + c['collectionElapsedMs'] <= 1200000
    assert c['archiveSHA256'] == ARCHIVE_SHA and c['binarySHA256'] == BINARY_SHA
    assert c['nativeArgv'] == ['serve', '--hostname', '100.123.123.3', '--port', '45131', '--cors', ORIGIN]
    assert c['scope'] == 'private-Tailscale-HTTPS-origin-to-distinct-peer-HTTP; not public Pages'
    assert c['native']['base'] == BASE and c['native']['origin'] == ORIGIN
    assert c['native']['version'] == '2.0.22' and c['native']['baselinePreserved'] is True
    foreground = c['native']['foreground']
    supervisor = foreground['supervisor']
    assert supervisor['event'] == 'started' and type(supervisor['uid']) is int and supervisor['uid'] == 0
    assert type(supervisor['pid']) is int and supervisor['pid'] > 0
    assert foreground['layer'] == 'Foreground'
    assert type(foreground['sessionId']) is str and 0 < len(foreground['sessionId']) <= 256
    assert foreground['config'] == {'TCP': {'8443': {'HTTPS': True}},
        'Web': {ORIGIN.removeprefix('https://'): {'Handlers': {'/': {'Proxy': 'http://127.0.0.1:45130'}}}}}
    assert c['native']['isolation'] == {'privateEnvironment': True, 'inheritedProviderCredentials': False}
    assert c['native']['static']['listenerOwned'] is True
    assert c['native']['static']['address'] == '127.0.0.1' and c['native']['static']['port'] == 45130
    assert type(c['native']['static']['pid']) is int and c['native']['static']['pid'] != c['native']['pid']
    assert '100.123.123.3' in c['native']['peerIPs'] and c['localIPs']
    assert not set(c['localIPs']) & set(c['native']['peerIPs'])
    assert c['page'] == {'origin': ORIGIN, 'secureContext': True}
    assert set(c['buildProvenance']['inputsSHA256']) == {'lib/main.dart', 'pubspec.yaml', 'pubspec.lock', 'web/index.html'}
    assert c['buildProvenance']['inputsSHA256']['lib/main.dart'] == c['sourceSHA256']
    assert c['buildSHA256'] == c['servedBuildSHA256'] == c['buildProvenance']['buildSHA256']
    assert c['buildProvenance']['argv'] == [
        ['rtk', 'proxy', 'flutter', 'pub', 'get', '--offline'],
        ['rtk', 'proxy', 'flutter', 'analyze', '--no-pub'],
        ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn']]
    assert not any('disable-web-security' in arg or 'ignore-certificate' in arg or 'unsafely-treat' in arg
                   or 'disable-features' in arg or 'host-resolver' in arg for arg in c['browserArgs'])
    assert c['browser']['product'].startswith('Chrome/154.')
    assert any(e.get('path') == '/main.dart.js' and e.get('status') == 200
               and e.get('remoteIP') in c['native']['peerIPs'] and e.get('securityState') == 'secure'
               and e.get('tls', {}).get('protocol') in ['TLS 1.2', 'TLS 1.3'] for e in c['bootstrap'])
    assert any(e.get('path', '').endswith('.wasm') and e.get('status') == 200
               and e.get('mediaType') == 'application/wasm' for e in c['bootstrap'])
    guards = {g['id']: g for g in c['guards']}
    assert len(guards) == len(c['guards'])
    operations = {o['label']: o for o in c['operations']}
    assert len(operations) == len(c['operations'])
    for o in c['operations']:
        g = guards[o['guardId']]
        assert g['listenerOwned'] is True and g['binarySHA256'] == BINARY_SHA
        assert type(g['pid']) is int and g['pid'] == c['native']['pid'] and g['socket'] == c['native']['socket']
        assert g['label'] == o['label'] and g['atMs'] <= o['atMs']
    for label, path in [('BrowserInfo', '/api/info'), ('BrowserSnapshot', '/api/session/' + c['session']),
                        ('BrowserSSEStart', '/api/event'), ('BrowserTicket', '/api/pty/' + c['pty'] + '/connect-token')]:
        operation = operations[label]
        assert type(operation['result']['ok']) is bool
        rows = [n for n in c['network'] if n['path'] == path and n.get('guardId') == operation['guardId']]
        assert rows
        if operation['result']['ok'] is False:
            assert any(n.get('failure') and any(n['failure'].get(key) for key in ['blocked', 'cors', 'errorCode']) for n in rows)
    info, snapshot = (operations[label]['result'] for label in ['BrowserInfo', 'BrowserSnapshot'])
    readable = all(o.get('ok') is True and type(o.get('status')) is int for o in [info, snapshot])
    assert c['observation'] == ('browser-http-readable' if readable else 'browser-http-not-readable')
    sse = operations['BrowserSSEStart']['result']
    if sse.get('ok') is True and sse.get('httpStatus') == 200:
        live = operations['BrowserSSELive']['result']
        assert len(live['chunks']) >= 2
        assert any(e['type'] == 'server.connected' for e in live['events'])
        assert any(e['type'] == 'session.renamed' and c['session'] in json.dumps(e)
                   and 'Tailpeer native 🚀' in json.dumps(e, ensure_ascii=False) for e in live['events'])
        assert operations['BrowserSSEStop']['result']['aborted'] is True
    ticket = operations['BrowserTicket']['result']
    if ticket.get('ok') is True and ticket.get('status') == 200:
        assert 'BrowserWSOpen' in operations
        ws = operations['BrowserWSOpen']['result']
        assert type(ws['ok']) is bool
        if ws['ok'] is True:
            assert type(ws['opened']) is bool and type(ws['failed']) is bool
        else:
            assert type(ws['errorType']) is str
        if ws.get('opened') is True and ws.get('failed') is False:
            assert 'ECHO:TAILPEER_PING' in operations['BrowserWSEcho']['result']['text']
            assert c['wsObservation'] == 'opened-with-native-echo'
        else:
            guard_id = operations['BrowserWSOpen']['guardId']
            ws_rows = [e for e in c['network'] if e.get('guardId') == guard_id and e.get('method') == 'WS']
            policy = any(e.get('guardId') == guard_id and e.get('nativeWebSocket') is True
                         and any(e.get(k) for k in ['mixedContent', 'localNetwork', 'cors']) for e in c['policyLogs'])
            policy = policy or any(e.get('failure') and (e['failure'].get('blocked') or e['failure'].get('cors')) for e in ws_rows)
            http_rejected = any(400 <= e.get('status', 0) <= 599 for e in ws_rows)
            transport = not policy and not http_rejected and any(e.get('wsFailureObserved')
                or (e.get('failure') or {}).get('errorCode') and not e['failure'].get('canceled') for e in ws_rows)
            assert policy or http_rejected or transport
            assert c['wsObservation'] == ('browser-policy-blocked' if policy else 'server-http-handshake-rejected' if http_rejected else 'transport-failed')
            assert c['wsFailureEvidence'] == {'policy': bool(policy), 'httpHandshakeRejected': bool(http_rejected), 'transport': bool(transport)}
            assert c['wsClientResultKind'] == ('bridge-exception' if ws['ok'] is False else 'socket-state')
        if ws['ok'] is True:
            assert operations['BrowserWSClose']['result']['ok'] is True
        else:
            assert 'BrowserWSClose' not in operations
    else:
        reason = (f"browser-ticket-http-status-{ticket['status']}; no control-plane fallback" if ticket['ok'] is True
                  else 'browser-ticket-fetch-rejected; no control-plane fallback')
        assert c['wsNotObservedReason'] == reason
        assert 'BrowserWSOpen' not in operations
    cleanup = c['cleanup']
    stopped = cleanup['remote']['serveSupervisor']
    assert stopped['event'] == 'stopped' and stopped['childReaped'] is True
    assert stopped['pid'] == supervisor['pid'] and type(stopped['exitCode']) is int
    assert cleanup['errors'] == [] and cleanup['remote']['errors'] == []
    assert 0 <= cleanup['elapsedMs'] <= 120000
    assert cleanup['remote']['budgetSeconds'] == 50 and 0 <= cleanup['remote']['elapsedSeconds'] <= 55
    for key in ['browserCredentialsCleared', 'browserProcessesStopped', 'remoteRootAbsent', 'snapRootAbsent', 'localServeBaselinePreserved']:
        assert cleanup[key] is True
    for key in ['sessionAbsent', 'ptyAbsent', 'ptyProcessAbsent', 'portsAbsent', 'ownedProcessesStopped', 'serveBaselineRestored']:
        assert cleanup['remote'][key] is True
    calls = cleanup['remote']['calls']
    for label, path in [('VerifySessionAbsent', '/api/session/' + c['session']), ('VerifyPtyAbsent', '/api/pty/' + c['pty'])]:
        assert any(call['label'] == label and call['path'] == path and call['status'] == 404
                   and call['listenerOwned'] is True for call in calls)
    return {'result': 'valid-observation', 'observation': c['observation'],
            'checkpointAccepted': False, 'publicOriginLANTested': False, 'nativeInferenceTurns': 0}


if __name__ == '__main__':
    root = Path(sys.argv[1]).resolve()
    capture = json.loads((root / 'evidence/capture.json').read_text())
    result = validate(capture)
    if (root / 'app/lib/main.dart').exists():
        assert sha(root / 'app/lib/main.dart') == capture['sourceSHA256']
        assert sha(root / 'app/build/web/main.dart.js') == capture['buildSHA256']
        for path, expected in capture['buildProvenance']['inputsSHA256'].items():
            assert sha(root / 'app' / path) == expected
    else:
        assert sha(root / 'flutter_main.dart.txt') == capture['sourceSHA256']
    (root / 'evidence/validation.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result))
