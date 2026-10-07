"""Synthetic controls only. Never starts a browser, native server or SSH."""
import copy
import unittest
import signal
import time
import json
from pathlib import Path
import tempfile
from unittest.mock import patch
from prepare import remaining, arm_deadline, rebuild
from validate import validate, ARCHIVE_SHA, BINARY_SHA, ORIGIN, BASE
import peer


def blocked_example():
    c = {'result': 'observed', 'nativeInferenceTurns': 0, 'inferenceCostUSD': 0,
         'securityOverrides': [], 'archiveSHA256': ARCHIVE_SHA, 'binarySHA256': BINARY_SHA,
         'budgets': {'setupSeconds': 1200, 'collectionSeconds': 180, 'cleanupSeconds': 120, 'preparationDebitSeconds': 180},
          'setupElapsedMs': 1000, 'collectionElapsedMs': 1000, 'policyLogs': [],
         'nativeArgv': ['serve', '--hostname', '100.123.123.3', '--port', '45131', '--cors', ORIGIN],
         'scope': 'private-Tailscale-HTTPS-origin-to-distinct-peer-HTTP; not public Pages',
          'native': {'base': BASE, 'origin': ORIGIN, 'version': '2.0.22', 'baselinePreserved': True,
                     'foreground': {'layer': 'Foreground', 'sessionId': 'owned', 'config': peer.foreground_config(),
                                    'supervisor': {'event': 'started', 'uid': 0, 'pid': 5679}},
                    'peerIPs': ['100.123.123.3'], 'pid': 1234, 'socket': '81',
                    'static': {'pid': 5678, 'socket': '82', 'listenerOwned': True, 'address': '127.0.0.1', 'port': 45130},
                    'isolation': {'privateEnvironment': True, 'inheritedProviderCredentials': False}},
         'localIPs': ['100.123.123.1'], 'page': {'origin': ORIGIN, 'secureContext': True},
         'sourceSHA256': '1' * 64, 'buildSHA256': '2' * 64, 'servedBuildSHA256': '2' * 64,
          'buildProvenance': {'inputsSHA256': {'lib/main.dart': '1' * 64, 'pubspec.yaml': '3' * 64,
                                            'pubspec.lock': '4' * 64, 'web/index.html': '5' * 64}, 'buildSHA256': '2' * 64,
                            'argv': [['rtk', 'proxy', 'flutter', 'pub', 'get', '--offline'],
                                     ['rtk', 'proxy', 'flutter', 'analyze', '--no-pub'],
                                     ['rtk', 'proxy', 'flutter', 'build', 'web', '--release', '--no-pub', '--no-web-resources-cdn']]},
         'browser': {'product': 'Chrome/154.0.0.0'}, 'browserArgs': ['--headless=new'],
         'bootstrap': [{'path': '/main.dart.js', 'status': 200, 'remoteIP': '100.123.123.3',
                        'securityState': 'secure', 'tls': {'protocol': 'TLS 1.3'}},
                       {'path': '/canvaskit/canvaskit.wasm', 'status': 200, 'mediaType': 'application/wasm'}],
         'guards': [], 'operations': [], 'network': [], 'session': 'ses_test', 'pty': 'pty_test',
         'observation': 'browser-http-not-readable',
         'wsNotObservedReason': 'browser-ticket-fetch-rejected; no control-plane fallback',
         'cleanup': {'errors': [], 'browserCredentialsCleared': True, 'browserProcessesStopped': True,
                     'remoteRootAbsent': True, 'snapRootAbsent': True, 'localServeBaselinePreserved': True, 'elapsedMs': 3000,
                     'remote': {'errors': [], 'sessionAbsent': True, 'ptyAbsent': True, 'portsAbsent': True,
                                'serveSupervisor': {'event': 'stopped', 'pid': 5679, 'childReaped': True, 'exitCode': -15},
                                'ownedProcessesStopped': True, 'ptyProcessAbsent': True, 'serveBaselineRestored': True, 'budgetSeconds': 50, 'elapsedSeconds': 2, 'calls': [
                                  {'label': 'VerifySessionAbsent', 'path': '/api/session/ses_test', 'status': 404, 'listenerOwned': True},
                                  {'label': 'VerifyPtyAbsent', 'path': '/api/pty/pty_test', 'status': 404, 'listenerOwned': True}]}}}
    for i, (label, path) in enumerate([('BrowserInfo', '/api/info'), ('BrowserSnapshot', '/api/session/ses_test'),
                                     ('BrowserSSEStart', '/api/event'), ('BrowserTicket', '/api/pty/pty_test/connect-token')], 1):
        c['guards'].append({'id': i, 'label': label, 'listenerOwned': True, 'binarySHA256': BINARY_SHA,
                            'pid': 1234, 'socket': '81', 'atMs': 100})
        c['operations'].append({'label': label, 'guardId': i, 'atMs': 101, 'result': {'ok': False, 'errorType': 'JSObject'}})
        c['network'].append({'path': path, 'guardId': i, 'failure': {'blocked': 'mixed-content', 'cors': None, 'errorCode': None}})
    return c


