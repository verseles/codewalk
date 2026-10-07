// Only retain credential-free browser observations; no response bodies or ticket URLs.
import assert from 'node:assert/strict';

export function remoteFailure(o) {
  const types = ['AssertionError', 'TimeoutError', 'TimeoutExpired', 'OSError', 'PermissionError',
    'FileNotFoundError', 'ConnectionRefusedError', 'CalledProcessError', 'RuntimeError', 'ValueError', 'KeyError', 'TypeError'];
  const phases = ['preflight', 'native-start', 'native-readiness', 'static-readiness', 'foreground-admission', 'foreground-guard', 'control'];
  const errorType = types.includes(o.errorType) ? o.errorType : 'RemoteError';
  const phase = phases.includes(o.phase) ? o.phase : 'unknown';
  const error = new Error(`remote control failed: ${phase}/${errorType}`);
  error.remoteFacts = { id: Number.isSafeInteger(o.id) && o.id > 0 ? o.id : null, errorType, phase,
    serveExitCode: Number.isInteger(o.serveExitCode) && o.serveExitCode >= -128 && o.serveExitCode <= 255 ? o.serveExitCode : null };
  return error;
}

export function remoteCleanupReady(report) {
  return report?.serveBaselineRestored === true && report.ownedProcessesStopped === true && report.portsAbsent === true
    && (report.serveNotAttempted === true || report.serveSupervisor?.childReaped === true)
    && (report.sessionAbsent === true || report.sessionNotAttempted === true)
    && ((report.ptyAbsent === true && report.ptyProcessAbsent === true) || report.ptyNotAttempted === true)
    && Array.isArray(report.errors) && report.errors.length === 0;
}

export function wsFailure(capture, guardId) {
  const rows = capture.network.filter((e) => e.guardId === guardId && e.method === 'WS');
  const policy = rows.some((e) => e.failure?.blocked || e.failure?.cors)
    || capture.policyLogs.some((e) => e.guardId === guardId && e.nativeWebSocket && (e.mixedContent || e.localNetwork || e.cors));
  const httpHandshakeRejected = rows.some((e) => e.status >= 400 && e.status <= 599);
  const transport = !policy && !httpHandshakeRejected
    && rows.some((e) => e.wsFailureObserved || e.failure?.errorCode && !e.failure.canceled);
  assert(policy || httpHandshakeRejected || transport, 'WS result lacks correlated failure evidence');
  return { observation: policy ? 'browser-policy-blocked' : httpHandshakeRejected ? 'server-http-handshake-rejected' : 'transport-failed',
    evidence: { policy: !!policy, httpHandshakeRejected, transport } };
}

