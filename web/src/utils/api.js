import { apiPath } from '../utils/constants';

async function readJson(response) {
  const text = await response.text();
  if (!text) return {};
  try {
    return JSON.parse(text);
  } catch {
    throw new Error(text || `HTTP ${response.status}`);
  }
}

export async function requestJson(path, options = {}) {
  const response = await fetch(apiPath(path), {
    cache: 'no-store',
    ...options,
  });
  const data = await readJson(response);

  if (!response.ok || data.ok === false) {
    throw new Error(data.error || `HTTP ${response.status}`);
  }

  return data;
}