class SemanticControls(unittest.TestCase):
    def test_block_is_not_checkpoint_acceptance(self):
        result = validate(blocked_example())
        self.assertFalse(result['checkpointAccepted'])
        self.assertFalse(result['publicOriginLANTested'])

    def test_security_and_evidence_mutations_rejected(self):
        changes = [
            lambda c: c.update(result='inconclusive'),
            lambda c: c.update(nativeInferenceTurns=True),
            lambda c: c.update(inferenceCostUSD=1),
            lambda c: c.update(securityOverrides=['ignoreTLS']),
            lambda c: c.update(binarySHA256='0' * 64),
            lambda c: c['nativeArgv'].__setitem__(2, '0.0.0.0'),
            lambda c: c['native'].update(base='http://127.0.0.1:45131'),
            lambda c: c['native'].update(origin='http://coolify.uaru-nase.ts.net:8443'),
            lambda c: c['native'].update(baselinePreserved=False),
            lambda c: c['native']['isolation'].update(inheritedProviderCredentials=True),
            lambda c: c.update(localIPs=['100.123.123.3']),
            lambda c: c['page'].update(secureContext=False),
            lambda c: c.update(servedBuildSHA256='0' * 64),
            lambda c: c['browserArgs'].append('--ignore-certificate-errors'),
            lambda c: c['browserArgs'].append('--disable-features=LocalNetworkAccessChecks'),
            lambda c: c['bootstrap'][0].update(remoteIP='127.0.0.1'),
            lambda c: c['bootstrap'][0].update(securityState='insecure'),
            lambda c: c['bootstrap'][1].update(mediaType='application/octet-stream'),
            lambda c: c['guards'][0].update(listenerOwned=False),
            lambda c: c['guards'][0].update(pid=4321),
            lambda c: c['guards'][0].update(socket='82'),
            lambda c: c['guards'][0].update(atMs=102),
            lambda c: c['operations'][0].update(guardId=99),
            lambda c: c['network'][0].update(guardId=99),
            lambda c: c['network'][0].update(failure=None),
            lambda c: c.update(observation='browser-http-readable'),
            lambda c: c['cleanup'].update(remoteRootAbsent=False),
            lambda c: c['cleanup'].update(browserCredentialsCleared=False),
            lambda c: c['cleanup']['remote'].update(serveBaselineRestored=False),
            lambda c: c['cleanup']['remote']['calls'][0].update(path='/api/session/ses_foreign'),
            lambda c: c['cleanup']['remote']['calls'][1].update(status=200),
            lambda c: c['native']['static'].update(listenerOwned=False),
            lambda c: c['native']['static'].update(address='0.0.0.0'),
            lambda c: c.update(collectionElapsedMs=180001),
            lambda c: c['cleanup'].update(elapsedMs=120001),
            lambda c: c['budgets'].update(cleanupSeconds=121),
            lambda c: c.update(setupElapsedMs=1200000),
            lambda c: c['budgets'].update(preparationDebitSeconds=1200),
            lambda c: c['buildProvenance']['inputsSHA256'].pop('pubspec.yaml'),
            lambda c: c['buildProvenance']['inputsSHA256'].pop('pubspec.lock'),
            lambda c: c['buildProvenance']['inputsSHA256'].pop('web/index.html'),
            lambda c: c['native']['foreground'].update(layer='TCP'),
            lambda c: c['native']['foreground'].update(sessionId=''),
            lambda c: c['native']['foreground']['config']['TCP']['8443'].update(HTTPS=False),
            lambda c: c['native']['foreground']['supervisor'].update(uid=1001),
            lambda c: c['cleanup']['remote']['serveSupervisor'].update(childReaped=False),
            lambda c: c['cleanup']['remote']['serveSupervisor'].update(pid=9999),
        ]
        for i, change in enumerate(changes):
            with self.subTest(control=i):
                capture = copy.deepcopy(blocked_example())
                change(capture)
                with self.assertRaises((AssertionError, KeyError)):
                    validate(capture)

    def test_http_error_ticket_is_not_browser_block(self):
        capture = blocked_example()
        capture['operations'][-1]['result'] = {'ok': True, 'status': 401}
        capture['network'][-1] = {'path': '/api/pty/pty_test/connect-token', 'guardId': 4, 'status': 401}
        capture['wsNotObservedReason'] = 'browser-ticket-http-status-401; no control-plane fallback'
        validate(capture)
        capture['wsNotObservedReason'] = 'browser-ticket-fetch-rejected; no control-plane fallback'
        with self.assertRaises(AssertionError):
            validate(capture)

    def test_sse_http_error_is_a_response_not_network_failure(self):
        capture = blocked_example()
        capture['operations'][2]['result'] = {'ok': True, 'httpStatus': 401, 'events': [], 'chunks': []}
        capture['network'][2] = {'path': '/api/event', 'guardId': 3, 'status': 401}
        validate(capture)

    def test_ws_exception_needs_correlated_browser_policy(self):
        capture = blocked_example()
        capture['operations'][-1]['result'] = {'ok': True, 'status': 200}
        capture['network'][-1] = {'path': '/api/pty/pty_test/connect-token', 'guardId': 4, 'status': 200}
        capture['guards'].append({'id': 5, 'label': 'BrowserWSOpen', 'listenerOwned': True, 'binarySHA256': BINARY_SHA, 'pid': 1234, 'socket': '81', 'atMs': 100})
        capture['operations'].append({'label': 'BrowserWSOpen', 'guardId': 5, 'atMs': 101, 'result': {'ok': False, 'errorType': 'JSObject'}})
        capture['wsObservation'] = 'browser-policy-blocked'
        capture['wsFailureEvidence'] = {'policy': True, 'httpHandshakeRejected': False, 'transport': False}
        capture['wsClientResultKind'] = 'bridge-exception'
        with self.assertRaises(AssertionError):
            validate(capture)
        capture['policyLogs'] = [{'guardId': 5, 'mixedContent': True, 'nativeWebSocket': True}]
        validate(capture)
        capture['policyLogs'] = []
        capture['network'].append({'guardId': 5, 'path': '/api/pty/pty_test/connect', 'method': 'WS', 'failure': {'errorCode': 'net::ERR_CONNECTION_CLOSED'}})
        capture['wsObservation'] = 'transport-failed'
        capture['wsFailureEvidence'] = {'policy': False, 'httpHandshakeRejected': False, 'transport': True}
        validate(capture)
        row = capture['network'][-1]
        for failure in [{'blocked': 'mixed-content'}, {'cors': 'LocalNetworkAccessPermissionDenied'}]:
            row['failure'] = failure
            capture['wsObservation'] = 'browser-policy-blocked'
            capture['wsFailureEvidence'] = {'policy': True, 'httpHandshakeRejected': False, 'transport': False}
            validate(capture)
            capture['wsObservation'] = 'transport-failed'
            with self.assertRaises(AssertionError):
                validate(capture)
        del row['failure']
        for status in [401, 403]:
            row['status'] = status
            capture['wsObservation'] = 'server-http-handshake-rejected'
            capture['wsFailureEvidence'] = {'policy': False, 'httpHandshakeRejected': True, 'transport': False}
            validate(capture)
            capture['wsObservation'] = 'transport-failed'
            with self.assertRaises(AssertionError):
                validate(capture)

    def test_shared_setup_deadline_interrupts_blocking_wait(self):
        with self.assertRaises(TimeoutError):
            remaining(time.monotonic() - 1, 1)
        self.assertLessEqual(remaining(time.monotonic() + 1, .01), .01)
        previous = arm_deadline(time.monotonic() + .02)
        try:
            with self.assertRaises(TimeoutError):
                time.sleep(.1)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, previous)

    def test_rebuild_refresh_uses_remaining_preparation_budget(self):
        with tempfile.TemporaryDirectory(prefix='codewalk-sp04-tailpeer-', dir='/tmp/opencode') as directory:
            root = Path(directory)
            (root / 'admission.json').write_text(json.dumps({'preparationElapsedSeconds': 1199}))
            started = time.monotonic()
            with patch('prepare.refresh', side_effect=lambda _: time.sleep(5)), patch('prepare.subprocess.run') as command:
                with self.assertRaises(TimeoutError):
                    rebuild(root)
                command.assert_not_called()
            self.assertLess(time.monotonic() - started, 2)