export class Cdp {
  static async open(url, capture, base, origin, waitFor, timeoutFor = () => 15000) {
    const c = new Cdp();
    Object.assign(c, { capture, base, origin, waitFor, timeoutFor, pending: new Map(), requests: new Map(), next: 0 });
    c.socket = new WebSocket(url);
    await new Promise((yes, no) => {
      const t = setTimeout(() => no(new Error('CDP open timeout')), Math.min(12000, timeoutFor()));
      c.socket.addEventListener('open', () => { clearTimeout(t); yes(); }, { once: true });
      c.socket.addEventListener('error', () => { clearTimeout(t); no(new Error('CDP open failed')); }, { once: true });
    });
    c.socket.addEventListener('message', (e) => c.message(JSON.parse(e.data)));
    c.socket.addEventListener('close', () => {
      for (const p of c.pending.values()) { clearTimeout(p.t); p.no(new Error('CDP closed')); }
      c.pending.clear();
    });
    return c;
  }
  call(method, params = {}, sessionId) {
    const id = ++this.next;
    return new Promise((yes, no) => {
      const t = setTimeout(() => { this.pending.delete(id); no(new Error(`CDP timeout ${method}`)); }, this.timeoutFor());
      this.pending.set(id, { yes, no, t });
      this.socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  }
  message(o) {
    if (o.id) {
      const p = this.pending.get(o.id); if (!p) return;
      clearTimeout(p.t); this.pending.delete(o.id);
      if (o.error) p.no(new Error(`CDP error ${o.error.code}`)); else p.yes(o.result);
      return;
    }
    if (o.sessionId !== this.sessionId) return;
    const p = o.params;
    if (o.method === 'Log.entryAdded') {
      // Never archive raw console text: WebSocket errors can contain live tickets.
      const text = p.entry.text;
      this.capture.policyLogs.push({ atMs: Date.now(), guardId: this.guardId, level: p.entry.level,
        mixedContent: /Mixed Content|insecure WebSocket/i.test(text),
        nativeWebSocket: text.includes(this.base.replace(/^http/, 'ws') + '/api/pty/'),
        localNetwork: /private network|local network|permission/i.test(text),
        cors: /CORS|Access-Control-/i.test(text), certificate: /certificate|ERR_CERT/i.test(text) });
    }
    if (!o.method?.startsWith('Network.')) return;
    const selected = (headers) => Object.fromEntries(Object.entries(headers ?? {})
      .filter(([key]) => ['origin', 'access-control-request-method', 'access-control-request-headers',
        'access-control-allow-origin', 'access-control-allow-headers', 'content-type'].includes(key.toLowerCase()))
      .map(([key, value]) => [key.toLowerCase(), value]));
    const key = p.requestId;
    const entry = this.requests.get(key) ?? { id: key }; this.requests.set(key, entry);
    if (o.method === 'Network.requestWillBeSent' || o.method === 'Network.webSocketCreated') {
      const url = new URL(p.request?.url ?? p.url);
      if (url.origin === this.origin) this.capture.bootstrap.push({ path: url.pathname, atMs: Date.now() });
      if (url.origin.replace(/^ws/, 'http') !== this.base) return;
      Object.assign(entry, { path: url.pathname, atMs: Date.now(), guardId: this.guardId,
        method: p.request?.method ?? 'WS', request: { ...entry.request, ...selected(p.request?.headers) },
        authorizationPresent: entry.authorizationPresent || Object.keys(p.request?.headers ?? {}).some((k) => k.toLowerCase() === 'authorization'),
        ticketPresent: url.searchParams.has('ticket') });
      this.capture.network.push(entry);
    } else if (o.method === 'Network.requestWillBeSentExtraInfo') {
      entry.request = { ...entry.request, ...selected(p.headers) };
      entry.authorizationPresent ||= Object.keys(p.headers).some((k) => k.toLowerCase() === 'authorization');
      if (p.clientSecurityState) entry.clientSecurityState = p.clientSecurityState;
    } else if (['Network.responseReceived', 'Network.responseReceivedExtraInfo', 'Network.webSocketHandshakeResponseReceived'].includes(o.method)) {
      entry.status = p.response?.status ?? p.statusCode;
      entry.response = { ...entry.response, ...selected(p.response?.headers ?? p.headers) };
      if (p.resourceIPAddressSpace) entry.resourceIPAddressSpace = p.resourceIPAddressSpace;
      const url = p.response?.url && new URL(p.response.url);
      if (url?.origin === this.origin) this.capture.bootstrap.push({ path: url.pathname,
        id: p.requestId, status: p.response.status, mediaType: p.response.mimeType, atMs: Date.now(),
        remoteIP: p.response.remoteIPAddress, securityState: p.response.securityState,
        tls: p.response.securityDetails && { protocol: p.response.securityDetails.protocol,
          subjectName: p.response.securityDetails.subjectName, issuer: p.response.securityDetails.issuer } });
    } else if (o.method === 'Network.webSocketFrameError') entry.wsFailureObserved = true;
    else if (o.method === 'Network.loadingFailed') entry.failure = {
      canceled: !!p.canceled, cors: p.corsErrorStatus?.corsError ?? null, blocked: p.blockedReason ?? null,
      errorCode: /^net::[A-Z_]+$/.test(p.errorText) ? p.errorText : null,
    };
  }
  async evaluate(expression) {
    const r = await this.call('Runtime.evaluate', { expression, awaitPromise: true, returnByValue: true }, this.sessionId);
    assert(!r.exceptionDetails, 'Dart bridge failed'); return r.result.value;
  }
  async page() {
    const { targetId } = await this.call('Target.createTarget', { url: 'about:blank' });
    const { sessionId } = await this.call('Target.attachToTarget', { targetId, flatten: true });
    Object.assign(this, { sessionId, targetId });
    await this.call('Network.enable', { maxTotalBufferSize: 64000000, maxResourceBufferSize: 16000000 }, sessionId);
    for (const method of ['Page.enable', 'Runtime.enable', 'Log.enable', 'Security.enable']) await this.call(method, {}, sessionId);
    await this.call('Page.navigate', { url: this.origin }, sessionId);
    await this.waitFor(async () => (await this.evaluate('typeof window.cwTransport === "function"')) === true, 30000);
  }
}
