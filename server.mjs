import http from 'node:http';
import https from 'node:https';
import fs from 'node:fs';
import fsp from 'node:fs/promises';
import path from 'node:path';
import crypto from 'node:crypto';
import { URL } from 'node:url';

const port = Number(process.env.HTTP_LISTEN_PORT || process.env.HY2_PORT || 20164);
const frontendDist = path.resolve(process.env.FRONTEND_DIST_DIR || path.join(process.cwd(), 'dist'));
const fileRoot = path.resolve(process.env.FILE_PATH || path.join(process.cwd(), '.npm/video'));
const tlsCertPath = path.resolve(process.env.TLS_CERT_PATH || path.join(fileRoot, 'cert.pem'));
const tlsKeyPath = path.resolve(process.env.TLS_KEY_PATH || path.join(fileRoot, 'private.key'));
const visitorFile = path.join(fileRoot, 'weekly_visitors.json');

const staticMime = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.svg': 'image/svg+xml; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.webp': 'image/webp',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8',
  '.xml': 'application/xml; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.woff2': 'font/woff2',
};

function log(...args) {
  console.log(new Date().toISOString(), ...args);
}

function loadTlsOptions() {
  if (!fs.existsSync(tlsCertPath) || !fs.existsSync(tlsKeyPath)) return null;
  try {
    return { cert: fs.readFileSync(tlsCertPath), key: fs.readFileSync(tlsKeyPath) };
  } catch (error) {
    log('[TLS] load failed:', error?.message || error);
    return null;
  }
}

function inside(root, target) {
  const resolvedRoot = path.resolve(root);
  const resolvedTarget = path.resolve(target);
  return resolvedTarget === resolvedRoot || resolvedTarget.startsWith(resolvedRoot + path.sep);
}

function sendText(res, code, text) {
  res.writeHead(code, { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store' });
  res.end(text);
}

function sendJson(res, code, obj) {
  const body = JSON.stringify(obj);
  res.writeHead(code, {
    'Content-Type': 'application/json; charset=utf-8',
    'Content-Length': Buffer.byteLength(body),
    'Cache-Control': 'no-store',
  });
  res.end(body);
}

// ---- 访客统计（按周去重） ----
function weekKey(ts = Date.now()) {
  const date = new Date(ts + 8 * 3600_000);
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() - day + 1);
  return date.toISOString().slice(0, 10);
}

let visitors = { weekKey: weekKey(), ids: [] };
let visitorSet = new Set();
try {
  const old = JSON.parse(await fsp.readFile(visitorFile, 'utf8'));
  if (old?.weekKey === weekKey() && Array.isArray(old.ids)) visitors = old;
} catch {}
visitorSet = new Set(visitors.ids);

async function saveVisitors() {
  try {
    await fsp.writeFile(`${visitorFile}.tmp`, JSON.stringify(visitors), { mode: 0o600 });
    await fsp.rename(`${visitorFile}.tmp`, visitorFile);
  } catch {}
}

function recordVisit(req) {
  const currentWeek = weekKey();
  if (visitors.weekKey !== currentWeek) {
    visitors = { weekKey: currentWeek, ids: [] };
    visitorSet = new Set();
  }
  const ip = String(req.headers['x-forwarded-for'] || req.socket.remoteAddress || '').split(',')[0].trim();
  const ua = String(req.headers['user-agent'] || '');
  const id = crypto.createHash('sha256').update(`${ip}|${ua}`).digest('hex').slice(0, 24);
  if (!visitorSet.has(id)) {
    visitorSet.add(id);
    visitors.ids.push(id);
    saveVisitors();
  }
}

// ---- 前端静态服务 ----
async function serveDist(req, res, pathname) {
  if (req.method !== 'GET' && req.method !== 'HEAD') return false;

  let rel = pathname === '/' ? 'index.html' : decodeURIComponent(pathname.slice(1));
  if (!rel || rel.includes('\0') || rel.split('/').includes('..')) return false;
  let full = path.resolve(frontendDist, rel);
  if (!inside(frontendDist, full)) return false;

  let stat;
  try {
    stat = await fsp.stat(full);
    if (stat.isDirectory()) {
      full = path.join(full, 'index.html');
      stat = await fsp.stat(full);
    }
  } catch {
    if (path.extname(rel)) return false;
    full = path.join(frontendDist, 'index.html');
    try {
      stat = await fsp.stat(full);
    } catch {
      return false;
    }
  }
  if (!stat.isFile()) return false;
  const ext = path.extname(full).toLowerCase();
  const cache = rel.startsWith('assets/') ? 'public,max-age=31536000,immutable' : 'no-cache';
  res.writeHead(200, {
    'Content-Type': staticMime[ext] || 'application/octet-stream',
    'Content-Length': stat.size,
    'Cache-Control': cache,
    'X-Content-Type-Options': 'nosniff',
  });
  if (req.method === 'HEAD') return res.end(), true;
  fs.createReadStream(full).pipe(res);
  return true;
}

const tlsOptions = loadTlsOptions();
const protocol = tlsOptions ? 'HTTPS' : 'HTTP';
const server = (tlsOptions ? https : http).createServer(tlsOptions || undefined, async (req, res) => {
  let pathname = '/';
  try {
    pathname = new URL(req.url, 'http://127.0.0.1').pathname;
  } catch {
    return sendText(res, 400, 'Bad Request');
  }

  try {
    if (req.method === 'GET' && (pathname === '/' || pathname === '/index.html')) recordVisit(req);
    if (await serveDist(req, res, pathname)) return;

    return sendText(res, 404, 'Not Found');
  } catch (error) {
    console.error(error);
    return sendJson(res, 500, { ok: false, error: error?.message || String(error) });
  }
});

server.on('error', (error) => {
  console.error(`[${protocol} server error]`, error);
  process.exit(1);
});

server.listen(port, '::', () => {
  log(
    `[${protocol}] listening on`,
    port,
    'frontend=',
    frontendDist,
    'tlsCert=',
    tlsOptions ? tlsCertPath : '未启用',
  );
});
