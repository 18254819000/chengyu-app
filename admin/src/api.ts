// 后端接口封装：统一带 JWT，401 时跳登录页
const BASE = '/api/v1';

export function getToken(): string {
  return localStorage.getItem('chengyu_token') || '';
}
export function setToken(t: string) {
  localStorage.setItem('chengyu_token', t);
}
export function clearToken() {
  localStorage.removeItem('chengyu_token');
}

export async function api(path: string, opts: RequestInit = {}): Promise<any> {
  const headers: Record<string, string> = { ...(opts.headers as any) };
  const token = getToken();
  if (token) headers['Authorization'] = `Bearer ${token}`;
  let body = opts.body as any;
  if (body && !(body instanceof FormData)) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(body);
  }
  const res = await fetch(BASE + path, { ...opts, headers, body });
  const text = await res.text();
  let json: any = null;
  try { json = JSON.parse(text); } catch { /* ignore */ }
  if (res.status === 401) {
    clearToken();
    if (location.hash !== '#/login') location.hash = '#/login';
    throw new Error('登录已失效，请重新登录');
  }
  if (!res.ok) {
    throw new Error(json?.message || `请求失败（${res.status}）`);
  }
  return json;
}
