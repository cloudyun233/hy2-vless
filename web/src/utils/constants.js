export const API_BASE = (import.meta.env.VITE_API_BASE || '').replace(/\/$/, '');
export const STATUS_INTERVAL_MS = 5000;
export const STATUS_INTERVAL_HIDDEN_MS = 30000;
export const KEY_STORAGE = 'moonroom.accessKey';
export const RECENT_STORAGE = 'moonroom.recentFiles';
export const PROGRESS_STORAGE = 'moonroom.playProgress';

export function apiPath(path) {
  return `${API_BASE}${path}`;
}

export function serverAsset(url) {
  const value = String(url || '');
  if (!value || /^(https?:)?\/\//i.test(value) || value.startsWith('data:')) return value;
  return `${API_BASE}${value.startsWith('/') ? value : `/${value}`}`;
}

export function percent(value) {
  return `${Math.max(0, Math.min(100, Number(value) || 0))}%`;
}

export function fileSignature(files) {
  return files.map((file) => `${file.id}|${file.size}|${file.mtime}`).join('||');
}

export function progressLabel(saved) {
  if (!saved?.duration || !saved?.time) return '';
  return `${Math.round((saved.time / saved.duration) * 100)}%`;
}

export function sortFiles(files, sortMode, recentIds) {
  const recentRank = new Map(recentIds.map((id, index) => [id, index]));
  const next = [...files];
  if (sortMode === 'name') return next.sort((a, b) => a.name.localeCompare(b.name, 'zh-CN', { numeric: true }));
  if (sortMode === 'size') return next.sort((a, b) => Number(b.size || 0) - Number(a.size || 0));
  if (sortMode === 'recent') {
    return next.sort((a, b) => {
      const ar = recentRank.has(a.id) ? recentRank.get(a.id) : 9999;
      const br = recentRank.has(b.id) ? recentRank.get(b.id) : 9999;
      return ar - br || Number(b.mtimeMs || 0) - Number(a.mtimeMs || 0);
    });
  }
  return next.sort((a, b) => Number(b.mtimeMs || 0) - Number(a.mtimeMs || 0));
}
