// Opt-in single capture. Run only after exact remote command approval and review.
import assert from 'node:assert/strict';
import { spawn, execFile } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { readFile, writeFile, mkdir, lstat } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { Cdp, wsFailure, remoteFailure, remoteCleanupReady } from './cdp.mjs';
import { now, remaining } from './budget.mjs';

const captureStarted = now();
const root = dirname(fileURLToPath(import.meta.url)), exec = promisify(execFile);
assert.match(root, /^\/tmp\/opencode\/codewalk-sp04-tailpeer-[a-z0-9_-]+$/);
assert.equal(process.argv[2], '--run-approved');
assert.equal((await lstat(root)).mode & 0o777, 0o700);
assert.equal((await lstat(root)).uid, process.getuid());
assert(!(await lstat(root)).isSymbolicLink());
const admission = JSON.parse(await readFile(join(root, 'admission.json'), 'utf8'));
assert.deepEqual([admission.captureSeconds, admission.budgetSeconds, admission.cleanupSeconds], [180, 1200, 120]);
const preparationDebit = admission.preparationElapsedSeconds;
assert(Number.isInteger(preparationDebit) && preparationDebit > 0 && preparationDebit < 1200);
const setupEnd = captureStarted + (1200 - preparationDebit) * 1000;
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
assert.equal(digest(await readFile(join(root, 'package/bin/opencode'))), admission.binarySHA256);
const proof = JSON.parse(await readFile(join(root, 'build-provenance.json'), 'utf8'));
assert.deepEqual(Object.keys(proof.inputsSHA256).sort(), ['lib/main.dart', 'pubspec.lock', 'pubspec.yaml', 'web/index.html']);
for (const [path, expected] of Object.entries(proof.inputsSHA256)) {
  assert.equal(digest(await readFile(join(root, 'app', path))), expected, `prepared input changed: ${path}`);
  remaining(setupEnd);
}
assert.equal(proof.inputsSHA256['lib/main.dart'], admission.sourceSHA256);
assert.equal(digest(await readFile(join(root, 'app/build/web/main.dart.js'))), proof.buildSHA256);
const launchEnv = Object.fromEntries(['HOME', 'PATH', 'USER', 'LOGNAME', 'LANG'].filter((k) => process.env[k]).map((k) => [k, process.env[k]]));
const sshArgs = ['-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', 'ubuntu@coolify'];
remaining(setupEnd);
let activeEnd = setupEnd, collectionStarted, cleanupStarted, cleaning = false;
const run = (command, args, options = {}) => {
  if (!cleaning && abort.signal.aborted) throw new Error('capture interrupted');
  return exec(command, args, { env: launchEnv, ...options,
    ...(cleaning ? {} : { signal: abort.signal }), timeout: remaining(activeEnd, options.timeout ?? 15000) });
};
const remote = root, cleanup = { errors: [] }, children = [];
const capture = { startedAt: new Date().toISOString(), nativeInferenceTurns: 0, inferenceCostUSD: 0,
  sourceSHA256: admission.sourceSHA256, buildSHA256: proof.buildSHA256, archiveSHA256: admission.archiveSHA256,
  binarySHA256: admission.binarySHA256, buildProvenance: proof,
  scope: 'private-Tailscale-HTTPS-origin-to-distinct-peer-HTTP; not public Pages',
  budgets: { setupSeconds: 1200, collectionSeconds: 180, cleanupSeconds: 120, preparationDebitSeconds: preparationDebit },
  securityOverrides: [], nativeArgv: ['serve', '--hostname', '100.123.123.3', '--port', '45131', '--cors', 'https://coolify.uaru-nase.ts.net:8443'],
  guards: [], operations: [], network: [], bootstrap: [], policyLogs: [], cleanup };
