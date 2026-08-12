part of 'quota_remote_datasource.dart';

String _jsSharedHelpers() => r'''
const fs = require('fs');
const os = require('os');
const p = require('path');

const P = 'CW_QUOTA_JSON:';
const CFG = p.join(os.homedir(), '.config', 'opencode');
const DATA = p.join(
  process.env.XDG_DATA_HOME || p.join(os.homedir(), '.local', 'share'),
  'opencode',
);
const AG = [
  p.join(CFG, 'antigravity-accounts.json'),
  p.join(DATA, 'antigravity-accounts.json'),
];
const GEP = ['https://cloudcode-pa.googleapis.com'];
const GDP = 'rising-fact-p41fc';
// These are provider-level OAuth app credentials, not user account secrets.
// OpenChamber ships the same fallback so installed builds can refresh
// host-owned Gemini tokens even when the host auth files omit client metadata.
const GGID = '681255809395-oo8ft2oprdrnp9e3aqf6av3hmdib135j.apps.googleusercontent.com';
const GGSC = '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';
const AGID = '1071006060591-tmhssin2h21lcre235vtolojh4g403ep.apps.googleusercontent.com';
const AGSC = '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';
const GHD = {
  'User-Agent': 'antigravity/1.11.5 windows/amd64',
  'X-Goog-Api-Client': 'google-cloud-sdk vscode_cloudshelleditor/0.1',
  'Client-Metadata': '{"ideType":"IDE_UNSPECIFIED","platform":"PLATFORM_UNSPECIFIED","pluginType":"GEMINI"}',
};

function rAuth() {
  try {
    const f = p.join(DATA, 'auth.json');
    if (!fs.existsSync(f)) return {};
    const r = fs.readFileSync(f, 'utf8').trim();
    if (!r) return {};
    return JSON.parse(r);
  } catch {
    return {};
  }
}

function rJson(f) {
  try {
    if (!fs.existsSync(f)) return null;
    const r = fs.readFileSync(f, 'utf8').trim();
    if (!r) return null;
    const j = JSON.parse(r);
    return j && typeof j === 'object' ? j : null;
  } catch {
    return null;
  }
}

function getE(a, al) {
  for (const x of al) {
    if (a[x]) return a[x];
  }
  return null;
}

function nE(e) {
  if (!e) return null;
  if (typeof e === 'string') return { token: e };
  if (typeof e === 'object') return e;
  return null;
}

function asO(v) {
  return v && typeof v === 'object' && !Array.isArray(v) ? v : null;
}

function asS(v) {
  if (typeof v !== 'string') return null;
  const t = v.trim();
  return t || null;
}

function pickS(...values) {
  for (const value of values) {
    const s = asS(value);
    if (s) return s;
  }
  return null;
}

function toN(v) {
  if (typeof v === 'number' && Number.isFinite(v)) return v;
  if (typeof v === 'string') {
    const p = Number(v);
    return Number.isFinite(p) ? p : null;
  }
  return null;
}

function toTs(v) {
  if (!v) return null;
  if (typeof v === 'number') return v < 1e12 ? v * 1000 : v;
  if (typeof v === 'string') {
    const p = Date.parse(v);
    return Number.isNaN(p) ? null : p;
  }
  return null;
}

function pgR(v) {
  const r = asS(v);
  if (!r) {
    return { refreshToken: null, projectId: null, managedProjectId: null };
  }
  const parts = r.split('|');
  return {
    refreshToken: asS(parts[0]),
    projectId: asS(parts[1]),
    managedProjectId: asS(parts[2]),
  };
}

function gCred(obj, prefix) {
  const o = asO(obj) || {};
  const c = asO(o.client);
  const did = prefix === 'GEMINI' ? GGID : prefix === 'ANTIGRAVITY' ? AGID : null;
  const dsc = prefix === 'GEMINI' ? GGSC : prefix === 'ANTIGRAVITY' ? AGSC : null;
  return {
    clientId: pickS(
      o.clientId,
      o.client_id,
      o.googleClientId,
      o.google_client_id,
      c && c.id,
      c && c.clientId,
      prefix ? process.env[prefix + '_GOOGLE_CLIENT_ID'] : null,
      process.env.GOOGLE_CLIENT_ID,
      did,
    ),
    clientSecret: pickS(
      o.clientSecret,
      o.client_secret,
      o.googleClientSecret,
      o.google_client_secret,
      c && c.secret,
      c && c.clientSecret,
      prefix ? process.env[prefix + '_GOOGLE_CLIENT_SECRET'] : null,
      process.env.GOOGLE_CLIENT_SECRET,
      dsc,
    ),
  };
}

function gDiag(src) {
  return [
    'access=' + (src.accessToken ? 'yes' : 'no'),
    'refresh=' + (src.refreshToken ? 'yes' : 'no'),
    'clientId=' + (src.clientId ? 'yes' : 'no'),
    'clientSecret=' + (src.clientSecret ? 'yes' : 'no'),
    'project=' + (src.projectId ? 'yes' : 'no'),
    'expires=' + (typeof src.expires === 'number' ? 'yes' : 'no'),
  ].join(', ');
}

function bR({ pId, pName, ok, use, err, errCode }) {
  return {
    providerId: pId,
    providerName: pName,
    ok,
    configured: true,
    usage: use ?? null,
    error: err ?? null,
    errorCode: errCode ?? null,
    fetchedAt: Date.now(),
  };
}

function tUW({ uP, wS, rA, vL }) {
  const c = typeof uP === 'number' ? Math.max(0, Math.min(100, uP)) : null;
  const rS =
    typeof rA === 'number' ? Math.max(0, Math.round((rA - Date.now()) / 1000)) : null;
  return {
    usedPercent: c,
    remainingPercent: c === null ? null : Math.max(0, 100 - c),
    windowSeconds: typeof wS === 'number' ? wS : null,
    resetAfterSeconds: rS,
    resetAt: typeof rA === 'number' ? rA : null,
    resetAtFormatted: null,
    resetAfterFormatted: null,
    valueLabel: vL ?? null,
  };
}

function gWin(s, rA) {
  if (s === 'antigravity') {
    const rem =
      typeof rA === 'number' ? Math.max(0, Math.round((rA - Date.now()) / 1000)) : null;
    if (rem !== null && rem > 36000) return { label: 'daily', seconds: 86400 };
    return { label: '5h', seconds: 18000 };
  }
  return { label: 'daily', seconds: 86400 };
}

function resolveWindowSeconds(limit) {
  if (!limit) return null;
  const unit = toN(limit.unit);
  const number = toN(limit.number);
  if (unit === null || number === null) return null;
  if (unit === 3) return number * 3600;
  if (unit === 1) return number * 86400;
  if (unit === 5) return 30 * 86400;
  return null;
}

function resolveWindowLabel(windowSeconds) {
  if (windowSeconds === null) return 'rate';
  if (windowSeconds <= 5 * 3600) return '5h';
  if (windowSeconds <= 7 * 86400) return 'weekly';
  if (windowSeconds <= 30 * 86400) return 'monthly';
  return 'daily';
}

function normalizeTimestamp(v) {
  const t = toTs(v);
  return t;
}

function durationToLabel(duration, unit) {
  const d = toN(duration);
  if (d === null) return 'rate';
  const u = (typeof unit === 'string' ? unit : '').toUpperCase();
  if (u === 'TIME_UNIT_MINUTE' || u === 'MINUTE') return d + 'm';
  if (u === 'TIME_UNIT_HOUR' || u === 'HOUR') return d + 'h';
  if (u === 'TIME_UNIT_DAY' || u === 'DAY') return d + 'd';
  return d + 's';
}

function durationToSeconds(duration, unit) {
  const d = toN(duration);
  if (d === null) return null;
  const u = (typeof unit === 'string' ? unit : '').toUpperCase();
  if (u === 'TIME_UNIT_MINUTE' || u === 'MINUTE') return d * 60;
  if (u === 'TIME_UNIT_HOUR' || u === 'HOUR') return d * 3600;
  if (u === 'TIME_UNIT_DAY' || u === 'DAY') return d * 86400;
  return d;
}
''';

