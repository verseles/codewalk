// Opt-in managed-service restart diagnostic; execute only in an owned /tmp root.
import assert from 'node:assert/strict';
import { spawn, execFile } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, lstat, rm, readdir, readlink } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
const exec = promisify(execFile), root = dirname(fileURLToPath(import.meta.url));
assert.match(root, /^\/tmp\/opencode\/codewalk-sp04-managed-[A-Za-z0-9-]+$/);
assert(!(await lstat(root)).isSymbolicLink());
const admission = JSON.parse(await readFile(join(root, 'admission.json'), 'utf8'));
assert(process.argv.includes('--run'), 'native execution requires explicit --run admission');
assert.equal(admission.budgetSeconds, 1200);
const env = admission.env, runtime = join(root, 'runtime'), binary = join(root, 'package/bin/opencode');
const configFile = join(env.XDG_CONFIG_HOME, 'opencode/service.json');
const registrationFile = join(env.XDG_STATE_HOME, 'opencode/service.json');
assert.equal(env.HOME, join(runtime, 'home'));
for (const key of ['CONFIG', 'DATA', 'CACHE', 'STATE']) assert.equal(env[`XDG_${key}_HOME`], join(runtime, key.toLowerCase()));
assert.equal(env.TMPDIR, join(runtime, 'tmp'));
assert.deepEqual(Object.keys(env).sort(), ['PATH', 'HOME', 'LANG', 'XDG_CONFIG_HOME', 'XDG_DATA_HOME',
  'XDG_CACHE_HOME', 'XDG_STATE_HOME', 'XDG_RUNTIME_DIR', 'TMPDIR', 'OPENCODE_DISABLE_MODELS_FETCH',
  'OPENCODE_CONFIG_PROJECT_DISABLE', 'OPENCODE_FILEWATCHER_DISABLE', 'OPENCODE_DISABLE_FFF'].sort());
const launcherEnv = Object.fromEntries(['HOME', 'PATH', 'USER', 'LOGNAME', 'LANG']
  .filter((k) => process.env[k]).map((k) => [k, process.env[k]]));