const abort = new AbortController();
for (const sig of ['SIGINT', 'SIGTERM', 'SIGHUP']) process.on(sig, () => { if (!cleaning) abort.abort(); });
let deadline, peer, peerCleanup, peerClosed, cdp, chrome, transferred = false, configured = false;
let password = randomBytes(32).toString('hex');
let authorization = `Basic ${Buffer.from(`opencode:${password}`).toString('base64')}`;
const delay = (ms) => new Promise((yes) => setTimeout(yes, ms));
const secrets = [password, authorization];
const safe = (data) => {
  let text = JSON.stringify(data, null, 2);
  for (const secret of secrets) text = text.replaceAll(secret, '[REDACTED]');
  return text.replaceAll(remote, '[OWNED_CAPTURE_ROOT]').replace(/ticket=[^&\s"']+/g, 'ticket=[REDACTED]') + '\n';
};
async function save() {
  await mkdir(join(root, 'evidence'), { recursive: true, mode: 0o700 });
  await writeFile(join(root, 'evidence/capture.json'), safe(capture), { mode: 0o600 });
}
async function waitFor(check, timeout = 12000, cleaning = false) {
  const end = now() + remaining(activeEnd, timeout);
  while (now() < end) {
    if (!cleaning && abort.signal.aborted) throw new Error('capture deadline');
    const value = await check(); if (value) return value;
    await delay(100);
  }
  throw new Error('bounded observation timeout');
}
function child(command, args, cwd = root) {
  const p = spawn(command, args, { env: launchEnv, cwd, detached: true, stdio: ['pipe', 'pipe', 'pipe'] });
  p.on('error', () => {}); p.stdout.on('data', () => {}); p.stderr.on('data', () => {});
  p.stdin.on('error', () => {
    if (p === peer) { for (const v of pending.values()) { clearTimeout(v.timer); v.no(new Error('remote stdin closed')); } pending.clear(); }
  });
  children.push(p); return p;
}
async function terminate(p) {
  if (!p?.pid) return;
  const exists = () => { try { process.kill(-p.pid, 0); return true; } catch (e) { if (e.code === 'ESRCH') return false; throw e; } };
  if (exists()) process.kill(-p.pid, 'SIGTERM');
  await waitFor(() => !exists(), 3000, true).catch(() => {});
  if (exists()) process.kill(-p.pid, 'SIGKILL');
  await waitFor(() => !exists(), 1000, true);
}
let nextId = 0;
const pending = new Map();
function control(op, body = {}, cleaning = false) {
  assert(peer && peer.exitCode === null && peer.signalCode === null, 'remote control exited');
  const id = ++nextId;
  return new Promise((yes, no) => {
    const timer = setTimeout(() => { pending.delete(id); no(new Error('remote control timeout')); }, remaining(activeEnd, 60000));
    pending.set(id, { yes, no, timer });
    if (!cleaning && abort.signal.aborted) { clearTimeout(timer); pending.delete(id); no(new Error('capture deadline')); return; }
    peer.stdin.write(JSON.stringify({ id, op, ...body }) + '\n');
  });
}
async function op(label, input) {
  const guard = await control('guard');
  assert.equal(guard.listenerOwned, true); assert.equal(guard.binarySHA256, admission.binarySHA256);
  const id = capture.guards.length + 1;
  capture.guards.push({ id, label, atMs: Date.now(), ...guard }); cdp.guardId = id;
  const result = await cdp.evaluate(`window.cwTransport(${JSON.stringify(JSON.stringify(input))}).then(JSON.parse)`);
  capture.operations.push({ label, atMs: Date.now(), guardId: id, result });
  return result;
}
const success = (o) => o.ok === true && o.status === 200;
try {
  const localStatus = JSON.parse((await run('tailscale', ['status', '--json'], { timeout: 10000 })).stdout);
  capture.localIPs = localStatus.Self.TailscaleIPs;
  capture.localServeBaseline = JSON.parse((await run('tailscale', ['serve', 'status', '--json'], { timeout: 10000 })).stdout);
  const bundle = join(root, 'peer-bundle.tar');
  await run('tar', ['-cf', bundle, 'peer.py', 'serve_supervisor.py', 'package/bin/opencode', 'app/build/web'], { cwd: root, timeout: 60000 });
  await run('ssh', [...sshArgs, `if [ -f "$HOME/paths" ]; then . "$HOME/paths"; fi; test ! -L /tmp/opencode && test -d /tmp/opencode && test ! -e '${remote}' && mkdir -m 700 '${remote}'`], { timeout: 20000 });
  transferred = true;
  await run('scp', ['-q', '-o', 'BatchMode=yes', '-o', 'ConnectTimeout=10', bundle, `ubuntu@coolify:${remote}/peer-bundle.tar`], { timeout: 240000 });
  await run('ssh', [...sshArgs, `if [ -f "$HOME/paths" ]; then . "$HOME/paths"; fi; tar -xf '${remote}/peer-bundle.tar' -C '${remote}'`], { timeout: 60000 });
  peer = child('ssh', [...sshArgs, `if [ -f "$HOME/paths" ]; then . "$HOME/paths"; fi; exec python3 -B '${remote}/peer.py' '${remote}'`]);
  let lines = '';
  peer.stdout.on('data', (buffer) => {
    lines += buffer.toString();
    while (lines.includes('\n')) {
      const end = lines.indexOf('\n'), line = lines.slice(0, end); lines = lines.slice(end + 1);
      let o; try { o = JSON.parse(line); } catch { continue; }
      if (o.cleanup) { peerCleanup = o.cleanup; continue; }
      const p = pending.get(o.id);
      if (!p) {
        if (!o.ok) { const error = remoteFailure(o); for (const v of pending.values()) { clearTimeout(v.timer); v.no(error); } pending.clear(); }
        continue;
      }
      clearTimeout(p.timer); pending.delete(o.id);
      if (o.ok) p.yes(o.result); else p.no(remoteFailure(o));
    }
  });
  peer.on('close', () => { peerClosed = true; for (const p of pending.values()) { clearTimeout(p.timer); p.no(new Error('remote control closed')); } pending.clear(); });
  capture.setupElapsedMs = now() - captureStarted;
  collectionStarted = now(); activeEnd = Math.min(setupEnd, collectionStarted + 180000);
  deadline = setTimeout(() => abort.abort(), remaining(activeEnd, 180000));
  const native = await control('start', { password });
  capture.native = native;
  assert(native.peerIPs.includes('100.123.123.3'));
  assert(!capture.localIPs.some((ip) => native.peerIPs.includes(ip)), 'distinct peer required');
  const session = (await control('createSession')).session;
  const pty = (await control('createPty')).pty;
  capture.session = session; capture.pty = pty;
  const browserRoots = Object.fromEntries(['home', 'config', 'data', 'cache', 'state', 'tmp', 'run'].map((k) => [k, join(root, k)]));
  capture.browserRoots = browserRoots;
  const shell = `set -eu
umask 077
test ! -L /tmp/opencode && test ! -L '${root}'
export HOME='${browserRoots.home}' XDG_CONFIG_HOME='${browserRoots.config}' XDG_DATA_HOME='${browserRoots.data}' XDG_CACHE_HOME='${browserRoots.cache}' XDG_STATE_HOME='${browserRoots.state}' TMPDIR='${browserRoots.tmp}' XDG_RUNTIME_DIR='${browserRoots.run}'
export SNAP_REAL_HOME="$HOME" SNAP_USER_DATA='${root}/snap-data' SNAP_USER_COMMON='${root}/snap-common' CHROME_CONFIG_HOME="$XDG_CONFIG_HOME"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$TMPDIR" "$XDG_RUNTIME_DIR" "$SNAP_USER_DATA" "$SNAP_USER_COMMON"
exec "$SNAP/usr/lib/chromium-browser/chrome" "$@"`;
  capture.browserArgs = ['--headless=new', '--no-first-run', '--no-default-browser-check', '--password-store=basic',
    '--disable-background-networking', '--no-proxy-server', '--remote-debugging-port=0', '--remote-debugging-address=127.0.0.1', `--user-data-dir=${root}/browser`, 'about:blank'];
  chrome = child('/usr/bin/snap', ['run', '--shell', 'chromium', '-c', shell, 'cw-sp04-tailpeer', ...capture.browserArgs]);
  let endpoint;
  chrome.stderr.on('data', (buffer) => { endpoint ??= buffer.toString().match(/DevTools listening on (ws:\/\/127\.0\.0\.1:\d+\/[^\s]+)/)?.[1]; });
  await waitFor(() => endpoint, 30000);
  cdp = await Cdp.open(endpoint, capture, native.base, native.origin, waitFor, () => remaining(activeEnd, 15000));
  capture.browser = await cdp.call('Browser.getVersion');
  await cdp.page();
  capture.page = await cdp.evaluate('({origin:location.origin,secureContext:isSecureContext})');
  assert.deepEqual(capture.page, { origin: native.origin, secureContext: true });
  const loaded = capture.bootstrap.find((e) => e.path === '/main.dart.js' && e.status === 200);
  assert(loaded && native.peerIPs.includes(loaded.remoteIP) && loaded.securityState === 'secure');
  const body = await cdp.call('Network.getResponseBody', { requestId: loaded.id }, cdp.sessionId);
  capture.servedBuildSHA256 = digest(Buffer.from(body.body, body.base64Encoded ? 'base64' : 'utf8'));
  assert.equal(capture.servedBuildSHA256, capture.buildSHA256);
  assert(capture.bootstrap.some((e) => e.path.endsWith('.wasm') && e.status === 200 && e.mediaType === 'application/wasm'));
  await op('Configure', { op: 'configure', base: native.base, authorization, directory: native.directory, session }); configured = true;
  const info = await op('BrowserInfo', { op: 'info' });
  const snapshot = await op('BrowserSnapshot', { op: 'snapshot' });
  const sse = await op('BrowserSSEStart', { op: 'sseStart' });
  if (sse.ok && sse.httpStatus === 200) {
    await control('rename', { title: 'Tailpeer native 🚀' });
    await op('BrowserSSELive', { op: 'sseWait', marker: 'Tailpeer native 🚀' });
    await op('BrowserSSEStop', { op: 'sseStop' });
  }
  const ticket = await op('BrowserTicket', { op: 'ticket', pty, handle: 'own' });
  if (success(ticket)) {
    const ws = await op('BrowserWSOpen', { op: 'wsOpen', pty, handle: 'own', socket: 'own' });
    if (ws.opened && !ws.failed) {
      await op('BrowserWSReady', { op: 'wsWait', socket: 'own', marker: 'TAILPEER_READY' });
      await op('BrowserWSSend', { op: 'wsSend', socket: 'own', text: 'TAILPEER_PING\n' });
      await op('BrowserWSEcho', { op: 'wsWait', socket: 'own', marker: 'ECHO:TAILPEER_PING' });
      capture.wsObservation = 'opened-with-native-echo';
    } else {
      const guardId = capture.operations.at(-1).guardId;
      const failure = wsFailure(capture, guardId);
      capture.wsObservation = failure.observation;
      capture.wsFailureEvidence = failure.evidence;
      capture.wsClientResultKind = ws.ok === false ? 'bridge-exception' : 'socket-state';
    }
    if (ws.ok === true) await op('BrowserWSClose', { op: 'wsClose', socket: 'own' });
  } else capture.wsNotObservedReason = ticket.ok === true
    ? `browser-ticket-http-status-${ticket.status}; no control-plane fallback`
    : 'browser-ticket-fetch-rejected; no control-plane fallback';
  capture.observation = info.ok === true && snapshot.ok === true ? 'browser-http-readable' : 'browser-http-not-readable';
  capture.result = 'observed';
} catch (error) {
  capture.result = 'inconclusive'; capture.failure = { type: error.constructor.name, message: error.message,
    ...(error.remoteFacts ? { remote: error.remoteFacts } : {}) };
  process.exitCode = 1;
} finally {
  cleaning = true;
  clearTimeout(deadline);
  capture.collectionElapsedMs = collectionStarted ? now() - collectionStarted : null;
  // Reserve five seconds of the approved 120s for final group checks/evidence.
  cleanupStarted = now(); activeEnd = cleanupStarted + 115000;
  if (cdp) cdp.timeoutFor = () => remaining(activeEnd, 3000);
  if (configured && cdp) {
    try { const result = await cdp.evaluate('window.cwTransport("{\\"op\\":\\"shutdown\\"}").then(JSON.parse)');
      cleanup.browserCredentialsCleared = result.ok && result.credentialsCleared; assert(cleanup.browserCredentialsCleared); }
    catch (e) { cleanup.errors.push('browser:' + e.constructor.name); }
  }
  if (cdp) { try { await cdp.call('Browser.close'); } catch { /* Own process group termination follows. */ } cdp.socket.close(); }
  try { await terminate(chrome); cleanup.browserProcessesStopped = true; } catch (e) { cleanup.errors.push('chrome:' + e.constructor.name); }
  if (peer && !peerClosed) {
    try { peer.stdin.write(JSON.stringify({ id: ++nextId, op: 'cleanup' }) + '\n');
      await waitFor(() => peerCleanup && peerClosed, 55000, true); }
    catch (e) { cleanup.errors.push('remote:' + e.constructor.name); }
  }
  cleanup.remote = peerCleanup ?? { errors: ['remote cleanup result absent'] };
  try {
    if (transferred && remoteCleanupReady(peerCleanup)) {
      await run('ssh', [...sshArgs, `if [ -f "$HOME/paths" ]; then . "$HOME/paths"; fi; test ! -L '${remote}' && test -d '${remote}' && test "$(stat -c %u '${remote}')" = "$(id -u)" && rm -rf -- '${remote}' && test ! -e '${remote}'`], { timeout: 15000 });
      cleanup.remoteRootAbsent = true;
    }
    // Snap has a separate /tmp namespace. Remove only this invocation's own root.
    if (cleanup.browserProcessesStopped) {
      await run('snap', ['run', '--shell', 'chromium', '-c', `test ! -L /tmp/opencode && test ! -L '${root}' && if test -d '${root}'; then rm -rf -- '${root}'; fi; test ! -e '${root}'`], { timeout: 15000 });
      cleanup.snapRootAbsent = true;
    }
    const status = JSON.parse((await run('tailscale', ['serve', 'status', '--json'], { timeout: 10000 })).stdout);
    cleanup.localServeBaselinePreserved = JSON.stringify(status) === JSON.stringify(capture.localServeBaseline);
    assert(cleanup.localServeBaselinePreserved);
  } catch (e) { cleanup.errors.push('ownedRoot:' + e.constructor.name); }
  for (const p of children) { try { await terminate(p); } catch (e) { cleanup.errors.push('process:' + e.constructor.name); } }
  password = ''; authorization = '';
  cleanup.elapsedMs = now() - cleanupStarted;
  capture.finishedAt = new Date().toISOString();
  if (cleanup.errors.length || cleanup.remote.errors.length || !cleanup.remoteRootAbsent) { capture.result = 'inconclusive'; process.exitCode = 1; }
  await save();
  console.log(JSON.stringify({ result: capture.result, observation: capture.observation,
    cleanupErrors: [...cleanup.errors, ...cleanup.remote.errors], nativeInferenceTurns: 0, inferenceCostUSD: 0 }));
}