String _jsClaudeProvider() => r'''
async function fC(a) {
  const e = nE(getE(a, ['anthropic', 'claude']));
  const t = e && (e.access || e.token);
  if (!t) return null;
  try {
    const res = await fetch('https://api.anthropic.com/api/oauth/usage', {
      headers: {
        Authorization: 'Bearer ' + t,
        'anthropic-beta': 'oauth-2025-04-20',
      },
    });
    if (!res.ok) {
      return bR({ pId: 'claude', pName: 'Claude', ok: false, err: 'API error: ' + res.status });
    }
    const d = await res.json();
    const w = {};
    const add = (k, f) => {
      if (d && d[f]) {
        const u = toN(d[f].utilization);
        const r = toTs(d[f].resets_at);
        w[k] = tUW({ uP: u, wS: null, rA: r });
      }
    };
    add('5h', 'five_hour');
    add('7d', 'seven_day');
    add('7d-sonnet', 'seven_day_sonnet');
    add('7d-opus', 'seven_day_opus');
    return bR({ pId: 'claude', pName: 'Claude', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'claude', pName: 'Claude', ok: false, err: err.message });
  }
}
''';

String _jsOpenRouterProvider() => r'''
async function fO(a) {
  const e = nE(getE(a, ['openrouter']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://openrouter.ai/api/v1/credits', {
      headers: {
        Authorization: 'Bearer ' + k,
        'Content-Type': 'application/json',
      },
    });
    if (!res.ok) {
      return bR({
        pId: 'openrouter',
        pName: 'OpenRouter',
        ok: false,
        err: 'API error: ' + res.status,
      });
    }
    const d = await res.json();
    const c = d && d.data ? d.data : {};
    const tC = toN(c.total_credits);
    const tU = toN(c.total_usage);
    const uP = tC !== null && tU !== null && tC > 0 ? Math.max(0, Math.min(100, (tU / tC) * 100)) : null;
    const rem = tC !== null && tU !== null ? Math.max(0, tC - tU) : null;
    return bR({
      pId: 'openrouter',
      pName: 'OpenRouter',
      ok: true,
      use: {
        windows: {
          credits: tUW({ uP: uP, wS: null, rA: null, vL: rem !== null ? '$' + rem.toFixed(2) + ' remaining' : null }),
        },
      },
    });
  } catch (err) {
    return bR({ pId: 'openrouter', pName: 'OpenRouter', ok: false, err: err.message });
  }
}
''';

String _jsCodexProvider() => r'''
async function fX(a) {
  const e = nE(getE(a, ['openai', 'codex', 'chatgpt']));
  const t = e && (e.access || e.token);
  const acc = e && e.accountId;
  if (!t) return null;
  try {
    const h = {
      Authorization: 'Bearer ' + t,
      'Content-Type': 'application/json',
    };
    if (acc) h['ChatGPT-Account-Id'] = acc;
    const res = await fetch('https://chatgpt.com/backend-api/wham/usage', {
      method: 'GET',
      headers: h,
    });
    if (!res.ok) {
      return bR({
        pId: 'codex',
        pName: 'Codex',
        ok: false,
        err:
          res.status === 401
            ? 'Session expired — please re-authenticate with OpenAI'
            : 'API error: ' + res.status,
      });
    }
    const d = await res.json();
    const p = d && d.rate_limit ? d.rate_limit.primary_window : null;
    const s = d && d.rate_limit ? d.rate_limit.secondary_window : null;
    const cr = d && d.credits ? d.credits : null;
    const w = {};
    if (p) {
      w['5h'] = tUW({
        uP: toN(p.used_percent),
        wS: toN(p.limit_window_seconds),
        rA: toTs(p.reset_at),
      });
    }
    if (s) {
      w.weekly = tUW({
        uP: toN(s.used_percent),
        wS: toN(s.limit_window_seconds),
        rA: toTs(s.reset_at),
      });
    }
    if (cr) {
      const bal = toN(cr.balance);
      const lab = cr.unlimited ? 'Unlimited' : bal !== null ? '$' + bal.toFixed(2) + ' remaining' : null;
      w.credits = tUW({ uP: null, wS: null, rA: null, vL: lab });
    }
    return bR({ pId: 'codex', pName: 'Codex', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'codex', pName: 'Codex', ok: false, err: err.message });
  }
}
''';