class ForegroundControls(unittest.TestCase):
    def baseline(self):
        return {'TCP': {'3001': {'HTTPS': True}, '4097': {'HTTPS': True}},
                'Web': {'other:3001': {'Handlers': {'/': {'Proxy': 'http://127.0.0.1:3000'}}}},
                'Foreground': {'foreign': {'TCP': {'9000': {'HTTPS': True}}}}}

    def active(self, before):
        after = copy.deepcopy(before)
        after.setdefault('Foreground', {})['owned'] = peer.foreground_config()
        return after

    def test_nested_route_admitted_without_mutating_baseline(self):
        for before in [self.baseline(), {}, {'Foreground': {}}]:
            after = self.active(before)
            saved = copy.deepcopy(after)
            peer.route_free(before)
            self.assertEqual(peer.admit_foreground(before, before), None)
            self.assertEqual(peer.admit_foreground(before, after), 'owned')
            self.assertEqual(after, saved)

    def test_foreground_and_baseline_mutations_rejected(self):
        changes = [
            lambda s: s['Foreground'].__setitem__('second', peer.foreground_config()),
            lambda s: s['Foreground']['foreign']['TCP'].clear(),
            lambda s: s['Foreground'].pop('foreign'),
            lambda s: s['TCP']['3001'].update(HTTPS=False),
            lambda s: s.update(Unexpected=True),
            lambda s: s['Foreground']['owned']['TCP']['8443'].update(HTTPS=False),
            lambda s: s['Foreground']['owned']['TCP'].__setitem__('9001', {'HTTPS': True}),
            lambda s: s['Foreground']['owned']['Web'][ORIGIN.removeprefix('https://')]['Handlers']['/'].update(Proxy='http://wrong:45130'),
            lambda s: s['Foreground']['owned']['Web'][ORIGIN.removeprefix('https://')]['Handlers'].__setitem__('/extra', {'Text': 'unexpected'}),
            lambda s: s['Foreground']['owned'].update(AllowFunnel={ORIGIN.removeprefix('https://'): True}),
            lambda s: s['Foreground']['owned'].update(Foreground={}),
            lambda s: s.update(Foreground=[]),
        ]
        before = self.baseline()
        for i, change in enumerate(changes):
            with self.subTest(control=i):
                after = self.active(before)
                change(after)
                with self.assertRaises(AssertionError):
                    peer.admit_foreground(before, after)
        with self.assertRaises(AssertionError):
            peer.admit_foreground(before, {**before, **peer.foreground_config()})

    def test_existing_top_or_foreground_collision_rejected(self):
        for config in [{'TCP': {'8443': {'HTTPS': True}}},
                       {'Web': {ORIGIN.removeprefix('https://'): {}}}]:
            for before in [config, {'Foreground': {'foreign': config}}]:
                with self.assertRaises(AssertionError):
                    peer.route_free(before)

    def test_child_exit_and_deadline_stop_admission(self):
        before = self.baseline()
        with patch('peer.serve_status', return_value=before) as status:
            with self.assertRaisesRegex(AssertionError, 'process exited'):
                peer.wait_foreground(type('Exited', (), {'poll': lambda _: 1})(), before)
            status.assert_not_called()
            with patch('peer.time.monotonic', side_effect=[0, 16]):
                with self.assertRaisesRegex(AssertionError, 'admission timeout'):
                    peer.wait_foreground(type('Running', (), {'poll': lambda _: None})(), before)

    def test_cleanup_waits_for_entire_baseline_and_never_writes_config(self):
        before = self.baseline()
        with patch('peer.time.sleep'), patch('peer.subprocess.run') as command:
            with patch('peer.serve_status', side_effect=[self.active(before), before]):
                peer.wait_baseline(before)
            with patch('peer.serve_status', return_value=self.active(before)), patch('peer.time.monotonic', side_effect=[0, 6]):
                with self.assertRaisesRegex(AssertionError, 'baseline not restored'):
                    peer.wait_baseline(before)
            command.assert_not_called()


if __name__ == '__main__':
    unittest.main()
