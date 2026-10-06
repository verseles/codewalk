"""Synthetic validator regression controls, never a native capture or proof."""
import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('managed_restart_validator', Path(__file__).with_name('validate.py'))
assert spec is not None and spec.loader is not None
validator = importlib.util.module_from_spec(spec)
spec.loader.exec_module(validator)
self_test, validate = validator.self_test, validator.validate


def sample():
    origin = 'http://cw-sp04-allowed.test:4000'
    session = 'ses_synthetic_only'
    def event(kind, at, title=None):
        data = {'type': kind}
        if title is not None:
            data['data'] = {'sessionID': session, 'title': title}
        return {'event': data, 'atMs': at, 'read': 2}
    first = {'number': 1, 'connected': True, 'ended': True, 'released': True,
             'locallyAborted': False, 'fatal': False, 'outcome': 'eof',
             'status': 200, 'mediaType': 'text/event-stream', 'startedMs': 100,
             'readerMs': 110, 'releasedMs': 220, 'endedMs': 220,
             'chunks': [{'bytes': 2}, {'bytes': 3}],
             'events': [event('server.connected', 120),
                        event('session.renamed', 180, 'SP04 managed live 🚀')]}
    denied = {**first, 'number': 2, 'connected': False, 'released': False,
              'status': None, 'mediaType': None, 'outcome': 'unowned-listener',
              'startedMs': 270, 'readerMs': None, 'releasedMs': None, 'endedMs': 280,
              'events': [], 'chunks': []}
    new = {**first, 'number': 3, 'ended': False, 'released': False,
           'startedMs': 310, 'readerMs': 330, 'releasedMs': None, 'endedMs': None,
           'events': [event('server.connected', 340),
                      event('session.renamed', 380, 'SP04 managed resumed live')]}
    c = {'result': 'managed-restart-browser-subset-pass',
         'nativeInferenceTurns': 0, 'inferenceCostUSD': 0,
         'nativeArgv': ['serve', '--service', '--log-level', 'none'],
         'archiveSHA256': '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b',
         'binarySHA256': 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815',
         'sourceSHA256': 'a' * 64, 'buildSHA256': 'b' * 64, 'servedBuildSHA256': 'b' * 64,
         'buildProvenance': {'buildSHA256': 'b' * 64, 'inputsSHA256': {'lib/main.dart': 'a' * 64},
             'argv': ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn'],
             'startedAt': 1, 'finishedAt': 2},
         'allowedOrigin': origin, 'deniedOrigin': 'http://cw-sp04-denied.test:4000',
         'nativePort': 5000, 'sessionID': session, 'restartStartedMs': 200,
         'oldListenerGoneMs': 250, 'initialConfig': {'cors': [origin]},
         'cli': [{'args': ['service', 'set', 'cors', origin], 'ok': True, 'atMs': 90, 'startMs': 80},
                 {'args': ['service', 'set', 'cors', origin], 'ok': True, 'atMs': 210, 'startMs': 200}],
         'services': [{'pid': pid, 'id': str(pid), 'socket': str(pid), 'version': '2.0.22',
                       'passwordStable': True, 'config': {'cors': [origin], 'port': 5000, 'passwordPresent': True},
                       'atMs': at, 'url': 'http://127.0.0.1:5000'} for pid, at in [(111, 150), (222, 300)]],
         'final': {'ok': True, 'visibility': 'visible', 'recoveryError': None,
                   'activeReaders': 1, 'maxActiveReaders': 1, 'activeAttempts': 1,
                   'attempts': [first, denied, new], 'milestones': [
                       {'kind': 'naturalDisconnect', 'atMs': 230, 'attempt': 1},
                       {'kind': 'streamRecovered', 'atMs': 360, 'attempt': 3,
                        'fromAttempt': 1, 'id': session, 'title': 'SP04 managed live 🚀'}]},
         'operations': [{'label': label, 'result': {'ok': ok, 'status': status}}
                        for label, ok, status in [('AllowedInfo', True, 200),
                         ('BadAuthInfo', True, 401), ('DeniedInfo', False, None), ('DeniedSSE', False, None)]],
         'network': [{'page': 'denied', 'path': path, 'method': 'OPTIONS', 'atMs': 140,
                      'authorizationPresent': False, 'failure': {'cors': 'PreflightMissingAllowOriginHeader'}}
                     for path in ['/api/info', '/api/event']],
         'authenticationGuards': [{'owned': True, 'pid': 111, 'atMs': 95},
                                  {'owned': False, 'atMs': 275},
                                  {'owned': True, 'pid': 222, 'atMs': 320},
                                  {'owned': True, 'pid': 222, 'atMs': 345}],
         'calls': [{'label': label, 'status': status, 'listenerOwned': True}
                   for label, status in [('CreateOwnedSession', 200), ('VerifyDeletedSession', 404)]],
         'cleanup': {'errors': [], **{k: True for k in ['session404', 'processGroupsAbsent',
                     'listenersAbsent', 'snapPrivateRootAbsent', 'nativeRuntimeAbsent']}}}
    c['operations'] += [{'label': 'FinalShutdown', 'page': page, 'result':
                        {'ok': True, 'credentialsCleared': True, 'activeReaders': 0, 'activeAttempts': 0}}
                       for page in ['allowed', 'denied']]
    c['network'] += [{'page': 'allowed', 'path': '/api/event', 'method': 'GET',
                     'status': 200, 'atMs': at, 'authorizationPresent': True,
                     'response': {'access-control-allow-origin': origin}} for at in [100, 329]]
    c['network'].append({'page': 'allowed', 'path': '/api/session/' + session,
                        'method': 'GET', 'status': 200, 'atMs': 350, 'authorizationPresent': True})
    return c


class Controls(unittest.TestCase):
    def test_valid_synthetic_shape_and_all_corruptions(self):
        self.assertEqual(self_test(sample()), 32)

    def test_browser_recovers_before_collector_finishes_readiness_record(self):
        c = sample()
        c['services'][1]['atMs'] = 400
        c['final']['attempts'][-1]['events'][-1]['atMs'] = 450
        validate(c)

    def test_recovery_without_ownerless_attempt_is_valid(self):
        c = sample()
        c['final']['attempts'].pop(1)
        c['final']['attempts'][-1]['number'] = 2
        c['final']['milestones'][-1]['attempt'] = 2
        c['authenticationGuards'] = [g for g in c['authenticationGuards'] if g['owned']]
        self.assertEqual(self_test(c), 29)

    def test_shutdown_boolean_attempts_rejected(self):
        c = sample()
        c['operations'][-1]['result']['activeAttempts'] = False
        with self.assertRaises(ValueError): validate(c)

    def test_guard_from_wrong_process_rejected(self):
        c = sample()
        c['authenticationGuards'][0]['pid'] = 333
        with self.assertRaises(ValueError): validate(c)

    def test_fresh_old_process_proof_after_exit_rejected(self):
        c = sample()
        at = c['oldListenerGoneMs'] + 1
        c['authenticationGuards'].append({'owned': True, 'pid': c['services'][0]['pid'], 'atMs': at})
        c['network'].append({'page': 'allowed', 'path': '/api/event', 'method': 'GET',
                             'atMs': at + 1, 'authorizationPresent': True})
        with self.assertRaises(ValueError): validate(c)

    def test_snapshot_before_reader_rejected(self):
        c = sample()
        c['network'][-1]['atMs'] = 329
        with self.assertRaises(ValueError): validate(c)


if __name__ == '__main__':
    unittest.main()
