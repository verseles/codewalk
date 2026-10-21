"""Read-only validation of observed SP04 configured-origin evidence, never a live runner."""
import copy
import hashlib
import json
import re
import sys
from pathlib import Path


STATE_OPERATIONS = ('InitialConnected', 'InitialLive', 'ArmLifecycle', 'FinalObservedState', 'FinalShutdown')


def require(condition, message):
    if not condition:
        raise ValueError(message)


def validate(c):
    require(c['result'] == 'configured-origin-browser-subset-pass' and not c['smoke'], 'native result')
    require(not c.get('failure') and not c['cleanup']['errors'], 'failure or cleanup')
    for key in ['session404', 'snapPrivateRootAbsent', 'processGroupsAbsent', 'listenersAbsent', 'nativeRuntimeAbsent']:
        require(c['cleanup'].get(key) is True, 'cleanup ' + key)
    require(c['archiveSHA256'] == '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b', 'archive provenance')
    require(c['archiveMemberSHA256'] == c['binarySHA256'] ==
            'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815', 'executed binary provenance')
    require(c['browserLaunch'] == 'confined-direct-binary'
            and all(re.fullmatch(r'/tmp/opencode/codewalk-sp04-[A-Za-z0-9-]+/' + key, value)
                    for key, value in c['browserPrivateRoots'].items())
            and set(c['browserPrivateRoots']) == {'home', 'config', 'data', 'cache', 'state', 'tmp', 'run'},
            'effective private browser roots')
    require(c['info']['version'] == '2.0.22' and c['info']['pid'] > 0, 'native identity')
    require(c['isolation'] == {'modelsFetchDisabled': True, 'projectConfigDisabled': True,
                              'inheritedProviderCredentials': False}, 'native isolation')
    require(c['nativeInferenceTurns'] == 0 and c['inferenceCostUSD'] == 0, 'zero inference budget')
    require(c['served']['/main.dart.js'] == c['buildSHA256'], 'served bundle')
    require(re.fullmatch(r'http://cw-sp04-allowed\.test:\d+', c['allowedOrigin']), 'configured origin')
    require(re.fullmatch(r'http://cw-sp04-denied\.test:\d+', c['deniedOrigin']), 'rejected origin')
    ops = {o['label']: o['result'] for o in c['operations']}
    require(ops['ConfigureAllowed']['origin'] == c['allowedOrigin'], 'actual allowed origin')
    require(ops['ConfigureDenied']['origin'] == c['deniedOrigin'], 'actual denied origin')
    require(ops['AllowedInfo']['ok'] and ops['AllowedInfo']['status'] == 200, 'readable authenticated info')
    require(ops['BadAuthInfo']['ok'] and ops['BadAuthInfo']['status'] == 401, 'readable wrong-auth response')
    require(not ops['DeniedInfo']['ok'] and not ops['DeniedSSE']['ok'], 'browser rejected info/SSE')
    net = c['network']
    for path in ['/api/info', '/api/event']:
        allowed = [n for n in net if n.get('page') == 'allowed' and n.get('path') == path]
        require(any(n.get('method') == 'OPTIONS' and n.get('request', {}).get('origin') == c['allowedOrigin']
                    and n.get('response', {}).get('access-control-allow-origin') == c['allowedOrigin']
                    and 'authorization' in n.get('response', {}).get('access-control-allow-headers', '').lower()
                    for n in allowed), 'allowed preflight ' + path)
        require(any(n.get('method') == 'GET' and n.get('authorizationPresent') and n.get('status') == 200
                    for n in allowed), 'authenticated browser GET ' + path)
        denied = [n for n in net if n.get('page') == 'denied' and n.get('path') == path]
        require(any(n.get('failure', {}).get('cors') for n in denied), 'observed browser CORS failure ' + path)
        require(any(n.get('method') == 'OPTIONS' and n.get('request', {}).get('origin') == c['deniedOrigin']
                    and n.get('response', {}).get('access-control-allow-origin') is None for n in denied),
                'denied actual-origin preflight ' + path)
    sid = c['sessionID']
    for call in c['calls']:
        require(call['listenerOwned'] is True, 'listener owner before auth')
        require(call['path'] in ['/api/info', '/api/session', '/api/session/' + sid], 'unadmitted native endpoint')
        require(call['method'] in ['GET', 'POST', 'PATCH', 'DELETE'], 'unadmitted native method')
    require(sum(call['method'] == 'POST' for call in c['calls']) == 1, 'one owned session creation')
    calls = {call['label']: call for call in c['calls']}
    live = ops['InitialLive']['attempts'][0]
    require(live['connected'] and not live['ended'] and live['status'] == 200
            and live['mediaType'].startswith('text/event-stream') and len(live['chunks']) >= 2, 'incremental open SSE')
    require(live['events'][0]['event']['type'] == 'server.connected', 'native connected frame')
    require(any(e['event']['type'] == 'session.renamed' and e['event']['data']['sessionID'] == sid
                and e['event']['data']['title'] == calls['RenameFirst']['title']
                and e['read'] > live['events'][0]['read'] and e['atMs'] >= calls['RenameFirst']['startedMs']
                for e in live['events']), 'incremental owned native rename')
    final = c['final']
    final_records = [o for o in c['operations'] if o['label'] == 'FinalObservedState']
    require(len(final_records) == 1 and final_records[0]['page'] == 'allowed'
            and json.dumps(final, sort_keys=True) == json.dumps(final_records[0]['result'], sort_keys=True),
            'matching final observed state')
    require(final['origin'] == c['allowedOrigin'] and final['lifecycleError'] is None, 'lifecycle origin/errors')
    arming = [o for o in c['operations'] if o['label'] == 'ArmLifecycle']
    require(len(arming) == 1 and arming[0]['page'] == 'allowed'
            and arming[0]['result']['ok'] is True and arming[0]['result']['origin'] == c['allowedOrigin']
            and arming[0]['result']['visibility'] == 'visible', 'armed visible page')
    if c['lifecycleResult'] == 'observed-page-visibility-recovery':
        marks = final['lifecycle']
        armed_ms = arming[0]['atMs']
        hidden = next(m for m in marks if m['kind'] == 'hiddenStopped')
        recovered = next(m for m in marks if m['kind'] == 'visibleRecovered')
        stopped = final['attempts'][hidden['attempt'] - 1]
        resumed = final['attempts'][recovered['attempt'] - 1]
        require(stopped['ended'] and stopped['released'] and stopped['endedMs'] <= hidden['atMs'], 'awaited hidden stop')
        require(hidden['atMs'] <= calls['RenameHiddenGap']['startedMs'] <= recovered['atMs'], 'hidden gap order')
        require(any(m['kind'] == 'visibilitychange' and m['state'] == 'hidden'
                    and armed_ms <= m['atMs'] <= stopped['endedMs'] for m in marks), 'real armed hidden')
        require(any(m['kind'] == 'visibilitychange' and m['state'] == 'visible' and hidden['atMs'] <= m['atMs'] <= recovered['atMs'] for m in marks), 'real visible')
        require(recovered['id'] == sid and recovered['title'] == calls['RenameHiddenGap']['title'], 'authoritative snapshot')
        require(resumed['connected'] and resumed['number'] > stopped['number'], 'fresh stream')
        require(any(e['event'].get('data', {}).get('title') == calls['RenameResumedLive']['title']
                    and e['event']['data']['sessionID'] == sid for e in resumed['events']), 'later live delivery')
    else:
        require(c['lifecycleResult'] == 'inconclusive-no-hidden-marker', 'lifecycle result')
        for operation in c['operations']:
            if operation['page'] != 'allowed' or operation['label'] not in STATE_OPERATIONS:
                continue
            state = operation['result']
            require(not any(m['kind'] in ['hiddenStopped', 'visibleRecovered'] or (m['kind'] == 'visibilitychange'
                            and m.get('state') == 'hidden') for m in state['lifecycle']), 'honest lifecycle inconclusion')
            require(len(state['attempts']) == 1 and type(state['attempts'][0]['number']) is int
                    and state['attempts'][0]['number'] == 1, 'no inconclusive resumed stream')
        require(not any(call['label'] in ['RenameHiddenGap', 'RenameResumedLive'] for call in c['calls']),
                'no inconclusive recovery calls')
    shutdowns = [o for o in c['operations'] if o['label'] == 'FinalShutdown']
    require(len(shutdowns) == 2 and {o['page'] for o in shutdowns} == {'allowed', 'denied'},
            'both page shutdown records')
    origins = {'allowed': c['allowedOrigin'], 'denied': c['deniedOrigin']}
    require(all(o['result']['ok'] is True and o['result']['origin'] == origins[o['page']]
                and o['result']['credentialsCleared'] is True
                and type(o['result']['activeReaders']) is int and o['result']['activeReaders'] == 0
                for o in shutdowns), 'reader/credential shutdown')
    require(not re.search(r'Basic\s+[A-Za-z0-9+/=]+|"(?:authorization|password|ticket|token)"\s*:', json.dumps(c), re.I), 'secret export')


