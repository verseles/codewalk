import assert from 'node:assert/strict';
import { Cdp, wsFailure, remoteFailure, remoteCleanupReady } from './cdp.mjs';
import { now, remaining } from './budget.mjs';
assert.throws(() => remaining(now() - 1), /deadline/);
assert(remaining(now() + 1000, 50) <= 50);
const c = new Cdp();
Object.assign(c, { sessionId: 'own', base: 'http://100.123.123.3:45131', origin: 'https://coolify.uaru-nase.ts.net:8443',
  capture: { network: [], bootstrap: [], policyLogs: [] }, requests: new Map(), guardId: 7 });
const event = (method, params) => c.message({ method, params, sessionId: 'own' });
event('Network.requestWillBeSentExtraInfo', { requestId: 'a', headers: { Authorization: 'secret', Origin: c.origin } });
event('Network.requestWillBeSent', { requestId: 'a', request: { url: c.base + '/api/info', method: 'GET', headers: {} } });
assert.equal(c.capture.network[0].authorizationPresent, true);
assert.equal(c.capture.network[0].request.origin, c.origin);
event('Network.loadingFailed', { requestId: 'a', canceled: false, blockedReason: 'mixed-content', errorText: 'net::ERR_FAILED' });
assert.equal(c.capture.network[0].failure.blocked, 'mixed-content');
event('Network.webSocketCreated', { requestId: 'ws', url: c.base.replace('http', 'ws') + '/api/pty/own/connect?ticket=live-secret' });
assert.equal(c.capture.network[1].ticketPresent, true);
event('Log.entryAdded', { entry: { level: 'error', text: 'Mixed Content: ws://host/connect?ticket=live-secret' } });
assert.equal(c.capture.policyLogs[0].mixedContent, true);
assert(!JSON.stringify(c.capture).includes('secret'));
assert.equal(c.capture.network[0].guardId, 7);
const wsCapture = (row) => ({ network: [{ guardId: 9, method: 'WS', ...row }], policyLogs: [] });
for (const failure of [{ blocked: 'mixed-content', errorCode: 'net::ERR_FAILED' }, { cors: 'LocalNetworkAccessPermissionDenied' }]) {
  const result = wsFailure(wsCapture({ failure }), 9);
  assert.equal(result.observation, 'browser-policy-blocked');
  assert.deepEqual(result.evidence, { policy: true, httpHandshakeRejected: false, transport: false });
}
for (const status of [401, 403]) {
  const result = wsFailure(wsCapture({ status, wsFailureObserved: true }), 9);
  assert.equal(result.observation, 'server-http-handshake-rejected');
  assert.deepEqual(result.evidence, { policy: false, httpHandshakeRejected: true, transport: false });
}
assert.equal(wsFailure(wsCapture({ failure: { errorCode: 'net::ERR_CONNECTION_CLOSED' } }), 9).observation, 'transport-failed');
assert.throws(() => wsFailure(wsCapture({ failure: { canceled: true, errorCode: 'net::ERR_ABORTED' } }), 9), /correlated/);
assert.throws(() => wsFailure(wsCapture({ guardId: 8, status: 403 }), 9), /correlated/);
const failure = remoteFailure({ id: 1, errorType: 'AssertionError', phase: 'foreground-admission', serveExitCode: 1,
  message: 'password=live-secret', stderr: 'ticket=live-secret' });
assert.deepEqual(failure.remoteFacts, { id: 1, errorType: 'AssertionError', phase: 'foreground-admission', serveExitCode: 1 });
assert(!JSON.stringify(failure.remoteFacts).includes('secret'));
assert(!failure.message.includes('secret'));
assert.deepEqual(remoteFailure({ id: 'secret', errorType: 'live-secret', phase: 'live-secret', serveExitCode: 'secret' }).remoteFacts,
  { id: null, errorType: 'RemoteError', phase: 'unknown', serveExitCode: null });
const earlyCleanup = { errors: [], serveBaselineRestored: true, ownedProcessesStopped: true, portsAbsent: true,
  sessionNotAttempted: true, ptyNotAttempted: true, serveNotAttempted: true };
assert.equal(remoteCleanupReady(earlyCleanup), true);
assert.equal(remoteCleanupReady({ ...earlyCleanup, ptyNotAttempted: false }), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, errors: ['unknown PTY'] }), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, serveBaselineRestored: false }), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, sessionNotAttempted: false, ptyNotAttempted: false,
  sessionAbsent: true, ptyAbsent: true, ptyProcessAbsent: true }), true);
assert.equal(remoteCleanupReady(undefined), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, serveNotAttempted: false }), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, serveNotAttempted: false, serveSupervisor: { childReaped: false } }), false);
assert.equal(remoteCleanupReady({ ...earlyCleanup, serveNotAttempted: false, serveSupervisor: { childReaped: true } }), true);
console.log('CDP, typed WS/remote failure, foreground cleanup admission and deadline controls pass');