const digest = (b) => createHash('sha256').update(b).digest('hex');
assert.equal(digest(await readFile(binary)), admission.binarySHA256);
assert.equal(admission.binarySHA256, 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815');
const abort = new AbortController(), deadline = setTimeout(() => abort.abort(), 180_000);
for (const sig of ['SIGINT', 'SIGTERM']) process.once(sig, () => abort.abort());
const capture = { startedAt: new Date().toISOString(), calls: [], operations: [], network: [], services: [], cli: [], authenticationGuards: [], bootstrap: [],
   isolation: { privateEnvironment: true, inheritedProviderCredentials: false },
  nativeInferenceTurns: 0, inferenceCostUSD: 0, archiveSHA256: admission.archiveSHA256,
  binarySHA256: admission.binarySHA256, npmIntegrity: admission.npmIntegrity,
  nativeArgv: ['serve', '--service', '--log-level', 'none'] };
const cleanup = { errors: [] }, children = [];
let password = '', authorization = '', native, nativePort, base, session, cdp, allowedPage, deniedPage, staticServer, phase = 'static';
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const safe = (o) => {
  let text = JSON.stringify(o, null, 2);
  for (const secret of [password, authorization].filter(Boolean)) text = text.replaceAll(secret, '[REDACTED]');
  return text + '\n';
};
async function save() {
  await mkdir(join(root, 'evidence'), { recursive: true, mode: 0o700 });
  await writeFile(join(root, 'evidence/capture.json'), safe(capture), { mode: 0o600 });
}
async function waitFor(check, ms = 12000) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    if (abort.signal.aborted) throw new Error('run deadline');
    const result = await check(); if (result) return result;
    await delay(100);
  }
  throw new Error('bounded observation timeout');
}
function child(command, args, childEnv, cwd) {
  const p = spawn(command, args, { env: childEnv, cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
  p.on('error', () => {}); p.stdout.on('data', () => {}); p.stderr.on('data', () => {});
  children.push(p); return p;
}
async function terminate(p) {
  if (!p?.pid) return;
  const exists = () => { try { process.kill(-p.pid, 0); return true; }
    catch (e) { if (e.code === 'ESRCH') return false; throw e; } };
  if (exists()) process.kill(-p.pid, 'SIGTERM');
  for (let i = 0; i < 50 && exists(); i++) await delay(100);
  if (exists()) process.kill(-p.pid, 'SIGKILL');
  for (let i = 0; i < 50 && exists(); i++) await delay(100);
  assert(!exists(), 'owned group remains');
}
async function absent(port) {
  const server = createServer();
  await new Promise((yes, no) => { server.once('error', no); server.listen(port, '127.0.0.1', yes); });
  const selected = server.address().port;
  await new Promise((yes) => server.close(yes)); return selected;
}
async function owned() {
  if (!native?.pid || native.exitCode !== null || native.signalCode !== null) return false;
  let descriptors;
  try { descriptors = await readdir(`/proc/${native.pid}/fd`); }
  catch (e) { if (e.code === 'ENOENT') return false; throw e; }
  const links = await Promise.all(descriptors.map(async (fd) => {
    try { return await readlink(`/proc/${native.pid}/fd/${fd}`); } catch (e) { if (e.code === 'ENOENT') return ''; throw e; }
  }));
  const address = `0100007F:${nativePort.toString(16).toUpperCase().padStart(4, '0')}`;
  const socket = (await readFile('/proc/net/tcp', 'utf8')).split('\n').map((s) => s.trim().split(/\s+/))
    .find((f) => f[1] === address && f[3] === '0A' && links.includes(`socket:[${f[9]}]`));
  if (!socket) return false;
  assert.equal(digest(await readFile(`/proc/${native.pid}/exe`)), admission.binarySHA256);
  return { pid: native.pid, socket: socket[9] };
}
async function cli(args) {
  if (native && native.exitCode === null && native.signalCode === null) {
    assert(await owned(), 'CLI mutation requires owned listener');
    const registration = JSON.parse(await readFile(registrationFile, 'utf8'));
    assert.equal(registration.pid, native.pid); assert.equal(registration.url, base);
  }
  const startMs = Date.now();
  const result = await exec(binary, ['service', ...args], { env, cwd: join(runtime, 'project'),
    timeout: 15000, maxBuffer: 16384 });
  capture.cli.push({ args: ['service', ...args], startMs, atMs: Date.now(), ok: true });
  return result.stdout.trim();
}
async function config() {
  const o = JSON.parse(await readFile(configFile, 'utf8'));
  assert.equal((await lstat(configFile)).mode & 0o777, 0o600);
  assert.deepEqual(o.cors, [capture.allowedOrigin]); assert.equal(o.port, nativePort);
  return { cors: o.cors, port: o.port, passwordPresent: !!o.password };
}
async function api(label, method, path, body, cleaning = false) {
  assert(path === '/api/info' || path === '/api/session' || path === `/api/session/${session}`);
  assert(method === 'GET' || (path !== '/api/info' && ['POST', 'PATCH', 'DELETE'].includes(method)));
  assert(await owned(), 'authentication requires owned loopback listener');
  const startedMs = Date.now();
  const response = await fetch(base + path, { method, redirect: 'error', headers: { Authorization: authorization,
    Accept: 'application/json', ...(body ? { 'Content-Type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: cleaning ? AbortSignal.timeout(12000) : AbortSignal.any([abort.signal, AbortSignal.timeout(12000)]) });
  const text = await response.text();
  capture.calls.push({ label, method, path, status: response.status, listenerOwned: true, startedMs, atMs: Date.now(),
    ...(body?.title ? { title: body.title } : {}) });
  return { status: response.status, data: text ? JSON.parse(text) : null };
}
async function startService() {
  native = child(binary, capture.nativeArgv, env, join(runtime, 'project'));
  let output = '';
  native.stdout.on('data', (b) => { output = (output + b.toString()).slice(-4096); });
  await waitFor(() => output.includes(`server listening on ${base}`), 30000);
  assert(await owned());
  const registration = JSON.parse(await readFile(registrationFile, 'utf8'));
  assert.equal(registration.pid, native.pid); assert.equal(registration.version, '2.0.22');
  assert.equal(registration.url, base);
  const retrieved = await cli(['get', 'password']);
  assert(retrieved.length >= 32, 'private password missing');
  if (password) assert.equal(retrieved, password, 'password changed');
  password = retrieved; authorization = `Basic ${Buffer.from(`opencode:${password}`).toString('base64')}`;
  const info = await waitFor(async () => { try { const r = await api('ReadinessInfo', 'GET', '/api/info'); return r.status === 200 && r; } catch { return false; } }, 30000);
  assert.equal(info.data.pid, native.pid); assert.equal(info.data.version, '2.0.22');
  assert(info.data.paths.tmp.startsWith(env.TMPDIR + '/'));
  capture.services.push({ atMs: Date.now(), ...(await owned()), id: registration.id, version: info.data.version,
    url: base, passwordStable: true, config: await config() });
}
class Cdp {
  static async open(url) {
    const c = new Cdp(); c.pending = new Map(); c.labels = new Map(); c.requests = new Map(); c.next = 0;
    c.socket = new WebSocket(url);
    await new Promise((yes, no) => { const t = setTimeout(() => no(new Error('CDP timeout')), 12000);
      c.socket.addEventListener('open', () => { clearTimeout(t); yes(); }, { once: true });
      c.socket.addEventListener('error', () => { clearTimeout(t); no(new Error('CDP failure')); }, { once: true }); });
    c.socket.addEventListener('message', (e) => c.message(JSON.parse(e.data)));
    c.socket.addEventListener('close', () => { for (const p of c.pending.values()) { clearTimeout(p.t); p.no(new Error('CDP closed')); } c.pending.clear(); });
    return c;
  }
  call(method, params = {}, sessionId) {
    const id = ++this.next;
    return new Promise((yes, no) => { const t = setTimeout(() => { this.pending.delete(id); no(new Error(`CDP timeout ${method}`)); }, 15000);
      this.pending.set(id, { yes, no, t }); this.socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) })); });
  }
  message(o) {
    if (o.id) { const p = this.pending.get(o.id); if (!p) return; clearTimeout(p.t); this.pending.delete(o.id);
      if (o.error) p.no(new Error(`CDP error ${o.error.code}`)); else p.yes(o.result); return; }
    const page = this.labels.get(o.sessionId); if (!page) return;
    if (phase === 'browser' && (o.method === 'Runtime.exceptionThrown' || o.method === 'Log.entryAdded')) {
      const details = o.params.exceptionDetails;
      capture.bootstrap.push({ page, atMs: Date.now(), kind: o.method,
        text: (details?.exception?.description ?? details?.text ?? o.params.entry?.text ?? '').slice(0, 500) });
    }
    if (phase === 'browser' && o.method === 'Network.responseReceived') {
      const r = o.params.response, url = new URL(r.url);
      if ([capture.allowedOrigin, capture.deniedOrigin].includes(url.origin)) {
        capture.bootstrap.push({ page, atMs: Date.now(), kind: 'response', path: url.pathname,
          status: r.status, mediaType: r.mimeType });
      }
    }
    if (!o.method?.startsWith('Network.')) return;
    const p = o.params, key = `${o.sessionId}:${p.requestId}`;
    const entry = this.requests.get(key) ?? { page, id: p.requestId }; this.requests.set(key, entry);
    const selected = (h) => Object.fromEntries(Object.entries(h ?? {}).filter(([k]) => ['origin', 'access-control-request-headers',
      'access-control-request-method', 'access-control-allow-origin', 'access-control-allow-headers', 'content-type'].includes(k.toLowerCase())).map(([k, v]) => [k.toLowerCase(), v]));
    if (o.method === 'Network.requestWillBeSent') {
      const url = new URL(p.request.url); if (url.origin !== base) return;
      entry.path = url.pathname; entry.method = p.request.method; entry.atMs = Date.now();
      entry.authorizationPresent = Object.keys(p.request.headers).some((k) => k.toLowerCase() === 'authorization');
      entry.request = { ...entry.request, ...selected(p.request.headers) }; capture.network.push(entry);
    } else if (o.method === 'Network.requestWillBeSentExtraInfo') {
      entry.request = { ...entry.request, ...selected(p.headers) };
      entry.authorizationPresent ||= Object.keys(p.headers).some((k) => k.toLowerCase() === 'authorization');
    } else if (o.method === 'Network.responseReceived' || o.method === 'Network.responseReceivedExtraInfo') {
      entry.status = p.response?.status ?? p.statusCode;
      entry.response = { ...entry.response, ...selected(p.response?.headers ?? p.headers) };
    } else if (o.method === 'Network.loadingFailed') entry.failure = { canceled: !!p.canceled, cors: p.corsErrorStatus?.corsError ?? null, blocked: p.blockedReason ?? null };
  }
  async evaluate(page, expression) {
    const r = await this.call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, page.sessionId);
    assert(!r.exceptionDetails, 'Dart bridge failure'); return r.result.value;
  }
  async page(label, origin) {
    const { targetId } = await this.call('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await this.call('Target.attachToTarget', { targetId, flatten: true });
    this.labels.set(sessionId, label); const page = { targetId, sessionId, label };
    for (const method of ['Network.enable', 'Page.enable', 'Runtime.enable', 'Log.enable']) await this.call(method, {}, sessionId);
    await this.call('Page.navigate', { url: origin }, sessionId);
    await waitFor(async () => await this.evaluate(page, 'typeof window.cwSp04 === "function"'), 30000);
    return page;
  }
}
async function op(page, label, input) {
  if (!['state', 'shutdown'].includes(input.op)) assert(await owned(), 'bridge authentication requires owned listener');
  const result = await cdp.evaluate(page, `window.cwSp04(${JSON.stringify(JSON.stringify(input))}).then(JSON.parse)`);
  capture.operations.push({ label, page: page.label, atMs: Date.now(), result }); return result;
}
async function state() { return cdp.evaluate(allowedPage, 'window.cwSp04("{\\"op\\":\\"state\\"}").then(JSON.parse)'); }
try {
  const build = join(root, 'app/build/web');
  capture.sourceSHA256 = digest(await readFile(join(root, 'app/lib/main.dart')));
  capture.buildSHA256 = digest(await readFile(join(build, 'main.dart.js')));
  capture.buildProvenance = JSON.parse(await readFile(join(root, 'build-provenance.json'), 'utf8'));
  assert.equal(capture.buildProvenance.buildSHA256, capture.buildSHA256);
  assert.equal(capture.buildProvenance.inputsSHA256['lib/main.dart'], capture.sourceSHA256);
  for (const required of ['lib/main.dart', 'pubspec.yaml', 'pubspec.lock', 'web/index.html']) assert(capture.buildProvenance.inputsSHA256[required]);
  for (const [name, sha] of Object.entries(capture.buildProvenance.inputsSHA256)) {
    const input = resolve(root, 'app', name); assert(input.startsWith(join(root, 'app') + '/'));
    assert.equal(digest(await readFile(input)), sha, 'compile input changed after controlled build');
  }
  assert(capture.buildProvenance.finishedAt - capture.buildProvenance.startedAt < 1200, 'compile execution budget');
  staticServer = createServer(async (request, response) => {
    try {
      const name = new URL(request.url, 'http://localhost').pathname;
      if (name === '/__native_owned') {
        const proof = await owned();
        capture.authenticationGuards.push({ atMs: Date.now(), owned: !!proof, ...(proof || {}) });
        response.writeHead(200, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        response.end(JSON.stringify({ owned: !!proof, base })); return;
      }
      const file = resolve(build, '.' + (name === '/' ? '/index.html' : decodeURIComponent(name)));
      assert(file.startsWith(build + '/')); const bytes = await readFile(file);
      if (name === '/main.dart.js') capture.servedBuildSHA256 = digest(bytes);
      const type = /\.m?js$/.test(file) ? 'application/javascript' : file.endsWith('.html') ? 'text/html' : file.endsWith('.wasm') ? 'application/wasm' : 'application/octet-stream';
      response.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' }); response.end(bytes);
    } catch { response.writeHead(404); response.end(); }
  });
  await new Promise((yes, no) => { staticServer.once('error', no); staticServer.listen(0, '127.0.0.1', yes); });
  capture.staticPort = staticServer.address().port;
  capture.allowedOrigin = `http://cw-sp04-allowed.test:${capture.staticPort}`;
  capture.deniedOrigin = `http://cw-sp04-denied.test:${capture.staticPort}`;
  phase = 'configuration'; nativePort = await absent(0); assert(nativePort !== 49374 && nativePort !== capture.staticPort);
  base = `http://127.0.0.1:${nativePort}`; capture.nativePort = nativePort;
  phase = 'browser';
  const browserRoots = Object.fromEntries(['home', 'config', 'data', 'cache', 'state', 'tmp', 'run'].map((k) => [k, join(root, k)]));
  const shell = `set -eu
umask 077
test ! -L /tmp/opencode && test ! -L '${root}'
export HOME='${browserRoots.home}' XDG_CONFIG_HOME='${browserRoots.config}' XDG_DATA_HOME='${browserRoots.data}' XDG_CACHE_HOME='${browserRoots.cache}' XDG_STATE_HOME='${browserRoots.state}' TMPDIR='${browserRoots.tmp}' XDG_RUNTIME_DIR='${browserRoots.run}'
export SNAP_REAL_HOME="$HOME" SNAP_USER_DATA='${root}/snap-data' SNAP_USER_COMMON='${root}/snap-common' CHROME_CONFIG_HOME="$XDG_CONFIG_HOME"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$TMPDIR" "$XDG_RUNTIME_DIR" "$SNAP_USER_DATA" "$SNAP_USER_COMMON"
printf 'CW_ROOTS %s\\n' '${JSON.stringify(browserRoots)}'
exec "$SNAP/usr/lib/chromium-browser/chrome" "$@"`;
  const chrome = child('/usr/bin/snap', ['run', '--shell', 'chromium', '-c', shell, 'cw-sp04',
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--password-store=basic', '--disable-background-networking',
    '--no-proxy-server', '--remote-debugging-port=0', '--remote-debugging-address=127.0.0.1', `--user-data-dir=${root}/browser`,
    '--host-resolver-rules=MAP cw-sp04-allowed.test 127.0.0.1,MAP cw-sp04-denied.test 127.0.0.1', 'about:blank'], launcherEnv, root);
  let endpoint, rootsOutput = '';
  chrome.stdout.on('data', (b) => { rootsOutput = (rootsOutput + b.toString()).slice(-4096); });
  chrome.stderr.on('data', (b) => { endpoint ??= b.toString().match(/DevTools listening on (ws:\/\/127\.0\.0\.1:\d+\/[^\s]+)/)?.[1]; });
  await waitFor(() => endpoint, 30000);
  assert.deepEqual(JSON.parse(rootsOutput.match(/CW_ROOTS (\{[^\n]+\})/)[1]), browserRoots);
  capture.browserRoots = browserRoots; capture.cdpPort = Number(new URL(endpoint).port);
  cdp = await Cdp.open(endpoint); capture.browser = await cdp.call('Browser.getVersion');
  allowedPage = await cdp.page('allowed', capture.allowedOrigin);
  phase = 'configuration';
  await cli(['set', 'port', String(nativePort)]); await cli(['set', 'cors', capture.allowedOrigin]);
  capture.initialConfig = await config(); await startService();
  await op(allowedPage, 'ConfigureAllowed', { op: 'configure', base, authorization });
  const good = await op(allowedPage, 'AllowedInfo', { op: 'info' }); assert(good.ok && good.status === 200);
  await op(allowedPage, 'ConfigureBadAuth', { op: 'configure', base, authorization: 'Basic b3BlbmNvZGU6aW52YWxpZA==' });
  const bad = await op(allowedPage, 'BadAuthInfo', { op: 'info' }); assert(bad.ok && bad.status === 401);
  deniedPage = await cdp.page('denied', capture.deniedOrigin);
  await op(deniedPage, 'ConfigureDenied', { op: 'configure', base, authorization });
  assert(!(await op(deniedPage, 'DeniedInfo', { op: 'info' })).ok);
  assert(!(await op(deniedPage, 'DeniedSSE', { op: 'start' })).ok);
  phase = 'initial-stream';
  session = 'ses_' + BigInt(Date.now() * 4096).toString(16).padStart(12, '0') + randomBytes(7).toString('hex');
  capture.sessionID = session; await save();
  const created = await api('CreateOwnedSession', 'POST', '/api/session', { id: session, title: 'SP04 managed initial', location: { directory: join(runtime, 'project') } });
  assert.equal(created.status, 200); assert.equal(created.data.data.id, session);
  await cdp.call('Target.activateTarget', { targetId: allowedPage.targetId }); await cdp.call('Page.bringToFront', {}, allowedPage.sessionId);
  await op(allowedPage, 'ConfigureOwnedSession', { op: 'configure', base, authorization, session });
  assert((await op(allowedPage, 'InitialConnected', { op: 'start' })).ok);
  const initialTitle = 'SP04 managed live 🚀';
  assert.equal((await api('RenameFirst', 'PATCH', `/api/session/${session}`, { title: initialTitle })).status, 204);
  await waitFor(async () => (await state()).attempts[0].events.some((e) => e.event.data?.title === initialTitle));
  capture.before = await op(allowedPage, 'BeforeRestart', { op: 'state' }); assert.equal(capture.before.visibility, 'visible');
  phase = 'restart'; capture.restartStartedMs = Date.now(); const old = native;
  await cli(['set', 'cors', capture.allowedOrigin]);
  await waitFor(() => old.exitCode !== null || old.signalCode !== null);
  await absent(nativePort); capture.oldListenerGoneMs = Date.now();
  await waitFor(async () => { const a = (await state()).attempts[0]; return a.ended && a.released && !a.locallyAborted; });
  capture.disconnected = await op(allowedPage, 'NaturalDisconnected', { op: 'state' });
  assert.deepEqual(await config(), capture.services[0].config);
  await startService(); assert.notEqual(old.pid, native.pid);
  phase = 'recovered';
  await waitFor(async () => { const s = await state(); assert.equal(s.recoveryError, null); return s.milestones.some((m) => m.kind === 'streamRecovered'); }, 25000);
  const recovered = await op(allowedPage, 'Recovered', { op: 'state' });
  const marker = recovered.milestones.find((m) => m.kind === 'streamRecovered');
  assert.equal(marker.id, session); assert.equal(marker.title, initialTitle); assert(marker.attempt > 1);
  const title = 'SP04 managed resumed live';
  assert.equal((await api('RenameResumedLive', 'PATCH', `/api/session/${session}`, { title })).status, 204);
  await waitFor(async () => (await state()).attempts[marker.attempt - 1].events.some((e) => e.event.data?.title === title));
  capture.final = await op(allowedPage, 'FinalObservedState', { op: 'state' });
  assert.equal(capture.servedBuildSHA256, capture.buildSHA256); capture.result = 'managed-restart-browser-subset-pass';
} catch (error) {
  capture.result = 'failed'; capture.failure = { phase, type: error.constructor.name, message: error.message }; process.exitCode = 1;
} finally {
  clearTimeout(deadline);
  for (const page of [allowedPage, deniedPage].filter(Boolean)) {
    try { const s = await op(page, 'FinalShutdown', { op: 'shutdown' }); assert(s.ok && s.credentialsCleared && s.activeReaders === 0 && s.activeAttempts === 0); }
    catch (e) { cleanup.errors.push(`Dart shutdown: ${e.constructor.name}`); }
  }
  if (session && native && native.exitCode === null && native.signalCode === null) {
    try { const d = await api('DeleteOwnedSession', 'DELETE', `/api/session/${session}`, undefined, true); assert([200, 204, 404].includes(d.status));
      cleanup.session404 = (await api('VerifyDeletedSession', 'GET', `/api/session/${session}`, undefined, true)).status === 404; assert(cleanup.session404); }
    catch (e) { cleanup.errors.push(`session cleanup: ${e.constructor.name}`); }
  } else if (session) cleanup.errors.push('owned session deletion unverified');
  if (cdp) { try { await cdp.call('Browser.close'); } catch { /* Owned group termination below is authoritative. */ } cdp.socket.close(); }
  for (const p of [...children].reverse()) { try { await terminate(p); } catch (e) { cleanup.errors.push(`process ${p.pid}: ${e.constructor.name}`); } }
  cleanup.processGroupsAbsent = !cleanup.errors.some((e) => e.startsWith('process '));
  try {
    assert(cleanup.processGroupsAbsent);
    await exec('snap', ['run', '--shell', 'chromium', '-c', `test ! -L /tmp/opencode && test ! -L '${root}' && if test -d '${root}'; then rm -rf -- '${root}'; fi; test ! -e '${root}'`], { timeout: 15000, env: launcherEnv });
    cleanup.snapPrivateRootAbsent = true;
  } catch (e) { cleanup.errors.push(`Snap cleanup: ${e.constructor.name}`); }
  if (staticServer?.listening) await new Promise((yes) => staticServer.close(yes));
  for (const port of [nativePort, capture.cdpPort, capture.staticPort].filter(Boolean)) {
    try { await absent(port); } catch (e) { cleanup.errors.push(`listener ${port}: ${e.constructor.name}`); }
  }
  cleanup.listenersAbsent = !cleanup.errors.some((e) => e.startsWith('listener '));
  if (cleanup.listenersAbsent && cleanup.processGroupsAbsent) {
    try { await rm(runtime, { recursive: true, force: true }); cleanup.nativeRuntimeAbsent = true; }
    catch (e) { cleanup.errors.push(`runtime cleanup: ${e.constructor.name}`); }
  }
  if (cleanup.errors.length) { capture.result = 'failed'; process.exitCode = 1; }
  capture.cleanup = cleanup; await save(); console.log(safe({ result: capture.result, failure: capture.failure, cleanup: cleanup.errors }));
}