String _jsGoogleProvider() => r'''
function rGem(a) {
  const raw = nE(getE(a, ['google', 'google.oauth']));
  const eo = asO(raw);
  if (!eo) return null;
  const oo = asO(eo.oauth) || eo;
  const at = pickS(oo.access, oo.token, eo.access, eo.token);
  const rp = pgR(oo.refresh);
  const gc = gCred(oo, 'GEMINI');
  const ec = gCred(eo, 'GEMINI');
  if (!at && !rp.refreshToken) return null;
  return {
    sourceId: 'gemini',
    sourceLabel: 'Gemini',
    accessToken: at,
    refreshToken: rp.refreshToken,
    projectId: pickS(
      oo.projectId,
      oo.managedProjectId,
      eo.projectId,
      eo.managedProjectId,
      rp.projectId,
      rp.managedProjectId,
    ),
    expires: toTs(oo.expires || eo.expires),
    clientId: pickS(gc.clientId, ec.clientId),
    clientSecret: pickS(gc.clientSecret, ec.clientSecret),
  };
}

function rAnti() {
  for (const f of AG) {
    const data = rJson(f);
    const root = asO(data);
    const accs = Array.isArray(root && root.accounts) ? root.accounts : [];
    if (!accs.length) continue;
    const idx = typeof (root && root.activeIndex) === 'number' ? root.activeIndex : 0;
    const acc = asO(accs[idx]) || asO(accs[0]);
    if (!acc) continue;
    const at = pickS(acc.accessToken, acc.access);
    const rp = pgR(acc.refreshToken);
    const ac = gCred(acc, 'ANTIGRAVITY');
    const rc = gCred(root, 'ANTIGRAVITY');
    if (!at && !rp.refreshToken) continue;
    return {
      sourceId: 'antigravity',
      sourceLabel: 'Antigravity',
      accessToken: at,
      refreshToken: rp.refreshToken,
      projectId: pickS(
        acc.projectId,
        acc.managedProjectId,
        rp.projectId,
        rp.managedProjectId,
      ),
      expires: toTs(acc.expires),
      clientId: pickS(ac.clientId, rc.clientId),
      clientSecret: pickS(ac.clientSecret, rc.clientSecret),
      email: pickS(acc.email),
    };
  }
  return null;
}

async function rGAccess(src) {
  if (src.accessToken && (!(typeof src.expires === 'number') || src.expires > Date.now())) {
    return src.accessToken;
  }
  if (!src.refreshToken || !src.clientId || !src.clientSecret) {
    return null;
  }
  try {
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: new URLSearchParams({
        client_id: src.clientId,
        client_secret: src.clientSecret,
        refresh_token: src.refreshToken,
        grant_type: 'refresh_token',
      }),
    });
    if (!res.ok) return null;
    const d = await res.json();
    return asS(d && d.access_token);
  } catch {
    return null;
  }
}

async function fGM(src) {
  const projectId = src.projectId || GDP;
  const body = { project: projectId };
  for (const ep of GEP) {
    try {
      const ac = typeof AbortController !== 'undefined' ? new AbortController() : null;
      const tm = ac ? setTimeout(() => ac.abort(), 15000) : null;
      const res = await fetch(ep + '/v1internal:fetchAvailableModels', {
        method: 'POST',
        headers: Object.assign({
          Authorization: 'Bearer ' + src.accessToken,
          'Content-Type': 'application/json',
        }, GHD),
        body: JSON.stringify(body),
        signal: ac && ac.signal,
      });
      if (tm) clearTimeout(tm);
      if (res.ok) return await res.json();
    } catch {}
  }
  return null;
}

async function fGQB(src) {
  if (src.sourceId !== 'gemini') return null;
  const projectId = src.projectId || GDP;
  const body = { project: projectId };
  try {
    const ac = typeof AbortController !== 'undefined' ? new AbortController() : null;
    const tm = ac ? setTimeout(() => ac.abort(), 15000) : null;
    const res = await fetch('https://cloudcode-pa.googleapis.com/v1internal:retrieveUserQuota', {
      method: 'POST',
      headers: {
        Authorization: 'Bearer ' + src.accessToken,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(body),
      signal: ac && ac.signal,
    });
    if (tm) clearTimeout(tm);
    if (!res.ok) return null;
    return await res.json();
  } catch {
    return null;
  }
}

async function fG(a) {
  const srcs = [];
  const gm = rGem(a);
  if (gm) srcs.push(gm);
  const ag = rAnti();
  if (ag) srcs.push(ag);
  if (!srcs.length) return null;

  const models = {};
  const errs = [];
  for (const src of srcs) {
    const token = await rGAccess(src);
    if (!token) {
      errs.push(src.sourceLabel + ': Missing usable host OAuth data (' + gDiag(src) + ')');
      continue;
    }
    src.accessToken = token;
    let merged = false;
    if (src.sourceId === 'gemini') {
      const qp = await fGQB(src);
      const buckets = Array.isArray(qp && qp.buckets) ? qp.buckets : [];
      for (const b of buckets) {
        const modelId = pickS(b && b.modelId);
        if (!modelId) continue;
        const remF = toN(b && b.remainingFraction);
        const remP = remF !== null ? Math.round(remF * 100) : null;
        const used = remP !== null ? Math.max(0, 100 - remP) : null;
        const rA = toTs(b && b.resetTime);
        const w = gWin(src.sourceId, rA);
        const scoped = modelId.startsWith(src.sourceId + '/')
          ? modelId
          : src.sourceId + '/' + modelId;
        models[scoped] = { windows: {} };
        models[scoped].windows[w.label] = tUW({
          uP: used,
          wS: w.seconds,
          rA: rA,
        });
        merged = true;
      }
    }
    const mp = await fGM(src);
    const raw = mp && typeof mp === 'object' && mp.models && typeof mp.models === 'object' ? mp.models : {};
    for (const key of Object.keys(raw)) {
      const md = raw[key] || {};
      const qi = md && md.quotaInfo && typeof md.quotaInfo === 'object' ? md.quotaInfo : {};
      const remF = toN(qi.remainingFraction);
      const remP = remF !== null ? Math.round(remF * 100) : null;
      const used = remP !== null ? Math.max(0, 100 - remP) : null;
      const rA = toTs(qi.resetTime);
      const w = gWin(src.sourceId, rA);
      const scoped = key.startsWith(src.sourceId + '/') ? key : src.sourceId + '/' + key;
      models[scoped] = {
        windows: {},
      };
      models[scoped].windows[w.label] = tUW({ uP: used, wS: w.seconds, rA: rA });
      merged = true;
    }
    if (!merged) errs.push(src.sourceLabel + ': No quota models visible');
  }

  if (!Object.keys(models).length) {
    return bR({
      pId: 'google',
      pName: 'Google',
      ok: false,
      err: errs[0] || 'Failed to fetch Google quota',
    });
  }
  return bR({
    pId: 'google',
    pName: 'Google',
    ok: true,
    use: {
      windows: {},
      models: models,
    },
  });
}
''';

String _jsGitHubCopilotProvider() => r'''
async function fGH(a) {
  const e = nE(getE(a, ['github-copilot', 'copilot']));
  const t = e && (e.access || e.token);
  if (!t) return null;
  try {
    const res = await fetch('https://api.github.com/copilot_internal/user', {
      headers: {
        Authorization: 'token ' + t,
        Accept: 'application/json',
        'Editor-Version': 'vscode/1.96.2',
        'X-Github-Api-Version': '2025-04-01',
      },
    });
    if (!res.ok) {
      return bR({
        pId: 'github-copilot',
        pName: 'GitHub Copilot',
        ok: false,
        err: 'API error: ' + res.status,
      });
    }
    const d = await res.json();
    const q = d && d.quota_snapshots ? d.quota_snapshots : {};
    const rA = toTs(d && d.quota_reset_date);
    const w = {};
    const aw = (l, s) => {
      if (!s) return;
      const en = toN(s.entitlement);
      const re = toN(s.remaining);
      const uP = en !== null && re !== null && en > 0 ? Math.max(0, 100 - (re / en) * 100) : null;
      const vL = en !== null && re !== null ? re.toFixed(0) + ' / ' + en.toFixed(0) + ' left' : null;
      w[l] = tUW({ uP: uP, wS: null, rA: rA, vL: vL });
    };
    aw('chat', q.chat);
    aw('completions', q.completions);
    aw('premium', q.premium_interactions);
    return bR({ pId: 'github-copilot', pName: 'GitHub Copilot', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'github-copilot', pName: 'GitHub Copilot', ok: false, err: err.message });
  }
}
''';

