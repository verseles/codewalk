// Opt-in, owned loopback diagnostic. No prompts, providers, PTYs or shared services.
import assert from 'node:assert/strict';
import { spawn, execFile } from 'node:child_process';
import { createHash, randomBytes } from 'node:crypto';
import { createServer } from 'node:http';
import { readFile, writeFile, mkdir, lstat, rm, readdir, readlink } from 'node:fs/promises';
import { dirname, resolve, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';

const exec = promisify(execFile);
const root = dirname(fileURLToPath(import.meta.url));
assert.match(root, /^\/tmp\/opencode\/codewalk-sp04-[A-Za-z0-9-]+$/);
assert(!(await lstat(root)).isSymbolicLink());
const smoke = process.argv.includes('--smoke');
const build = join(root, 'app/build/web');
const profile = join(root, 'browser'); // Snap-private /tmp, not the host path.
const launcherEnv = Object.fromEntries(['HOME', 'PATH', 'USER', 'LOGNAME', 'LANG']
  .filter((k) => process.env[k]).map((k) => [k, process.env[k]]));
const password = randomBytes(32).toString('base64url');
const authorization = `Basic ${Buffer.from(`opencode:${password}`).toString('base64')}`;
const abort = new AbortController();
const deadline = setTimeout(() => abort.abort(), 180_000);
for (const signal of ['SIGINT', 'SIGTERM']) process.once(signal, () => abort.abort());
const capture = { startedAt: new Date().toISOString(), smoke, calls: [], operations: [], network: [], served: {},
  nativeInferenceTurns: 0, inferenceCostUSD: 0, lifecycleResult: 'not-run' };
const cleanup = { errors: [] };
const children = [];
let phase = 'static', staticServer, cdp, allowedPage, deniedPage, native, base, nativePort, session;
let nativeReady = false;
const digest = (bytes) => createHash('sha256').update(bytes).digest('hex');
const delay = (ms) => new Promise((r) => setTimeout(r, ms));
const safe = (value) => JSON.stringify(value, null, 2)
  .replaceAll(authorization, '[REDACTED]').replaceAll(password, '[REDACTED]') + '\n';
const save = async () => {
  await mkdir(join(root, 'evidence'), { recursive: true, mode: 0o700 });
  await writeFile(join(root, 'evidence', smoke ? 'smoke.json' : 'capture.json'), safe(capture), { mode: 0o600 });
};

class ObservationTimeout extends Error {}

async function waitFor(check, timeout = 12_000) {
  const until = Date.now() + timeout;
  while (Date.now() < until) {
    if (abort.signal.aborted) throw new Error('run deadline or signal');
    const result = await check();
    if (result) return result;
    await delay(100);
  }
  throw new ObservationTimeout('bounded observation timeout');
}

function child(command, args, env, cwd) {
  const process = spawn(command, args, { env, cwd, detached: true, stdio: ['ignore', 'pipe', 'pipe'] });
  process.on('error', () => {});
  process.stdout.on('data', () => {});
  process.stderr.on('data', () => {});
  children.push(process);
  return process;
}

async function terminate(process) {
  if (!process?.pid) return;
  const groupExists = () => {
    try { globalThis.process.kill(-process.pid, 0); return true; }
    catch (e) { if (e.code === 'ESRCH') return false; throw e; }
  };
  if (groupExists()) globalThis.process.kill(-process.pid, 'SIGTERM');
  for (let i = 0; i < 50 && groupExists(); i++) await delay(100);
  if (groupExists()) globalThis.process.kill(-process.pid, 'SIGKILL');
  for (let i = 0; i < 50 && groupExists(); i++) await delay(100);
  assert(!groupExists(), 'owned process group remains');
}

async function listenerAbsent(port) {
  const test = createServer();
  await new Promise((yes, no) => { test.once('error', no); test.listen(port, '127.0.0.1', yes); });
  await new Promise((yes) => test.close(yes));
  return true;
}

async function api(label, method, path, body, cleaning = false) {
  assert(path === '/api/info' || path === '/api/session' || path === `/api/session/${session}`);
  assert(method === 'GET' || (path !== '/api/info' && ['POST', 'PATCH', 'DELETE'].includes(method)));
  assert(await nativeListenerOwned(), 'authenticated request requires an owned listener');
  const startedMs = Date.now();
  const response = await fetch(base + path, {
    method, headers: { Authorization: authorization, Accept: 'application/json',
      ...(body ? { 'Content-Type': 'application/json' } : {}) },
    ...(body ? { body: JSON.stringify(body) } : {}),
    signal: cleaning ? AbortSignal.timeout(12_000) : AbortSignal.any([abort.signal, AbortSignal.timeout(12_000)]),
  });
  const text = await response.text();
  const data = text ? JSON.parse(text) : null;
  capture.calls.push({ label, method, path, status: response.status, listenerOwned: true, startedMs, atMs: Date.now(),
    ...(body?.title ? { title: body.title } : {}) });
  return { status: response.status, data };
}

async function nativeListenerOwned() {
  if (!native?.pid || native.exitCode !== null || native.signalCode !== null) return false;
  const fds = await readdir(`/proc/${native.pid}/fd`);
  const sockets = new Set(await Promise.all(fds.map(async (fd) => {
    try { return await readlink(`/proc/${native.pid}/fd/${fd}`); }
    catch (error) { if (error.code === 'ENOENT') return null; throw error; }
  })));
  const address = `0100007F:${nativePort.toString(16).toUpperCase().padStart(4, '0')}`;
  const table = await readFile('/proc/net/tcp', 'utf8');
  return table.split('\n').some((line) => {
    const fields = line.trim().split(/\s+/);
    return fields[1] === address && fields[3] === '0A' && sockets.has(`socket:[${fields[9]}]`);
  });
}

class Cdp {
  static async open(url) {
    const c = new Cdp();
    c.pending = new Map(); c.labels = new Map(); c.requests = new Map(); c.next = 0;
    c.socket = new WebSocket(url);
    await new Promise((yes, no) => {
      const timer = setTimeout(() => no(new Error('CDP socket timeout')), 12_000);
      c.socket.addEventListener('open', () => { clearTimeout(timer); yes(); }, { once: true });
      c.socket.addEventListener('error', () => { clearTimeout(timer); no(new Error('CDP socket failure')); }, { once: true });
    });
    c.socket.addEventListener('message', (event) => c.message(JSON.parse(event.data)));
    c.socket.addEventListener('close', () => {
      for (const { no, timer } of c.pending.values()) { clearTimeout(timer); no(new Error('CDP closed')); }
      c.pending.clear();
    });
    return c;
  }
  call(method, params = {}, sessionId) {
    const id = ++this.next;
    return new Promise((yes, no) => {
      const timer = setTimeout(() => { this.pending.delete(id); no(new Error(`CDP timeout ${method}`)); }, 15_000);
      this.pending.set(id, { yes, no, timer });
      this.socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  }
  message(o) {
    if (o.id) {
      const pending = this.pending.get(o.id);
      if (!pending) return;
      clearTimeout(pending.timer); this.pending.delete(o.id);
      if (o.error) pending.no(new Error(`CDP error ${o.error.code}`)); else pending.yes(o.result);
      return;
    }
    const label = this.labels.get(o.sessionId);
    if (!label || !o.method?.startsWith('Network.')) return;
    const p = o.params;
    const key = `${o.sessionId}:${p.requestId}`;
    const entry = this.requests.get(key) ?? { page: label, id: p.requestId };
    this.requests.set(key, entry);
    const selected = (headers) => Object.fromEntries(Object.entries(headers ?? {})
      .filter(([k]) => ['origin', 'access-control-request-headers', 'access-control-request-method',
        'access-control-allow-origin', 'access-control-allow-headers', 'content-type'].includes(k.toLowerCase()))
      .map(([k, v]) => [k.toLowerCase(), v]));
    if (o.method === 'Network.requestWillBeSent') {
      const url = new URL(p.request.url);
      if (url.origin !== base) return;
      entry.path = url.pathname; entry.method = p.request.method;
      entry.authorizationPresent = Object.keys(p.request.headers).some((k) => k.toLowerCase() === 'authorization');
      entry.request = { ...entry.request, ...selected(p.request.headers) };
      capture.network.push(entry);
    } else if (o.method === 'Network.requestWillBeSentExtraInfo') {
      entry.request = { ...entry.request, ...selected(p.headers) };
      entry.authorizationPresent ||= Object.keys(p.headers).some((k) => k.toLowerCase() === 'authorization');
    } else if (o.method === 'Network.responseReceived') {
      entry.status = p.response.status;
      entry.response = { ...entry.response, ...selected(p.response.headers) };
    } else if (o.method === 'Network.responseReceivedExtraInfo') {
      entry.status = p.statusCode;
      entry.response = { ...entry.response, ...selected(p.headers) };
    } else if (o.method === 'Network.loadingFailed') {
      entry.failure = { canceled: !!p.canceled, cors: p.corsErrorStatus?.corsError ?? null,
        blocked: p.blockedReason ?? null };
    }
  }
  async page(label, origin) {
    const { targetId } = await this.call('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await this.call('Target.attachToTarget', { targetId, flatten: true });
    this.labels.set(sessionId, label);
    await this.call('Network.enable', {}, sessionId);
    await this.call('Page.enable', {}, sessionId);
    await this.call('Runtime.enable', {}, sessionId);
    await this.call('Page.navigate', { url: origin }, sessionId);
    const page = { targetId, sessionId, label };
    await waitFor(async () => (await this.evaluate(page, 'typeof window.cwSp04 === "function"')) === true, 30_000);
    return page;
  }
  async evaluate(page, expression) {
    const r = await this.call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, page.sessionId);
    assert(!r.exceptionDetails, 'Dart bridge evaluation failed');
    return r.result.value;
  }
  async activate(page) {
    await this.call('Target.activateTarget', { targetId: page.targetId });
    await this.call('Page.bringToFront', {}, page.sessionId);
  }
}

async function op(page, label, input) {
  if (nativeReady && !['state', 'shutdown'].includes(input.op)) {
    assert(await nativeListenerOwned(), 'browser operation requires an owned native listener');
  }
  const expression = `window.cwSp04(${JSON.stringify(JSON.stringify(input))}).then(JSON.parse)`;
  const result = await cdp.evaluate(page, expression);
  capture.operations.push({ label, page: page.label, atMs: Date.now(), result });
  return result;
}
async function state(page = allowedPage) {
  return cdp.evaluate(page, 'window.cwSp04("{\\"op\\":\\"state\\"}").then(JSON.parse)');
}

try {
  staticServer = createServer(async (request, response) => {
    try {
      const path = new URL(request.url, 'http://localhost').pathname;
      const name = path === '/' ? '/index.html' : decodeURIComponent(path);
      const file = resolve(build, '.' + name);
      assert(file.startsWith(build + '/'), 'static path');
      const bytes = await readFile(file);
      capture.served[name] = digest(bytes);
      const type = file.endsWith('.js') ? 'application/javascript' : file.endsWith('.wasm') ? 'application/wasm'
        : file.endsWith('.html') ? 'text/html' : file.endsWith('.json') ? 'application/json' : 'application/octet-stream';
      response.writeHead(200, { 'Content-Type': type, 'Cache-Control': 'no-store' }); response.end(bytes);
    } catch { response.writeHead(404); response.end(); }
  });
  await new Promise((yes, no) => { staticServer.once('error', no); staticServer.listen(0, '127.0.0.1', yes); });
  const webPort = staticServer.address().port;
  capture.allowedOrigin = `http://cw-sp04-allowed.test:${webPort}`;
  capture.deniedOrigin = `http://cw-sp04-denied.test:${webPort}`;
  capture.buildSHA256 = digest(await readFile(join(build, 'main.dart.js')));
  capture.sourceSHA256 = digest(await readFile(join(root, 'app/lib/main.dart')));
  phase = 'browser';
  const browserRoots = { home: join(root, 'home'), config: join(root, 'config'), data: join(root, 'data'),
    cache: join(root, 'cache'), state: join(root, 'state'), tmp: join(root, 'tmp'), run: join(root, 'run') };
  const browserShell = `set -eu
umask 077
test ! -L /tmp/opencode && test ! -L '${root}'
export HOME='${browserRoots.home}' XDG_CONFIG_HOME='${browserRoots.config}'
export XDG_DATA_HOME='${browserRoots.data}' XDG_CACHE_HOME='${browserRoots.cache}'
export XDG_STATE_HOME='${browserRoots.state}' TMPDIR='${browserRoots.tmp}' XDG_RUNTIME_DIR='${browserRoots.run}'
export SNAP_REAL_HOME="$HOME" SNAP_USER_DATA='${root}/snap-data' SNAP_USER_COMMON='${root}/snap-common'
export CHROME_CONFIG_HOME="$XDG_CONFIG_HOME"
unset DBUS_SESSION_BUS_ADDRESS
mkdir -p "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$TMPDIR" "$XDG_RUNTIME_DIR" "$SNAP_USER_DATA" "$SNAP_USER_COMMON"
printf 'CW_BROWSER_ROOTS {"home":"%s","config":"%s","data":"%s","cache":"%s","state":"%s","tmp":"%s","run":"%s"}\\n' "$HOME" "$XDG_CONFIG_HOME" "$XDG_DATA_HOME" "$XDG_CACHE_HOME" "$XDG_STATE_HOME" "$TMPDIR" "$XDG_RUNTIME_DIR"
exec "$SNAP/usr/lib/chromium-browser/chrome" "$@"`;
  const chrome = child('/usr/bin/snap', ['run', '--shell', 'chromium', '-c', browserShell, 'cw-sp04',
    '--headless=new', '--no-first-run', '--no-default-browser-check', '--password-store=basic',
    '--disable-background-networking', '--no-proxy-server', '--remote-debugging-port=0',
    '--remote-debugging-address=127.0.0.1', `--user-data-dir=${profile}`,
    '--host-resolver-rules=MAP cw-sp04-allowed.test 127.0.0.1,MAP cw-sp04-denied.test 127.0.0.1', 'about:blank'],
    launcherEnv, root);
  let browserOutput = '', observedRoots;
  chrome.stdout.on('data', (bytes) => {
    browserOutput = (browserOutput + bytes.toString()).slice(-4096);
    const marker = browserOutput.match(/CW_BROWSER_ROOTS (\{[^\n]+\})/);
    if (marker) observedRoots = JSON.parse(marker[1]);
  });
  let endpoint;
  chrome.stderr.on('data', (bytes) => { endpoint ??= bytes.toString().match(/DevTools listening on (ws:\/\/127\.0\.0\.1:\d+\/[^\s]+)/)?.[1]; });
  await waitFor(() => endpoint, 30_000);
  assert.deepEqual(observedRoots, browserRoots, 'effective private browser roots');
  capture.browserPrivateRoots = observedRoots;
  capture.browserLaunch = 'confined-direct-binary';
  capture.cdpPort = Number(new URL(endpoint).port);
  cdp = await Cdp.open(endpoint);
  capture.browser = await cdp.call('Browser.getVersion');
  allowedPage = await cdp.page('allowed', capture.allowedOrigin);
  assert.equal((await state()).origin, capture.allowedOrigin);
  assert.equal(capture.served['/main.dart.js'], capture.buildSHA256);
  if (smoke) {
    capture.bridge = await state();
    capture.result = 'browser-only-smoke-pass';
  } else {
    phase = 'native';
    capture.archiveSHA256 = digest(await readFile(join(root, 'official-2.0.22.tgz')));
    assert.equal(capture.archiveSHA256, '49e5466de60f65001cddd7583419f842140697daead2b4d8826be54d9056e70b');
    const member = await exec('tar', ['-xOf', join(root, 'official-2.0.22.tgz'), 'package/bin/opencode'],
      { encoding: 'buffer', maxBuffer: 512 * 1024 * 1024, timeout: 12_000, env: launcherEnv });
    capture.archiveMemberSHA256 = digest(member.stdout);
    capture.binarySHA256 = digest(await readFile(join(root, 'package/bin/opencode')));
    assert.equal(capture.archiveMemberSHA256, 'f27539d9c05c970d3eb9ad6a7724b75d3e638932c5423554f5ecbfe0ee2e8815');
    assert.equal(capture.binarySHA256, capture.archiveMemberSHA256);
    capture.isolation = { modelsFetchDisabled: true, projectConfigDisabled: true, inheritedProviderCredentials: false };
    const runtime = join(root, 'runtime');
    const env = { PATH: '/usr/bin:/bin', HOME: join(runtime, 'home'), LANG: 'C.UTF-8',
      XDG_CONFIG_HOME: join(runtime, 'config'), XDG_DATA_HOME: join(runtime, 'data'),
      XDG_CACHE_HOME: join(runtime, 'cache'), XDG_STATE_HOME: join(runtime, 'state'),
      TMPDIR: join(runtime, 'tmp'), OPENCODE_CONFIG_DIR: join(runtime, 'config/opencode'),
      OPENCODE_SERVER_PASSWORD: password, OPENCODE_DISABLE_MODELS_FETCH: '1',
      OPENCODE_CONFIG_PROJECT_DISABLE: '1', OPENCODE_FILEWATCHER_DISABLE: '1', OPENCODE_DISABLE_FFF: '1' };
    for (const name of ['home', 'config', 'data', 'cache', 'state', 'tmp', 'project']) {
      await mkdir(join(runtime, name), { recursive: true, mode: 0o700 });
    }
    native = child(join(root, 'package/bin/opencode'), ['serve', '--hostname', '127.0.0.1',
      '--port', '0', '--cors', capture.allowedOrigin, '--log-level', 'none'], env, join(runtime, 'project'));
    let nativeOutput = '';
    native.stdout.on('data', (bytes) => {
      nativeOutput = (nativeOutput + bytes.toString()).slice(-512);
      base ??= nativeOutput.match(/server listening on (http:\/\/127\.0\.0\.1:\d+)/)?.[1];
    });
    await waitFor(() => base, 30_000);
    nativePort = Number(new URL(base).port);
    assert(nativePort > 0);
    assert(await nativeListenerOwned(), 'bound port belongs to owned native PID');
    const info = await waitFor(async () => {
      try { return await api('ReadinessInfo', 'GET', '/api/info'); } catch { return false; }
    }, 30_000);
    assert.equal(info.status, 200); assert.equal(info.data.version, '2.0.22');
    assert.equal(info.data.pid, native.pid); assert.equal(info.data.paths.tmp, join(runtime, 'tmp/opencode'));
    nativeReady = true; capture.info = info.data;
    capture.nativePort = nativePort;
    phase = 'cors';
    await op(allowedPage, 'ConfigureAllowed', { op: 'configure', base, authorization });
    const good = await op(allowedPage, 'AllowedInfo', { op: 'info' });
    assert(good.ok && good.status === 200 && good.body.version === '2.0.22');
    await op(allowedPage, 'ConfigureBadAuth', { op: 'configure', base, authorization: 'Basic b3BlbmNvZGU6aW52YWxpZA==' });
    const bad = await op(allowedPage, 'BadAuthInfo', { op: 'info' });
    assert(bad.ok && bad.status === 401);
    deniedPage = await cdp.page('denied', capture.deniedOrigin);
    await op(deniedPage, 'ConfigureDenied', { op: 'configure', base, authorization });
    const deniedInfo = await op(deniedPage, 'DeniedInfo', { op: 'info' });
    const deniedSse = await op(deniedPage, 'DeniedSSE', { op: 'start' });
    assert(!deniedInfo.ok && !deniedSse.ok);
    assert(capture.network.some((e) => e.page === 'denied' && e.failure?.cors));
    phase = 'incremental';
    session = 'ses_' + BigInt(Date.now() * 4096).toString(16).padStart(12, '0') + randomBytes(7).toString('hex');
    capture.sessionID = session;
    await save(); // Ownership is recorded before dispatching a potentially ambiguous mutation.
    const created = await api('CreateOwnedSession', 'POST', '/api/session',
      { id: session, title: 'SP04 owned initial', location: { directory: join(runtime, 'project') } });
    assert.equal(created.status, 200); assert.equal(created.data.data.id, session);
    await cdp.activate(allowedPage);
    await op(allowedPage, 'ConfigureOwnedSession', { op: 'configure', base, authorization, session });
    const initial = await op(allowedPage, 'InitialConnected', { op: 'start' });
    assert(initial.ok && initial.activeReaders === 1);
    const firstTitle = 'SP04 configured-origin live 🚀';
    assert.equal((await api('RenameFirst', 'PATCH', `/api/session/${session}`, { title: firstTitle })).status, 204);
    await waitFor(async () => (await state()).attempts.at(-1).events.some((e) => e.event.data?.title === firstTitle));
    const live = await op(allowedPage, 'InitialLive', { op: 'state' });
    assert(live.attempts[0].chunks.length >= 2 && !live.attempts[0].ended);
    phase = 'visibility';
    await op(allowedPage, 'ArmLifecycle', { op: 'arm' });
    await cdp.activate(deniedPage);
    let hidden;
    try { hidden = await waitFor(async () => (await state()).lifecycle.find((e) => e.kind === 'hiddenStopped'), 10_000); }
    catch (error) {
      if (!(error instanceof ObservationTimeout) || abort.signal.aborted) throw error;
      const observed = await state();
      assert.equal(observed.lifecycleError, null, 'visibility stop failed');
      assert(!observed.lifecycle.some((m) => m.kind === 'visibilitychange' && m.state === 'hidden'),
        'hidden visibility was observed without a completed stop');
      capture.lifecycleResult = 'inconclusive-no-hidden-marker';
    }
    if (hidden) {
      const stopped = await state();
      assert.equal(stopped.activeReaders, 0);
      assert(stopped.attempts[0].ended && stopped.attempts[0].released);
      const gapTitle = 'SP04 real-hidden gap';
      assert.equal((await api('RenameHiddenGap', 'PATCH', `/api/session/${session}`, { title: gapTitle })).status, 204);
      await cdp.activate(allowedPage);
      await waitFor(async () => (await state()).lifecycle.find((e) => e.kind === 'visibleRecovered' && e.title === gapTitle));
      const laterTitle = 'SP04 real-visible live';
      assert.equal((await api('RenameResumedLive', 'PATCH', `/api/session/${session}`, { title: laterTitle })).status, 204);
      await waitFor(async () => (await state()).attempts.at(-1).events.some((e) => e.event.data?.title === laterTitle));
      capture.lifecycleResult = 'observed-page-visibility-recovery';
    } else await cdp.activate(allowedPage);
    capture.final = await op(allowedPage, 'FinalObservedState', { op: 'state' });
    capture.result = 'configured-origin-browser-subset-pass';
  }
} catch (error) {
  capture.failure = { phase, type: error.constructor.name, message: error.message };
  capture.result = 'failed';
  process.exitCode = 1;
} finally {
  clearTimeout(deadline);
  for (const page of [allowedPage, deniedPage].filter(Boolean)) {
    try {
      const result = await op(page, 'FinalShutdown', { op: 'shutdown' });
      assert(result.ok && result.credentialsCleared && result.activeReaders === 0);
    } catch (error) { cleanup.errors.push(`Dart shutdown: ${error.constructor.name}`); }
  }
  if (nativeReady && session) {
    try {
      const deleted = await api('DeleteOwnedSession', 'DELETE', `/api/session/${session}`, undefined, true);
      assert([200, 204, 404].includes(deleted.status));
      cleanup.session404 = (await api('VerifyDeletedSession', 'GET', `/api/session/${session}`, undefined, true)).status === 404;
      assert(cleanup.session404);
    } catch (error) { cleanup.errors.push(`session cleanup: ${error.constructor.name}`); }
  }
  if (cdp) {
    try { await cdp.call('Browser.close'); } catch { /* Child-group exit below is authoritative. */ }
    cdp.socket.close();
  }
  for (const process of [...children].reverse()) {
    try { await terminate(process); } catch (error) { cleanup.errors.push(`process ${process.pid}: ${error.constructor.name}`); }
  }
  try {
    assert(!cleanup.errors.some((e) => e.startsWith('process ')), 'browser process may remain');
    await exec('snap', ['run', '--shell', 'chromium', '-c',
      `test ! -L /tmp/opencode && test ! -L '${root}' && if test -d '${root}'; then rm -rf -- '${root}'; fi; test ! -e '${root}'`],
      { timeout: 15_000, env: launcherEnv });
    cleanup.snapPrivateRootAbsent = true;
  } catch (error) { cleanup.errors.push(`Snap profile cleanup: ${error.constructor.name}`); }
  if (staticServer?.listening) await new Promise((yes) => staticServer.close(yes));
  for (const port of [capture.cdpPort, nativePort].filter(Boolean)) {
    try { await listenerAbsent(port); } catch (error) { cleanup.errors.push(`listener ${port}: ${error.constructor.name}`); }
  }
  cleanup.processGroupsAbsent = cleanup.errors.every((e) => !e.startsWith('process '));
  cleanup.listenersAbsent = cleanup.errors.every((e) => !e.startsWith('listener '));
  if (cleanup.processGroupsAbsent && cleanup.listenersAbsent) {
    try { await rm(join(root, 'runtime'), { recursive: true, force: true }); cleanup.nativeRuntimeAbsent = true; }
    catch (error) { cleanup.errors.push(`runtime cleanup: ${error.constructor.name}`); }
  }
  if (cleanup.errors.length) { capture.result = 'failed'; process.exitCode = 1; }
  capture.cleanup = cleanup;
  await save();
  console.log(safe({ result: capture.result, lifecycle: capture.lifecycleResult, cleanup: cleanup.errors,
    ...(capture.failure ? { failure: capture.failure } : {}) }));
}