if __name__ == '__main__':
    root = Path(__file__).resolve().parent
    path = root / 'evidence/capture.json'
    c = json.loads(path.read_text())
    validate(c)
    source = root / 'app/lib/main.dart'
    if not source.is_file():
        source = root / 'flutter_main.dart.txt'
    require(hashlib.sha256(source.read_bytes()).hexdigest() == c['sourceSHA256'], 'source provenance')
    if '--self-test' in sys.argv:
        def set_final(d, snapshot):
            d['final'] = copy.deepcopy(snapshot)
            next(o for o in d['operations'] if o['label'] == 'FinalObservedState')['result'] = copy.deepcopy(snapshot)

        mutations = [lambda d: d['cleanup'].update(session404=False),
                     lambda d: d.update(sessionID='ses_wrong'),
                     lambda d: d.update(allowedOrigin=d['deniedOrigin']),
                     lambda d: d.update(binarySHA256='0' * 64),
                     lambda d: d['calls'][0].update(listenerOwned=False),
                     lambda d: d['browserPrivateRoots'].update(home='/home/shared'),
                     lambda d: d.update(buildSHA256='0' * 64),
                     lambda d: d.update(operations=[o for o in d['operations'] if o['label'] != 'ArmLifecycle']),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'ArmLifecycle')['result'].update(ok='false'),
                     lambda d: d.update(operations=[o for o in d['operations'] if o['label'] != 'FinalShutdown']),
                     lambda d: d.update(operations=[o for o in d['operations']
                                                   if not (o['label'] == 'FinalShutdown' and o['page'] == 'allowed')]),
                     lambda d: d.update(operations=[o for o in d['operations']
                                                   if not (o['label'] == 'FinalShutdown' and o['page'] == 'denied')]),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(ok=False),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(origin=d['deniedOrigin']),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(ok='false'),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(credentialsCleared='false'),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(activeReaders=False),
                     lambda d: next(o for o in d['operations'] if o['label'] == 'FinalShutdown')['result'].update(activeReaders=0.0),
                     lambda d: d['final'].update(activeReaders=99)]
        if c['lifecycleResult'] == 'observed-page-visibility-recovery':
            mutations.append(lambda d: set_final(d, dict(d['final'], lifecycle=[m for m in d['final']['lifecycle']
                                                                              if m.get('state') != 'hidden'])))
            mutations.append(lambda d: set_final(d, dict(d['final'], lifecycle=[m for m in d['final']['lifecycle']
                                                                              if not (m.get('state') == 'hidden'
                                                                                      and m['atMs'] >= next(o['atMs'] for o in d['operations']
                                                                                                           if o['label'] == 'ArmLifecycle'))])))
        cases = [(c, mutate) for mutate in mutations]
        if c['lifecycleResult'] == 'observed-page-visibility-recovery':
            inconclusive = copy.deepcopy(c)
            inconclusive['lifecycleResult'] = 'inconclusive-no-hidden-marker'
            for operation in inconclusive['operations']:
                if operation['page'] != 'allowed' or operation['label'] not in STATE_OPERATIONS:
                    continue
                state = operation['result']
                state['lifecycle'] = [m for m in state['lifecycle']
                                      if m['kind'] not in ['hiddenStopped', 'visibleRecovered'] and m.get('state') != 'hidden']
                state['attempts'] = state['attempts'][:1]
            snapshot = copy.deepcopy(next(o for o in inconclusive['operations'] if o['label'] == 'ArmLifecycle')['result'])
            set_final(inconclusive, snapshot)
            inconclusive['calls'] = [call for call in inconclusive['calls']
                                     if call['label'] not in ['RenameHiddenGap', 'RenameResumedLive']]
            validate(inconclusive)
            cases.append((inconclusive, lambda d: d.update(operations=[o for o in d['operations']
                                                                      if o['label'] != 'ArmLifecycle'])))
            for kind in ['hiddenStopped', 'visibleRecovered', 'visibilitychange']:
                cases.append((inconclusive, lambda d, kind=kind: set_final(
                    d, dict(d['final'], lifecycle=d['final']['lifecycle'] + [{'kind': kind, 'state': 'hidden'}]))))
            for label in ['RenameHiddenGap', 'RenameResumedLive']:
                recovery_call = next(call for call in c['calls'] if call['label'] == label)
                cases.append((inconclusive, lambda d, call=recovery_call: d['calls'].append(copy.deepcopy(call))))
            resumed_attempt = c['final']['attempts'][1]
            cases.append((inconclusive, lambda d: set_final(
                d, dict(d['final'], attempts=d['final']['attempts'] + [resumed_attempt]))))
            for label in ['ArmLifecycle', 'FinalShutdown']:
                for kind in ['hiddenStopped', 'visibleRecovered', 'visibilitychange']:
                    marker = next(m for m in c['final']['lifecycle']
                                  if m['kind'] == kind and (kind != 'visibilitychange' or m.get('state') == 'hidden'))
                    cases.append((inconclusive, lambda d, label=label, marker=marker: next(
                        o for o in d['operations'] if o['label'] == label and o['page'] == 'allowed'
                    )['result']['lifecycle'].append(copy.deepcopy(marker))))
                cases.append((inconclusive, lambda d, label=label: next(
                    o for o in d['operations'] if o['label'] == label and o['page'] == 'allowed'
                )['result']['attempts'].append(copy.deepcopy(resumed_attempt))))
        for baseline, mutate in cases:
            broken = copy.deepcopy(baseline)
            mutate(broken)
            try:
                validate(broken)
            except (ValueError, KeyError, StopIteration):
                continue
            raise ValueError('tampered evidence accepted')
    print(json.dumps({'validation': 'pass', 'lifecycle': c['lifecycleResult'],
                      'captureSHA256': hashlib.sha256(path.read_bytes()).hexdigest()}))