String _jsOpenCodeGoProvider() {
  return r'''
async function fOCG(a) {
  const e = nE(getE(a, ['opencode-go']));
  const k = e && (e.key || e.access || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://opencode.ai/zen/go/v1/usage', {
      headers: {
        Authorization: 'Bearer ' + k,
        Accept: 'application/json',
        'User-Agent': 'CodeWalk quota provider',
      },
      signal: AbortSignal.timeout(15000),
    });
    if (res.status === 401 || res.status === 403) {
      return bR({ pId: 'opencode-go', pName: 'OpenCode Go', ok: false, err: 'OpenCode Go authentication failed', errCode: 'authentication' });
    }
    if (!res.ok) {
      return bR({ pId: 'opencode-go', pName: 'OpenCode Go', ok: false, err: 'OpenCode Go usage API returned HTTP ' + res.status, errCode: 'request_failed' });
    }
    const payload = await res.json().catch(function() { return null; });
    const usage = payload && typeof payload === 'object' && payload.usage && typeof payload.usage === 'object'
      ? payload.usage
      : null;
    const w = {};
    const mappings = [['rolling', 'rolling'], ['weekly', 'weekly'], ['monthly', 'monthly']];
    for (const mapping of mappings) {
      const entry = usage && usage[mapping[0]];
      if (!entry || typeof entry !== 'object') continue;
      const used = entry.percent;
      const resetAt = typeof entry.resetsAt === 'string' ? Date.parse(entry.resetsAt) : NaN;
      if (typeof used !== 'number' || !Number.isFinite(used)) continue;
      w[mapping[1]] = tUW({ uP: used, wS: null, rA: Number.isFinite(resetAt) ? resetAt : null });
    }
    if (!Object.keys(w).length) {
      return bR({ pId: 'opencode-go', pName: 'OpenCode Go', ok: false, err: 'OpenCode Go usage data could not be parsed', errCode: 'invalid_response' });
    }
    return bR({ pId: 'opencode-go', pName: 'OpenCode Go', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'opencode-go', pName: 'OpenCode Go', ok: false, err: err.message, errCode: 'request_failed' });
  }
}
''';
}

String _jsNanoGptProvider() => r'''
async function fNanoGpt(a) {
  const e = nE(getE(a, ['nano-gpt', 'nanogpt', 'nano_gpt']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://nano-gpt.com/api/subscription/v1/usage', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'nano-gpt', pName: 'NanoGPT', ok: false, err: 'API error: ' + res.status });
    const payload = await res.json();
    const windows = {};
    const daily = payload && payload.daily;
    const monthly = payload && payload.monthly;
    const state = (payload && payload.state) || 'active';
    const handleWindow = (entry, wS) => {
      if (!entry) return null;
      let uP = null;
      if (typeof entry.percentUsed === 'number') {
        uP = Math.max(0, Math.min(100, entry.percentUsed * 100));
      } else {
        const u = toN(entry.used);
        const l = toN(entry.limit || (entry.limits && entry.limits.daily) || (entry.limits && entry.limits.monthly));
        if (u !== null && l !== null && l > 0) uP = Math.max(0, Math.min(100, (u / l) * 100));
      }
      const vL = state !== 'active' ? '(' + state + ')' : null;
      return tUW({ uP, wS, rA: toTs(entry.resetAt), vL });
    };
    if (daily) windows.daily = handleWindow(daily, 86400);
    if (monthly) windows.monthly = handleWindow(monthly, null);
    return bR({ pId: 'nano-gpt', pName: 'NanoGPT', ok: true, use: { windows } });
  } catch (err) {
    return bR({ pId: 'nano-gpt', pName: 'NanoGPT', ok: false, err: err.message });
  }
}
''';

String _jsWaferProvider() => r'''
async function fWafer(a) {
  const e = nE(getE(a, ['wafer', 'wafer-ai', 'wafer_ai', 'wafer.ai']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  const ac = typeof AbortController !== 'undefined' ? new AbortController() : null;
  const tm = ac ? setTimeout(() => ac.abort(), 15000) : null;
  try {
    const res = await fetch('https://pass.wafer.ai/v1/inference/quota', {
      headers: { Authorization: 'Bearer ' + k, 'Accept-Encoding': 'identity' },
      signal: ac && ac.signal,
    });
    if (tm) clearTimeout(tm);
    if (!res.ok) return bR({ pId: 'wafer', pName: 'Wafer.ai', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const remaining = toN(d.remaining_included_requests);
    const limit = toN(d.included_request_limit);
    const overage = toN(d.overage_request_count);
    const usedPercentRaw = toN(d.current_period_used_percent);
    const windowStart = toTs(d.window_start);
    const windowEnd = toTs(d.window_end);
    const planTier = (d.plan_tier && typeof d.plan_tier === 'string' && d.plan_tier.trim()) ? d.plan_tier.trim() : null;
    if (remaining === null && limit === null && overage === null && usedPercentRaw === null) {
      return bR({ pId: 'wafer', pName: 'Wafer.ai', ok: false, err: 'No quota data in response' });
    }
    const hasOverage = overage !== null && overage > 0;
    const usedPercent = hasOverage ? Math.max(0, usedPercentRaw || 0) : Math.max(0, Math.min(100, usedPercentRaw || 0));
    const windowSeconds = (windowStart !== null && windowEnd !== null) ? Math.round((windowEnd - windowStart) / 1000) : 18000;
    const windowLabel = resolveWindowLabel(windowSeconds);
    let vL = null;
    if (remaining !== null && limit !== null) {
      const parts = [];
      if (planTier) parts.push(planTier);
      parts.push(remaining + ' / ' + limit + ' left');
      if (hasOverage) parts.push('+' + overage + ' overage');
      vL = parts.join(' \u00b7 ');
    }
    const w = {};
    w[windowLabel] = tUW({ uP: usedPercent, wS: windowSeconds, rA: windowEnd, vL: vL });
    return bR({ pId: 'wafer', pName: 'Wafer.ai', ok: true, use: { windows: w } });
  } catch (err) {
    if (tm) clearTimeout(tm);
    const isTimeout = ac && ac.signal && ac.signal.aborted;
    return bR({ pId: 'wafer', pName: 'Wafer.ai', ok: false, err: isTimeout ? 'Request timed out' : err.message });
  }
}
''';

String _jsGitHubCopilotAddonProvider() => r'''
async function fGHA(a) {
  const e = nE(getE(a, ['github-copilot-addon', 'github-copilot', 'copilot']));
  const t = e && (e.access || e.token);
  if (!t) return null;
  try {
    const res = await fetch('https://api.github.com/copilot_internal/user', {
      headers: {
        Authorization: 'token ' + t,
        Accept: 'application/json',
        'Editor-Version': 'vscode/1.96.2',
        'X-Github-Api-Version': '2025-04-01',
      },
    });
    if (!res.ok) return bR({ pId: 'github-copilot-addon', pName: 'GitHub Copilot Add-on', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const q = d && d.quota_snapshots ? d.quota_snapshots : {};
    const rA = toTs(d && d.quota_reset_date);
    const w = {};
    if (q && q.premium_interactions) {
      const s = q.premium_interactions;
      const en = toN(s.entitlement);
      const re = toN(s.remaining);
      const uP = en !== null && re !== null && en > 0 ? Math.max(0, 100 - (re / en) * 100) : null;
      const vL = en !== null && re !== null ? re.toFixed(0) + ' / ' + en.toFixed(0) + ' left' : null;
      w.premium = tUW({ uP: uP, wS: null, rA: rA, vL: vL });
    }
    return bR({ pId: 'github-copilot-addon', pName: 'GitHub Copilot Add-on', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'github-copilot-addon', pName: 'GitHub Copilot Add-on', ok: false, err: err.message });
  }
}
''';

