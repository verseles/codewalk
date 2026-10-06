"""Offline semantic validation; synthetic controls never count as native evidence."""
import argparse
import copy
import hashlib
import json
from pathlib import Path


def require(condition, label):
    if not condition:
        raise ValueError(label)


def validate(c):
    require(c['result'] == 'managed-restart-browser-subset-pass', 'native result')
    require(type(c['nativeInferenceTurns']) is int and c['nativeInferenceTurns'] == 0, 'turns')
    require(type(c['inferenceCostUSD']) in (int, float) and c['inferenceCostUSD'] == 0, 'cost')
    require(c['nativeArgv'] == ['serve', '--service', '--log-level', 'none'], 'managed mode')
    require(c['archiveSHA256'] == '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b', 'archive')
    require(c['binarySHA256'] == 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815', 'binary')
    require(c['buildSHA256'] == c['servedBuildSHA256'], 'compiled bytes served')
    build = c['buildProvenance']
    require(build['buildSHA256'] == c['buildSHA256'] and build['inputsSHA256']['lib/main.dart'] == c['sourceSHA256'], 'source/build provenance')
    require(build['argv'] == ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn'], 'controlled build command')
    require(0 <= build['finishedAt'] - build['startedAt'] < 1200, 'compile budget')
    require(c['allowedOrigin'] != c['deniedOrigin'] and c['allowedOrigin'].startswith('http://cw-sp04-allowed.test:'), 'origins')
    services = c['services']
    require(len(services) == 2 and services[0]['pid'] != services[1]['pid'], 'PID restart')
    for s in services:
        require(type(s['pid']) is int and s['pid'] > 0 and bool(s['socket']), 'owned identity')
        require(s['version'] == '2.0.22' and s['passwordStable'] is True, 'version/auth')
        require(s['config']['cors'] == [c['allowedOrigin']] and s['config']['port'] == c['nativePort'], 'persisted config')
        require(s['config']['passwordPresent'] is True, 'private password persisted')
    require(services[0]['id'] != services[1]['id'] and services[0]['url'] == services[1]['url'], 'new instance/same port')
    require(c['initialConfig']['cors'] == [c['allowedOrigin']], 'initial CLI configuration')
    require(services[0]['atMs'] < c['restartStartedMs'] <= c['oldListenerGoneMs'] <= services[1]['atMs'], 'restart ordering')
    cors_sets = [x for x in c['cli'] if x['args'] == ['service', 'set', 'cors', c['allowedOrigin']] and x['ok'] is True]
    require(len(cors_sets) == 2 and cors_sets[0]['atMs'] <= services[0]['atMs'] and cors_sets[1]['startMs'] >= c['restartStartedMs'], 'official CORS writes')
    final = c['final']
    require(final['ok'] is True and final['visibility'] == 'visible' and final['recoveryError'] is None, 'real recovery')
    require(type(final['activeReaders']) is int and final['activeReaders'] == 1, 'active reader')
    require(type(final['maxActiveReaders']) is int and final['maxActiveReaders'] == 1 and type(final['activeAttempts']) is int and final['activeAttempts'] == 1, 'no overlap')
    attempts = final['attempts']
    first = attempts[0]
    require(first['number'] == 1 and first['connected'] is True and first['ended'] is True and first['released'] is True, 'old reader termination')
    require(first['locallyAborted'] is False and first['fatal'] is False and first['outcome'] in ('eof', 'read-error'), 'natural disconnect')
    require(c['restartStartedMs'] <= first['releasedMs'] <= first['endedMs'], 'natural reader release time')
    marks = [m for m in final['milestones'] if m['kind'] == 'streamRecovered']
    require(len(marks) == 1, 'one recovered stream')
    m = marks[0]
    disconnects = [x for x in final['milestones'] if x['kind'] == 'naturalDisconnect']
    require(len(disconnects) == 1 and disconnects[0]['attempt'] == 1, 'natural disconnect marker')
    require(0 <= m['atMs'] - disconnects[0]['atMs'] < 20000 and len(attempts) <= 13, 'bounded recovery')
    require(m['id'] == c['sessionID'] and m['title'] == 'SP04 managed live 🚀' and m['fromAttempt'] == 1, 'authoritative snapshot identity/title')
    require(type(m['attempt']) is int and 1 < m['attempt'] <= len(attempts), 'new stream number')
    new = attempts[m['attempt'] - 1]
    require(new['connected'] is True and new['ended'] is False and new['status'] == 200 and new['mediaType'].startswith('text/event-stream'), 'new SSE response')
    require(first['endedMs'] <= new['startedMs'] <= new['readerMs'] <= m['atMs'], 'release before reconnect/hydration')
    for a in attempts:
        if a['readerMs'] is not None:
            require(a['status'] == 200 and a['mediaType'].startswith('text/event-stream'), 'reader response')
        if a['ended'] is True and a['readerMs'] is not None:
            require(a['released'] is True and a['releasedMs'] <= a['endedMs'], 'all locks released')
    readers = [a for a in attempts if a['readerMs'] is not None]
    for old, later in zip(readers, readers[1:]):
        require(old['releasedMs'] is not None and old['releasedMs'] <= later['readerMs'], 'reader intervals')
    def events(a, title):
        return [e for e in a['events'] if e['event']['type'] == 'session.renamed' and
                e['event']['data']['sessionID'] == c['sessionID'] and e['event']['data']['title'] == title]
    require(events(first, 'SP04 managed live 🚀') and len(first['chunks']) >= 2, 'initial incremental event')
    live = events(new, 'SP04 managed resumed live')
    require(len(live) == 1 and live[0]['atMs'] > m['atMs'] and not events(first, 'SP04 managed resumed live'), 'later live event on new reader')
    require(any(e['event']['type'] == 'server.connected' and e['atMs'] <= m['atMs'] for e in new['events']), 'new connected frame')
    labels = {o['label']: o for o in c['operations'] if o['label'] != 'FinalShutdown'}
    require(labels['AllowedInfo']['result']['ok'] is True and labels['AllowedInfo']['result']['status'] == 200, 'readable allowed')
    require(labels['BadAuthInfo']['result']['ok'] is True and labels['BadAuthInfo']['result']['status'] == 401, 'readable auth control')
    require(all(labels[k]['result']['ok'] is False for k in ('DeniedInfo', 'DeniedSSE')), 'denied browser reads')
    shutdown = [o for o in c['operations'] if o['label'] == 'FinalShutdown']
    require(len(shutdown) == 2 and {o['page'] for o in shutdown} == {'allowed', 'denied'}, 'both shutdowns')
    for o in shutdown:
        s = o['result']
        require(s['ok'] is True and s['credentialsCleared'] is True and type(s['activeReaders']) is int and s['activeReaders'] == 0 and type(s['activeAttempts']) is int and s['activeAttempts'] == 0, 'strict shutdown')
    net = c['network']
    require(any(e['page'] == 'allowed' and e['path'] == '/api/session/' + c['sessionID'] and e['method'] == 'GET' and e.get('status') == 200 and
                new['readerMs'] <= e['atMs'] <= m['atMs'] and e.get('authorizationPresent') is True for e in net), 'Chrome authoritative hydration GET')
    guards = c['authenticationGuards']
    require(guards and any(g['owned'] is True and g['pid'] == services[1]['pid'] and c['oldListenerGoneMs'] <= g['atMs'] <= new['readerMs'] for g in guards), 'owned replacement before browser authentication')
    for g in guards:
        require(type(g['owned']) is bool and type(g['atMs']) is int, 'strict ownership proof')
        if g['owned']:
            require(g['pid'] in {s['pid'] for s in services}, 'known owned process')
    for e in net:
        require(type(e['authorizationPresent']) is bool and type(e['atMs']) is int, 'strict network auth marker/time')
    used_proofs = set()
    for e in sorted(net, key=lambda e: e['atMs']):
        if e['authorizationPresent']:
            prior = [(i, g) for i, g in enumerate(guards) if g['atMs'] <= e['atMs']]
            require(prior, 'authentication requires preceding owned proof')
            i, proof = max(prior, key=lambda pair: (pair[1]['atMs'], pair[0]))
            require(proof['owned'] is True and i not in used_proofs, 'authentication requires fresh owned proof')
            if e['atMs'] >= c['oldListenerGoneMs']:
                require(proof['pid'] == services[1]['pid'], 'authentication requires replacement process')
            used_proofs.add(i)
    for a in attempts:
        if a['outcome'] == 'unowned-listener':
            require(a['ended'] is True and a['connected'] is False and a['released'] is False and
                    a['status'] is None and a['mediaType'] is None and a['readerMs'] is None and
                    a['releasedMs'] is None and a['events'] == [] and a['chunks'] == [], 'denied retry made no native read')
            require(any(g['owned'] is False and c['oldListenerGoneMs'] <= a['startedMs'] <= g['atMs'] <= a['endedMs']
                        for g in guards), 'denied retry ownership correlation')
    for path in ('/api/info', '/api/event'):
        require(any(e['page'] == 'denied' and e['path'] == path and e.get('failure', {}).get('cors') and
                    'access-control-allow-origin' not in e.get('response', {}) for e in net), 'actual denied Chrome CORS')
    sse = [e for e in net if e['page'] == 'allowed' and e['path'] == '/api/event' and e['method'] == 'GET' and e.get('status') == 200]
    require(len(sse) >= 2 and any(e['atMs'] >= c['oldListenerGoneMs'] for e in sse), 'Chrome new request')
    for e in sse:
        require(e.get('authorizationPresent') is True and e.get('response', {}).get('access-control-allow-origin') == c['allowedOrigin'], 'authorized exact-origin SSE')
    calls = {x['label']: x for x in c['calls']}
    require(calls['CreateOwnedSession']['status'] == 200 and calls['VerifyDeletedSession']['status'] == 404, 'owned session lifecycle')
    require(all(x['listenerOwned'] is True for x in c['calls']), 'API ownership')
    cleanup = c['cleanup']
    require(cleanup['errors'] == [] and all(cleanup[k] is True for k in ('session404', 'processGroupsAbsent', 'listenersAbsent', 'snapPrivateRootAbsent', 'nativeRuntimeAbsent')), 'cleanup')
    def secrets(o):
        if isinstance(o, dict):
            require(not ({k.lower() for k in o} & {'password', 'authorization', 'last-event-id'}), 'secret/cursor field')
            for v in o.values(): secrets(v)
        elif isinstance(o, list):
            for v in o: secrets(v)
        elif isinstance(o, str):
            require(not o.startswith('Basic ') and '[REDACTED]' not in o, 'secret in evidence')
    secrets(c)


def self_test(c):
    validate(c)
    controls = [
        ('PID', lambda x: x['services'][1].update(pid=x['services'][0]['pid'])),
        ('mode', lambda x: x.update(nativeArgv=['serve', '--cors'])),
        ('origin', lambda x: x['services'][1]['config'].update(cors=[x['deniedOrigin']])),
        ('password', lambda x: x['services'][1].update(passwordStable=False)),
        ('release', lambda x: x['final']['attempts'][0].update(released=False)),
        ('local abort', lambda x: x['final']['attempts'][0].update(locallyAborted=True)),
        ('reader overlap', lambda x: x['final'].update(maxActiveReaders=2)),
        ('snapshot', lambda x: next(m for m in x['final']['milestones'] if m['kind'] == 'streamRecovered').update(id='wrong')),
        ('title', lambda x: next(m for m in x['final']['milestones'] if m['kind'] == 'streamRecovered').update(title='wrong')),
        ('no live event', lambda x: x['final']['attempts'][-1].update(events=[])),
        ('cleanup', lambda x: x['cleanup'].update(listenersAbsent=False)),
        ('secret', lambda x: x.update(password='private')),
        ('boolean readers', lambda x: x['final'].update(activeReaders=True)),
        ('boolean max readers', lambda x: x['final'].update(maxActiveReaders=True)),
        ('boolean attempts', lambda x: x['final'].update(activeAttempts=True)),
        ('source provenance', lambda x: x['buildProvenance']['inputsSHA256'].update({'lib/main.dart': 'wrong'})),
        ('build provenance', lambda x: x['buildProvenance'].update(buildSHA256='wrong')),
        ('late recovery', lambda x: next(m for m in x['final']['milestones'] if m['kind'] == 'naturalDisconnect').update(atMs=next(m for m in x['final']['milestones'] if m['kind'] == 'streamRecovered')['atMs'] - 20000)),
        ('missing disconnect', lambda x: x['final'].update(milestones=[m for m in x['final']['milestones'] if m['kind'] != 'naturalDisconnect'])),
        ('too many attempts', lambda x: x['final'].update(attempts=x['final']['attempts'] + [copy.deepcopy(x['final']['attempts'][0])] * 14)),
        ('missing hydration GET', lambda x: x.update(network=[e for e in x['network'] if e['path'] != '/api/session/' + x['sessionID']])),
        ('missing ownership proof', lambda x: x.update(authenticationGuards=[])),
        ('late ownership proof', lambda x: x.update(authenticationGuards=[{**g, 'atMs': next(m for m in x['final']['milestones'] if m['kind'] == 'streamRecovered')['atMs'] + 1} for g in x['authenticationGuards']])),
        ('turns', lambda x: x.update(nativeInferenceTurns=1)),
        ('authentication before proof', lambda x: x['network'].append({'page': 'allowed', 'path': '/api/info', 'method': 'GET',
            'atMs': min(g['atMs'] for g in x['authenticationGuards']) - 1, 'authorizationPresent': True})),
        ('old proof after listener exit', lambda x: x['network'].append({'page': 'allowed', 'path': '/api/event', 'method': 'GET',
            'atMs': x['oldListenerGoneMs'] + 1, 'authorizationPresent': True, 'failure': {'blocked': 'connection-refused'}})),
        ('reused ownership proof', lambda x: x['authenticationGuards'].pop()),
        ('numeric auth marker', lambda x: x['network'].append({'page': 'allowed', 'path': '/api/event', 'method': 'GET',
            'atMs': x['oldListenerGoneMs'] + 1, 'authorizationPresent': 1})),
        ('missing auth marker', lambda x: x['network'].append({'page': 'allowed', 'path': '/api/event', 'method': 'GET',
            'atMs': x['oldListenerGoneMs'] + 1})),
    ]
    if any(a['outcome'] == 'unowned-listener' for a in c['final']['attempts']):
        controls += [
            ('missing denial proof', lambda x: x.update(authenticationGuards=[g for g in x['authenticationGuards'] if g['owned']])),
            ('authentication after denial', lambda x: x['network'].append({'page': 'allowed', 'path': '/api/event', 'method': 'GET',
                'atMs': next(g['atMs'] for g in x['authenticationGuards'] if g['owned'] is False) + 1, 'authorizationPresent': True})),
            ('native response on denied retry', lambda x: next(a for a in x['final']['attempts'] if a['outcome'] == 'unowned-listener').update(status=200)),
        ]
    for label, mutation in controls:
        altered = copy.deepcopy(c); mutation(altered)
        try: validate(altered)
        except (ValueError, KeyError, TypeError, IndexError): continue
        raise ValueError('negative control accepted: ' + label)
    return len(controls)


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--capture', type=Path, default=Path(__file__).parent / 'evidence/capture.json')
    parser.add_argument('--self-test', action='store_true')
    args = parser.parse_args()
    raw = args.capture.read_bytes(); capture = json.loads(raw)
    validate(capture)
    controls = self_test(capture) if args.self_test else 0
    print(json.dumps({'validation': 'pass', 'negativeControls': controls,
                      'captureSHA256': hashlib.sha256(raw).hexdigest()}))
