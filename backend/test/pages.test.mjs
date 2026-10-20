// 协议与政策（ContentPage）接口测试（本地 SQLite 环境，需先启动服务）
// 运行：node test/pages.test.mjs [baseUrl]，默认 base 为 http://localhost:3000（注意：公开页不带 /api/v1 前缀）
const ORIGIN = process.argv[2] || 'http://localhost:3000';
const BASE = ORIGIN + '/api/v1';

const results = [];
function check(name, cond, detail = '') {
  results.push({ name, pass: !!cond });
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
}

async function req(url, opts = {}) {
  const headers = { ...(opts.headers || {}) };
  let body;
  if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(opts.body);
  }
  if (opts.token) headers['Authorization'] = `Bearer ${opts.token}`;
  const res = await fetch(url, { method: opts.method || 'GET', headers, body });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* 非 JSON */ }
  return { status: res.status, json, text, contentType: res.headers.get('content-type') || '' };
}

async function main() {
  // ---------- 鉴权 ----------
  const unauthPut = await req(`${BASE}/admin/pages/privacy`, {
    method: 'PUT',
    body: { title: 'x', content: 'x' },
  });
  check('未登录 PUT /admin/pages/:key 被拒（401）', unauthPut.status === 401, `status=${unauthPut.status}`);

  const unauthList = await req(`${BASE}/admin/pages`);
  check('未登录 GET /admin/pages 被拒（401）', unauthList.status === 401, `status=${unauthList.status}`);

  const login = await req(`${BASE}/admin/login`, {
    method: 'POST',
    body: { username: 'admin', password: 'admin123' },
  });
  check('管理员登录成功', login.status === 200 && !!login.json?.token, `status=${login.status}`);
  const token = login.json.token;

  // ---------- 管理端列表与详情 ----------
  const list = await req(`${BASE}/admin/pages`, { token });
  check('GET /admin/pages 返回两篇（privacy/terms）',
    list.status === 200 && Array.isArray(list.json) && list.json.length === 2 &&
    list.json.every((p) => p.key && p.title && p.updated_at),
    JSON.stringify(list.json));

  const detail = await req(`${BASE}/admin/pages/privacy`, { token });
  check('GET /admin/pages/privacy 返回初稿全文（Markdown）',
    detail.status === 200 && detail.json.title === 'Privacy Policy' &&
    detail.json.content.includes('Tai\'an Mengma Software Service') && detail.json.content.includes('kingsummerai@gmail.com'),
    `title=${detail.json?.title}, len=${detail.json?.content?.length}`);

  const notFound = await req(`${BASE}/admin/pages/nope`, { token });
  check('GET 不存在的 key 返回 404', notFound.status === 404, `status=${notFound.status}`);

  // ---------- 公开 JSON ----------
  const pubJson = await req(`${BASE}/pages/terms`);
  check('公开 JSON GET /api/v1/pages/terms 可读',
    pubJson.status === 200 && pubJson.json.key === 'terms' && pubJson.json.title === 'Terms of Use' &&
    pubJson.json.content.includes('US$9.9') && !!pubJson.json.updated_at,
    `title=${pubJson.json?.title}`);

  const pub404 = await req(`${BASE}/pages/nope`);
  check('公开 JSON 不存在的 key 返回 404', pub404.status === 404, `status=${pub404.status}`);

  // ---------- 公开 HTML 页 ----------
  const htmlP = await req(`${ORIGIN}/pages/privacy`);
  check('GET /pages/privacy 返回 text/html 且为完整文档',
    htmlP.status === 200 && htmlP.contentType.includes('text/html') &&
    htmlP.text.startsWith('<!DOCTYPE html>') && htmlP.text.includes('<title>Privacy Policy'),
    `status=${htmlP.status}, type=${htmlP.contentType}`);
  check('隐私政策 HTML 含渲染后正文（小节标题已成 HTML 标签）',
    htmlP.text.includes('<h2>') && htmlP.text.includes('Information We Collect') && !htmlP.text.includes('## 1.'));

  const htmlT = await req(`${ORIGIN}/pages/terms`);
  check('GET /pages/terms 返回 text/html 且含协议标题',
    htmlT.status === 200 && htmlT.contentType.includes('text/html') &&
    htmlT.text.includes('<title>Terms of Use') && htmlT.text.includes('Auto-renewal'),
    `status=${htmlT.status}`);

  const html404 = await req(`${ORIGIN}/pages/nope`);
  check('GET /pages/nope 返回 404 HTML', html404.status === 404 && html404.contentType.includes('text/html'), `status=${html404.status}`);

  // ---------- 编辑保存往返 ----------
  const marker = `测试标记 ${Date.now()}`;
  const put = await req(`${BASE}/admin/pages/privacy`, {
    method: 'PUT',
    token,
    body: { title: 'Privacy Policy', content: detail.json.content + `\n\n${marker}\n\n<script>alert(1)</script>` },
  });
  check('登录后 PUT 保存成功', put.status === 200 && put.json.content.includes(marker), `status=${put.status}`);

  const after = await req(`${BASE}/admin/pages/privacy`, { token });
  check('再 GET 内容已更新且 updated_at 变化',
    after.json.content.includes(marker) && after.json.updated_at >= detail.json.updated_at,
    `updated_at: ${detail.json.updated_at} -> ${after.json.updated_at}`);

  const htmlAfter = await req(`${ORIGIN}/pages/privacy`);
  check('公开 HTML 同步显示新内容，且 <script> 已被消毒去掉',
    htmlAfter.text.includes(marker) && !htmlAfter.text.includes('<script>alert(1)</script>'));

  const cfgBefore = await req(`${BASE}/config`);
  await req(`${BASE}/admin/pages/privacy`, {
    method: 'PUT',
    token,
    body: { title: 'Privacy Policy', content: detail.json.content },
  });
  const cfgAfter = await req(`${BASE}/config`);
  check('PUT 内容页未改动 content_version',
    cfgBefore.json.content_version === cfgAfter.json.content_version,
    `version=${cfgAfter.json.content_version}`);
  const restored = await req(`${BASE}/pages/privacy`);
  check('内容已还原为初稿（去掉测试标记）', restored.status === 200 && !restored.json.content.includes(marker));

  const fail = results.filter((r) => !r.pass).length;
  console.log(`\n共 ${results.length} 项，通过 ${results.length - fail}，失败 ${fail}`);
  process.exit(fail ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