String _jsKimiForCodingProvider() => r'''
async function fKimi(a) {
  const e = nE(getE(a, ['kimi-for-coding', 'kimi']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://api.kimi.com/coding/v1/usages', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'kimi-for-coding', pName: 'Kimi for Coding', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const w = {};
    if (d && d.usage) {
      const limit = toN(d.usage.limit);
      const remaining = toN(d.usage.remaining);
      const usedPercent = limit && remaining !== null ? Math.max(0, Math.min(100, 100 - (remaining / limit) * 100)) : null;
      w.weekly = tUW({ uP: usedPercent, wS: null, rA: toTs(d.usage.resetTime) });
    }
    const limits = Array.isArray(d && d.limits) ? d.limits : [];
    for (const lim of limits) {
      const window = lim && lim.window;
      const detail = lim && lim.detail;
      const rawLabel = durationToLabel(window && window.duration, window && window.timeUnit);
      const windowSeconds = durationToSeconds(window && window.duration, window && window.timeUnit);
      const label = (windowSeconds === 18000) ? 'Rate Limit (' + rawLabel + ')' : rawLabel;
      const total = toN(detail && detail.limit);
      const remaining = toN(detail && detail.remaining);
      const usedPercent = total && remaining !== null ? Math.max(0, Math.min(100, 100 - (remaining / total) * 100)) : null;
      w[label] = tUW({ uP: usedPercent, wS: windowSeconds, rA: toTs(detail && detail.resetTime) });
    }
    return bR({ pId: 'kimi-for-coding', pName: 'Kimi for Coding', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'kimi-for-coding', pName: 'Kimi for Coding', ok: false, err: err.message });
  }
}
''';

String _jsZhipuaiCodingPlanProvider() => r'''
async function fZhipu(a) {
  const e = nE(getE(a, ['zhipuai-coding-plan', 'zhipuai', 'zhipu']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://open.bigmodel.cn/api/monitor/usage/quota/limit', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'zhipuai-coding-plan', pName: 'Zhipu AI Coding Plan', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const limits = (d && d.data && Array.isArray(d.data.limits)) ? d.data.limits : [];
    const tokensLimit = limits.find((x) => x && x.type === 'TOKENS_LIMIT');
    const mcpToolsTimeLimit = limits.find((x) => x && x.type === 'TIME_LIMIT');
    const w = {};
    if (tokensLimit) {
      const windowSeconds = resolveWindowSeconds(tokensLimit);
      const resetAt = tokensLimit.nextResetTime ? normalizeTimestamp(tokensLimit.nextResetTime) : null;
      const usedPercent = typeof tokensLimit.percentage === 'number' ? tokensLimit.percentage : null;
      w.Tokens = tUW({ uP: usedPercent, wS: windowSeconds, rA: resetAt });
    }
    if (mcpToolsTimeLimit) {
      const monthSeconds = 30 * 24 * 3600;
      const resetAt = mcpToolsTimeLimit.nextResetTime ? normalizeTimestamp(mcpToolsTimeLimit.nextResetTime) : null;
      const usedPercent = typeof mcpToolsTimeLimit.percentage === 'number' ? mcpToolsTimeLimit.percentage : null;
      w['MCP Tools'] = tUW({ uP: usedPercent, wS: monthSeconds, rA: resetAt });
    }
    return bR({ pId: 'zhipuai-coding-plan', pName: 'Zhipu AI Coding Plan', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'zhipuai-coding-plan', pName: 'Zhipu AI Coding Plan', ok: false, err: err.message });
  }
}
''';

String _jsMinimaxCodingPlanProvider() => r'''
async function fMinimax(a) {
  const e = nE(getE(a, ['minimax-coding-plan']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://api.minimax.io/v1/api/openplatform/coding_plan/remains', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'minimax-coding-plan', pName: 'MiniMax Coding Plan (minimax.io)', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const baseResp = d && d.base_resp;
    if (baseResp && baseResp.status_code !== undefined && baseResp.status_code !== 0) {
      return bR({ pId: 'minimax-coding-plan', pName: 'MiniMax Coding Plan (minimax.io)', ok: false, err: baseResp.status_msg || ('API error: ' + baseResp.status_code) });
    }
    const firstModel = d && Array.isArray(d.model_remains) && d.model_remains[0];
    if (!firstModel) return bR({ pId: 'minimax-coding-plan', pName: 'MiniMax Coding Plan (minimax.io)', ok: false, err: 'No model quota data available' });
    const intervalTotal = toN(firstModel.current_interval_total_count);
    const intervalUsage = toN(firstModel.current_interval_usage_count);
    const intervalStartAt = toTs(firstModel.start_time);
    const intervalResetAt = toTs(firstModel.end_time);
    const weeklyTotal = toN(firstModel.current_weekly_total_count);
    const weeklyUsage = toN(firstModel.current_weekly_usage_count);
    const weeklyStartAt = toTs(firstModel.weekly_start_time);
    const weeklyResetAt = toTs(firstModel.weekly_end_time);
    // Non-CN: usage IS the used count.
    const intervalUsed = intervalUsage;
    const weeklyUsed = weeklyUsage;
    // The Coding Plan rate-limit returns total=0 with a separate
    // `current_*_remaining_percent` field for the actual signal. Fall back
    // to that field when the count formula cannot produce a percent (so the
    // popup filter does not hide the row).
    const intervalRemPct = toN(firstModel.current_interval_remaining_percent);
    const weeklyRemPct = toN(firstModel.current_weekly_remaining_percent);
    const intervalUsedPercent = (intervalTotal > 0 && intervalUsed !== null)
      ? Math.max(0, Math.min(100, (intervalUsed / intervalTotal) * 100))
      : (intervalRemPct !== null ? Math.max(0, Math.min(100, 100 - intervalRemPct)) : null);
    const intervalWindowSeconds = (intervalStartAt && intervalResetAt && intervalResetAt > intervalStartAt) ? Math.floor((intervalResetAt - intervalStartAt) / 1000) : null;
    const weeklyUsedPercent = (weeklyTotal > 0 && weeklyUsed !== null)
      ? Math.max(0, Math.min(100, (weeklyUsed / weeklyTotal) * 100))
      : (weeklyRemPct !== null ? Math.max(0, Math.min(100, 100 - weeklyRemPct)) : null);
    const weeklyWindowSeconds = (weeklyStartAt && weeklyResetAt && weeklyResetAt > weeklyStartAt) ? Math.floor((weeklyResetAt - weeklyStartAt) / 1000) : null;
    const w = {
      '5h': tUW({ uP: intervalUsedPercent, wS: intervalWindowSeconds, rA: intervalResetAt }),
      weekly: tUW({ uP: weeklyUsedPercent, wS: weeklyWindowSeconds, rA: weeklyResetAt }),
    };
    return bR({ pId: 'minimax-coding-plan', pName: 'MiniMax Coding Plan (minimax.io)', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'minimax-coding-plan', pName: 'MiniMax Coding Plan (minimax.io)', ok: false, err: err.message });
  }
}
''';

String _jsMinimaxCnCodingPlanProvider() => r'''
async function fMinimaxCn(a) {
  const e = nE(getE(a, ['minimax-cn-coding-plan']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://www.minimaxi.com/v1/api/openplatform/coding_plan/remains', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'minimax-cn-coding-plan', pName: 'MiniMax Coding Plan (minimaxi.com)', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const baseResp = d && d.base_resp;
    if (baseResp && baseResp.status_code !== undefined && baseResp.status_code !== 0) {
      return bR({ pId: 'minimax-cn-coding-plan', pName: 'MiniMax Coding Plan (minimaxi.com)', ok: false, err: baseResp.status_msg || ('API error: ' + baseResp.status_code) });
    }
    const firstModel = d && Array.isArray(d.model_remains) && d.model_remains[0];
    if (!firstModel) return bR({ pId: 'minimax-cn-coding-plan', pName: 'MiniMax Coding Plan (minimaxi.com)', ok: false, err: 'No model quota data available' });
    const intervalTotal = toN(firstModel.current_interval_total_count);
    const intervalUsage = toN(firstModel.current_interval_usage_count);
    const intervalStartAt = toTs(firstModel.start_time);
    const intervalResetAt = toTs(firstModel.end_time);
    const weeklyTotal = toN(firstModel.current_weekly_total_count);
    const weeklyUsage = toN(firstModel.current_weekly_usage_count);
    const weeklyStartAt = toTs(firstModel.weekly_start_time);
    const weeklyResetAt = toTs(firstModel.weekly_end_time);
    // CN: usage is REMAINING, not used. Subtract to get the used count.
    const intervalUsed = (intervalTotal !== null && intervalUsage !== null) ? Math.max(0, Math.min(intervalTotal, intervalTotal - intervalUsage)) : null;
    const weeklyUsed = (weeklyTotal !== null && weeklyUsage !== null) ? Math.max(0, Math.min(weeklyTotal, weeklyTotal - weeklyUsage)) : null;
    // The Coding Plan rate-limit returns total=0 with a separate
    // `current_*_remaining_percent` field for the actual signal. Fall back
    // to that field when the count formula cannot produce a percent (so the
    // popup filter does not hide the row).
    const intervalRemPct = toN(firstModel.current_interval_remaining_percent);
    const weeklyRemPct = toN(firstModel.current_weekly_remaining_percent);
    const intervalUsedPercent = (intervalTotal > 0 && intervalUsed !== null)
      ? Math.max(0, Math.min(100, (intervalUsed / intervalTotal) * 100))
      : (intervalRemPct !== null ? Math.max(0, Math.min(100, 100 - intervalRemPct)) : null);
    const intervalWindowSeconds = (intervalStartAt && intervalResetAt && intervalResetAt > intervalStartAt) ? Math.floor((intervalResetAt - intervalStartAt) / 1000) : null;
    const weeklyUsedPercent = (weeklyTotal > 0 && weeklyUsed !== null)
      ? Math.max(0, Math.min(100, (weeklyUsed / weeklyTotal) * 100))
      : (weeklyRemPct !== null ? Math.max(0, Math.min(100, 100 - weeklyRemPct)) : null);
    const weeklyWindowSeconds = (weeklyStartAt && weeklyResetAt && weeklyResetAt > weeklyStartAt) ? Math.floor((weeklyResetAt - weeklyStartAt) / 1000) : null;
    const w = {
      '5h': tUW({ uP: intervalUsedPercent, wS: intervalWindowSeconds, rA: intervalResetAt }),
      weekly: tUW({ uP: weeklyUsedPercent, wS: weeklyWindowSeconds, rA: weeklyResetAt }),
    };
    return bR({ pId: 'minimax-cn-coding-plan', pName: 'MiniMax Coding Plan (minimaxi.com)', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'minimax-cn-coding-plan', pName: 'MiniMax Coding Plan (minimaxi.com)', ok: false, err: err.message });
  }
}
''';

String _jsZaiCodingPlanProvider() => r'''
async function fZai(a) {
  const e = nE(getE(a, ['zai-coding-plan', 'zai', 'z.ai']));
  const k = e && (e.key || e.token);
  if (!k) return null;
  try {
    const res = await fetch('https://api.z.ai/api/monitor/usage/quota/limit', {
      headers: { Authorization: 'Bearer ' + k, 'Content-Type': 'application/json' }
    });
    if (!res.ok) return bR({ pId: 'zai-coding-plan', pName: 'z.ai', ok: false, err: 'API error: ' + res.status });
    const d = await res.json();
    const limits = (d && d.data && Array.isArray(d.data.limits)) ? d.data.limits : [];
    const tokensLimit = limits.find((x) => x && x.type === 'TOKENS_LIMIT');
    if (!tokensLimit) return bR({ pId: 'zai-coding-plan', pName: 'z.ai', ok: true, use: { windows: {} } });
    const windowSeconds = resolveWindowSeconds(tokensLimit);
    const windowLabel = resolveWindowLabel(windowSeconds);
    const resetAt = tokensLimit.nextResetTime ? normalizeTimestamp(tokensLimit.nextResetTime) : null;
    const usedPercent = typeof tokensLimit.percentage === 'number' ? tokensLimit.percentage : null;
    const w = {};
    w[windowLabel] = tUW({ uP: usedPercent, wS: windowSeconds, rA: resetAt });
    return bR({ pId: 'zai-coding-plan', pName: 'z.ai', ok: true, use: { windows: w } });
  } catch (err) {
    return bR({ pId: 'zai-coding-plan', pName: 'z.ai', ok: false, err: err.message });
  }
}
''';

String _jsCursorProvider() => r'''
async function fCursor(a) {
  const e = nE(getE(a, ['cursor']));
  const apiKey = e && (e.key || e.token);
  const refreshT = e && e.refreshToken;

  const BASE_URL = 'https://api2.cursor.sh';
  const USAGE_URL = BASE_URL + '/aiserver.v1.DashboardService/GetCurrentPeriodUsage';
  const PLAN_URL = BASE_URL + '/aiserver.v1.DashboardService/GetPlanInfo';
  const CREDITS_URL = BASE_URL + '/aiserver.v1.DashboardService/GetCreditGrantsBalance';
  const REFRESH_URL = BASE_URL + '/oauth/token';
  const CLIENT_ID = 'KbZUR41cY7W6zRSdpSUJ7I7mLYBKOCmB';
  const REFRESH_BUFFER_MS = 5 * 60 * 1000;
  const STATE_DB = p.join(os.homedir(), 'Library', 'Application Support', 'Cursor', 'User', 'globalStorage', 'state.vscdb');

  const readJwtPayload = (token) => {
    try {
      const parts = String(token).split('.');
      if (!parts[1]) return null;
      return JSON.parse(Buffer.from(parts[1], 'base64').toString('utf8'));
    } catch (e) { return null; }
  };

  const readStateValue = (key) => {
    if (!fs.existsSync(STATE_DB)) return null;
    try {
      const escapedKey = String(key).replace(/\'/g, "\'\'");
      const { execFileSync } = require('child_process');
      const rows = execFileSync('sqlite3', ['-json', STATE_DB, "SELECT value FROM ItemTable WHERE key = '" + escapedKey + "' LIMIT 1;"], {
        encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'pipe', 'ignore']
      });
      const parsed = JSON.parse(rows || '[]');
      return parsed && parsed[0] && parsed[0].value ? String(parsed[0].value).trim() : null;
    } catch (e) { return null; }
  };

  const writeStateValue = (key, value) => {
    if (!fs.existsSync(STATE_DB)) return false;
    try {
      const escaped = String(value).replace(/\'/g, "\'\'");
      const escapedKey = String(key).replace(/\'/g, "\'\'");
      const { execFileSync } = require('child_process');
      execFileSync('sqlite3', [STATE_DB, "INSERT OR REPLACE INTO ItemTable (key, value) VALUES ('" + escapedKey + "', '" + escaped + "');"], {
        encoding: 'utf8', windowsHide: true, stdio: ['ignore', 'ignore', 'ignore']
      });
      return true;
    } catch (e) { return false; }
  };

  const readFileToken = (path) => {
    try {
      if (!path || !fs.existsSync(path)) return null;
      return fs.readFileSync(path, 'utf8').trim() || null;
    } catch (e) { return null; }
  };

  const writeFileToken = (path, value) => {
    try {
      if (!path) return false;
      fs.writeFileSync(path, value + '\n', { encoding: 'utf8', mode: 0o600 });
      return true;
    } catch (e) { return false; }
  };

  const loadAuthState = () => {
    const envAccessToken = process.env.CURSOR_TOKEN || process.env.CURSOR_ACCESS_TOKEN || null;
    const envRefreshToken = process.env.CURSOR_REFRESH_TOKEN || null;
    const accessTokenPath = process.env.CURSOR_TOKEN_FILE || null;
    const refreshTokenPath = process.env.CURSOR_REFRESH_TOKEN_FILE || null;
    const fileAccessToken = readFileToken(accessTokenPath);
    const fileRefreshToken = readFileToken(refreshTokenPath);
    if (envAccessToken || envRefreshToken) return { accessToken: envAccessToken, refreshToken: envRefreshToken, source: 'env' };
    if (fileAccessToken || fileRefreshToken) return { accessToken: fileAccessToken, refreshToken: fileRefreshToken, source: 'file', accessTokenPath: accessTokenPath };
    return {
      accessToken: apiKey || readStateValue('cursorAuth/accessToken'),
      refreshToken: refreshT || readStateValue('cursorAuth/refreshToken'),
      source: apiKey ? 'auth_json' : 'sqlite'
    };
  };

  const tokenNeedsRefresh = (token) => {
    if (!token) return true;
    const payload = readJwtPayload(token);
    const expiresAt = payload && typeof payload.exp === 'number' ? payload.exp * 1000 : null;
    return !expiresAt || (expiresAt - Date.now() <= REFRESH_BUFFER_MS);
  };

  const persistAccessToken = (auth, accessToken) => {
    if (auth.source === 'sqlite') writeStateValue('cursorAuth/accessToken', accessToken);
    if (auth.source === 'file' && auth.accessTokenPath) writeFileToken(auth.accessTokenPath, accessToken);
  };

  const refreshAccessToken = async (auth) => {
    if (!auth.refreshToken) return auth.accessToken;
    const response = await fetch(REFRESH_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ grant_type: 'refresh_token', client_id: CLIENT_ID, refresh_token: auth.refreshToken })
    });
    const body = await response.json().catch(() => null);
    if (body && body.shouldLogout === true) throw new Error('Session expired - please sign in to Cursor again');
    if (!response.ok) throw new Error(response.status === 401 ? 'Cursor session expired' : ('API error: ' + response.status));
    if (!body || typeof body.access_token !== 'string' || !body.access_token) throw new Error('Cursor refresh response did not include an access token');
    persistAccessToken(auth, body.access_token);
    return body.access_token;
  };

  const resolveAccessToken = async () => {
    const auth = loadAuthState();
    if (!auth.accessToken && !auth.refreshToken) return null;
    if (!tokenNeedsRefresh(auth.accessToken)) return auth.accessToken;
    return refreshAccessToken(auth);
  };

  const connectPost = async (url, accessToken) => {
    const response = await fetch(url, {
      method: 'POST',
      headers: { Authorization: 'Bearer ' + accessToken, 'Content-Type': 'application/json', 'Connect-Protocol-Version': '1' },
      body: '{}'
    });
    if (!response.ok) throw new Error(response.status === 401 ? 'Cursor session expired' : ('API error: ' + response.status));
    return response.json();
  };

  const formatMoney = (value) => {
    const n = toN(value);
    return n === null ? null : n.toFixed(2);
  };

  const centsLabel = (cents) => {
    const value = toN(cents);
    return value === null ? null : '$' + formatMoney(value / 100);
  };

  const percentFromSpend = (planUsage) => {
    const explicit = toN(planUsage && planUsage.totalPercentUsed);
    if (explicit !== null) return explicit;
    const limit = toN(planUsage && planUsage.limit);
    const remaining = toN(planUsage && planUsage.remaining);
    if (!limit || remaining === null) return null;
    return Math.min(100, Math.max(0, ((limit - remaining) / limit) * 100));
  };

  const buildWindows = (usage, plan) => {
    const planUsage = (usage && usage.planUsage) || {};
    const spendLimitUsage = (usage && usage.spendLimitUsage) || {};
    const resetAt = toTs((usage && usage.billingCycleEnd) || (plan && plan.planInfo && plan.planInfo.billingCycleEnd));
    const windowSeconds = resetAt ? Math.max(0, Math.floor((resetAt - Date.now()) / 1000)) : null;
    const windows = {};
    windows.billing_cycle = tUW({ uP: percentFromSpend(planUsage), wS: windowSeconds, rA: resetAt, vL: centsLabel(planUsage && planUsage.totalSpend) });
    const autoPercent = toN(planUsage && planUsage.autoPercentUsed);
    if (autoPercent !== null) windows.auto = tUW({ uP: autoPercent, wS: windowSeconds, rA: resetAt });
    const apiPercent = toN(planUsage && planUsage.apiPercentUsed);
    if (apiPercent !== null) windows.api = tUW({ uP: apiPercent, wS: windowSeconds, rA: resetAt });
    const planLimit = centsLabel(planUsage && planUsage.limit);
    if (planLimit) {
      const limit = toN(planUsage && planUsage.limit);
      const remaining = toN(planUsage && planUsage.remaining);
      const limitRemaining = centsLabel(remaining) || '$0.00';
      windows.plan_limit = tUW({
        uP: limit && remaining !== null ? Math.min(100, Math.max(0, ((limit - remaining) / limit) * 100)) : null,
        wS: windowSeconds,
        rA: resetAt,
        vL: limitRemaining + ' remaining of ' + planLimit
      });
    }
    const onDemandLimit = toN(spendLimitUsage.individualLimit) || toN(spendLimitUsage.pooledLimit);
    if (onDemandLimit && onDemandLimit > 0) {
      const remaining = toN(spendLimitUsage.individualRemaining) || toN(spendLimitUsage.pooledRemaining) || 0;
      const limitRemaining = centsLabel(remaining) || '$0.00';
      windows.on_demand = tUW({
        uP: Math.min(100, Math.max(0, ((onDemandLimit - remaining) / onDemandLimit) * 100)),
        wS: windowSeconds,
        rA: resetAt,
        vL: limitRemaining + ' remaining of ' + centsLabel(onDemandLimit)
      });
    }
    return windows;
  };

  const appendCreditsWindow = (windows, credits) => {
    const balance = toN((credits && credits.balanceCents) || (credits && credits.totalBalanceCents) || (credits && credits.amountCents));
    if (balance === null) return;
    windows.credits = tUW({ uP: null, wS: null, rA: null, vL: centsLabel(balance) });
  };

  const accessToken = await resolveAccessToken();
  if (!accessToken) return null;

  try {
    const [usage, plan, credits] = await Promise.all([
      connectPost(USAGE_URL, accessToken),
      connectPost(PLAN_URL, accessToken).catch(() => null),
      connectPost(CREDITS_URL, accessToken).catch(() => null)
    ]);
    if (!usage || usage.enabled === false || !usage.planUsage) {
      return bR({ pId: 'cursor', pName: 'Cursor', ok: false, err: 'No active Cursor subscription' });
    }
    const windows = buildWindows(usage, plan);
    appendCreditsWindow(windows, credits);
    const planName = plan && plan.planInfo && plan.planInfo.planName;
    return bR({
      pId: 'cursor',
      pName: planName ? 'Cursor ' + planName : 'Cursor',
      ok: true,
      use: { windows }
    });
  } catch (err) {
    return bR({ pId: 'cursor', pName: 'Cursor', ok: false, err: err.message });
  }
}
''';

String _jsOllamaCloudProvider() => r'''
async function fOllamaCloud(a) {
  const e = nE(getE(a, ['ollama-cloud', 'ollamacloud']));
  const rawCookie = e && (e.key || e.token || e.cookie);
  const COOKIE_PATH = p.join(os.homedir(), '.config', 'ollama-quota', 'cookie');
  const readCookieFile = () => {
    try {
      if (!fs.existsSync(COOKIE_PATH)) return null;
      return fs.readFileSync(COOKIE_PATH, 'utf-8').trim() || null;
    } catch (err) { return null; }
  };
  const parseOllamaSettingsHtml = (html) => {
    const windows = {};
    const sessionMatch = html.match(/Session\s+usage[^0-9]*([0-9.]+)%/i);
    if (sessionMatch) windows.session = tUW({ uP: toN(sessionMatch[1]), wS: null, rA: null });
    const weeklyMatch = html.match(/Weekly\s+usage[^0-9]*([0-9.]+)%/i);
    if (weeklyMatch) windows.weekly = tUW({ uP: toN(weeklyMatch[1]), wS: null, rA: null });
    const premiumMatch = html.match(/Premium[^0-9]*([0-9]+)\s*\/\s*([0-9]+)/i);
    if (premiumMatch) {
      const used = toN(premiumMatch[1]);
      const total = toN(premiumMatch[2]);
      const uP = total && used !== null ? Math.min(100, (used / total) * 100) : null;
      windows.premium = tUW({ uP, wS: null, rA: null, vL: (used === null ? 0 : used) + ' / ' + (total === null ? 0 : total) });
    }
    return windows;
  };
  const cookie = rawCookie || readCookieFile();
  if (!cookie) return null;
  try {
    const res = await fetch('https://ollama.com/settings', {
      headers: { Cookie: cookie, 'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36' }
    });
    if (!res.ok) return bR({ pId: 'ollama-cloud', pName: 'Ollama Cloud', ok: false, err: 'API error: ' + res.status });
    const html = await res.text();
    const windows = parseOllamaSettingsHtml(html);
    if (!windows || Object.keys(windows).length === 0) {
      const fragment = html.substring(0, 200);
      return bR({ pId: 'ollama-cloud', pName: 'Ollama Cloud', ok: false, err: 'Failed to parse Ollama Cloud usage: ' + fragment });
    }
    return bR({ pId: 'ollama-cloud', pName: 'Ollama Cloud', ok: true, use: { windows } });
  } catch (err) {
    return bR({ pId: 'ollama-cloud', pName: 'Ollama Cloud', ok: false, err: err.message });
  }
}
''';

String _jsDispatcher({required String supportedKeysLiteral}) {
  return r'''
(async () => {
  const a = rAuth();
  const authKeys = Object.keys(a);
  const R = [];
  const c = await fC(a); if (c) R.push(c);
  const o = await fO(a); if (o) R.push(o);
  const x = await fX(a); if (x) R.push(x);
  const g = await fG(a); if (g) R.push(g);
  const gh = await fGH(a); if (gh) R.push(gh);
  const ocg = await fOCG(a); if (ocg) R.push(ocg);
  const ng = await fNanoGpt(a); if (ng) R.push(ng);
  const wf = await fWafer(a); if (wf) R.push(wf);
  const gha = await fGHA(a); if (gha) R.push(gha);
  const km = await fKimi(a); if (km) R.push(km);
  const zp = await fZhipu(a); if (zp) R.push(zp);
  const mx = await fMinimax(a); if (mx) R.push(mx);
  const mxc = await fMinimaxCn(a); if (mxc) R.push(mxc);
  const za = await fZai(a); if (za) R.push(za);
  const cu = await fCursor(a); if (cu) R.push(cu);
  const oc = await fOllamaCloud(a); if (oc) R.push(oc);

  const unsupported = authKeys.filter(
    (k) => !__SUPPORTED_KEYS_LITERAL__.includes(k),
  );
  console.log(
    P + JSON.stringify({
      results: R,
      meta: {
        authKeys: authKeys,
        unsupportedConfigured: unsupported,
        resultProviderIds: R.map((r) => r.providerId),
      },
    }),
  );
})().catch((err) => {
  console.log(P + JSON.stringify({ results: [], meta: { error: String(err) } }));
});
'''
      .replaceAll('__SUPPORTED_KEYS_LITERAL__', supportedKeysLiteral);
}
