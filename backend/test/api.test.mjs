// 每日成语后端 API 测试（本地 SQLite 环境，需先启动服务）
// 运行：node test/api.test.mjs [baseUrl]，默认 http://localhost:3000/api/v1
const BASE = process.argv[2] || 'http://localhost:3000/api/v1';

const results = [];
function check(name, cond, detail = '') {
  results.push({ name, pass: !!cond, detail });
  console.log(`${cond ? 'PASS' : 'FAIL'}  ${name}${detail ? ' — ' + detail : ''}`);
}

async function req(method, path, opts = {}) {
  const headers = { ...(opts.headers || {}) };
  let body;
  if (opts.form) {
    body = opts.form;
  } else if (opts.body !== undefined) {
    headers['Content-Type'] = 'application/json';
    body = JSON.stringify(opts.body);
  }
  if (opts.token) headers['Authorization'] = `Bearer ${opts.token}`;
  const res = await fetch(BASE + path, { method, headers, body });
  const text = await res.text();
  let json = null;
  try { json = JSON.parse(text); } catch { /* 非 JSON */ }
  return { status: res.status, json, text };
}

const b64url = (obj) =>
  Buffer.from(JSON.stringify(obj)).toString('base64').replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
function fakeJws(payload) {
  return `${b64url({ alg: 'ES256', typ: 'JWT' })}.${b64url(payload)}.${b64url('dev-signature')}`;
}

async function main() {
  // ---------- 登录 ----------
  const badLogin = await req('POST', '/admin/login', { body: { username: 'admin', password: 'wrong-pass' } });
  check('登录失败被拒（401）', badLogin.status === 401, `status=${badLogin.status}`);

  const login = await req('POST', '/admin/login', { body: { username: 'admin', password: 'admin123' } });
  check('管理员登录成功并返回 token', login.status === 200 && !!login.json?.token, `status=${login.status}`);
  const token = login.json.token;

  const noAuth = await req('GET', '/admin/idioms');
  check('未授权访问后台接口被拒（401）', noAuth.status === 401, `status=${noAuth.status}`);

  // ---------- 初始配置 ----------
  const cfg0 = await req('GET', '/config');
  check('GET /config 返回 free_count=20 与 content_version',
    cfg0.status === 200 && cfg0.json.free_count === 20 && typeof cfg0.json.content_version === 'number',
    JSON.stringify(cfg0.json));
  const version0 = cfg0.json.content_version;

  // ---------- App 列表与锁定 ----------
  const list = await req('GET', '/idioms?page=1&pageSize=200');
  check('App 列表只含已发布成语共 30 条', list.status === 200 && list.json.total === 30, `total=${list.json?.total}`);
  // 新免费模型（2026-10-27）：非订阅用户仅当日成语解锁；列表已按 sort_order 升序返回
  const bySort = list.json.items;
  const dailyToday = await req('GET', '/daily');
  const unlockedItems = list.json.items.filter((i) => i.locked === false);
  check('非订阅用户列表仅当日成语解锁',
    unlockedItems.length === 1 && unlockedItems[0].id === dailyToday.json.id,
    `unlocked=${unlockedItems.map((i) => i.idiom).join(',')} daily=${dailyToday.json?.idiom}`);
  const lockedItem = list.json.items.find((i) => i.locked === true);
  check('非当日条目 locked=true 且不含释义与例句字段',
    lockedItem && !('definition_zh' in lockedItem) && !('definition_en' in lockedItem) && !('example_zh' in lockedItem));

  const detail403 = await req('GET', `/idioms/${lockedItem.id}`);
  check('非当日详情匿名访问返回 403', detail403.status === 403, `status=${detail403.status}`);
  check('403 响应不泄露释义/例句原文',
    !detail403.text.includes('definition_zh') && !detail403.text.includes('example_zh') && detail403.json?.locked === true);

  const detailFree = await req('GET', `/idioms/${dailyToday.json.id}`);
  check('当日免费详情可读且逐字拼音为数组',
    detailFree.status === 200 && Array.isArray(detailFree.json.pinyin_chars) && detailFree.json.pinyin_chars.length > 0);

  // ---------- daily 公式与稳定性 ----------
  const date = '2026-10-20';
  const days = Math.floor((Date.UTC(2026, 9, 20) - Date.UTC(2026, 0, 1)) / 86400000);
  const expected = bySort[days % bySort.length];
  const daily1 = await req('GET', `/daily?date=${date}`);
  const daily2 = await req('GET', `/daily?date=${date}`);
  check('daily 与公式计算一致', daily1.status === 200 && daily1.json.id === expected.id,
    `expected=${expected.idiom} got=${daily1.json?.idiom}`);
  check('daily 同日期两次调用结果稳定', daily1.json.id === daily2.json.id && daily1.json.date === date);
  check('daily 返回公开字段且不含例句',
    !!daily1.json.definition_zh && Array.isArray(daily1.json.pinyin_chars) && !('example_zh' in daily1.json));
  const week = await req('GET', `/daily/week?from=${date}`);
  check('daily/week 返回 7 天', week.status === 200 && week.json.days?.length === 7);

  // ---------- 新增成语校验 ----------
  const missing = await req('POST', '/admin/idioms', { token, body: { idiom: '残缺成语甲' } });
  check('新增草稿成功（仅成语也可存草稿）', missing.status === 201 || missing.status === 200);
  const missingPublish = await req('POST', `/admin/idioms/${missing.json.id}/publish`, { token });
  check('缺字段发布被拒并给出原因', missingPublish.status === 400 && /缺少必填/.test(missingPublish.text),
    missingPublish.json?.message || '');

  const badPinyin = await req('POST', '/admin/idioms', {
    token,
    body: {
      idiom: '拼音不符甲', pinyin: 'pīn yīn bù fú',
      pinyin_chars: 'pīn yīn bù',
      definition_zh: '测试释义', definition_en: 'test',
      example_zh: '这是拼音不符甲的例句。', example_en: 'test sentence',
    },
  });
  const badPinyinPublish = await req('POST', `/admin/idioms/${badPinyin.json.id}/publish`, { token });
  check('逐字拼音个数与汉字数不符发布被拒',
    badPinyinPublish.status === 400 && /不一致/.test(badPinyinPublish.text), badPinyinPublish.json?.message || '');

  const dup = await req('POST', '/admin/idioms', { token, body: { idiom: '画蛇添足' } });
  check('重复成语新增被拒', dup.status === 400 && /已存在/.test(dup.text));

  // ---------- 发布后出现在 App 列表 ----------
  const created = await req('POST', '/admin/idioms', {
    token,
    body: {
      idiom: '锦上添花', pinyin: 'jǐn shàng tiān huā', pinyin_chars: 'jǐn shàng tiān huā',
      definition_zh: '比喻好上加好。', definition_en: 'To make something good even better.',
      example_zh: '这份礼物真是锦上添花。', example_en: 'This gift is the icing on the cake.',
    },
  });
  const pub = await req('POST', `/admin/idioms/${created.json.id}/publish`, { token });
  check('合法成语发布成功', pub.status === 200 || pub.status === 201, `status=${pub.status}`);
  const listAfter = await req('GET', '/idioms?q=锦上添花');
  check('发布后出现在 App 列表', listAfter.json.total === 1 && listAfter.json.items[0].idiom === '锦上添花');
  await req('POST', `/admin/idioms/${created.json.id}/unpublish`, { token });
  await req('DELETE', `/admin/idioms/${created.json.id}`, { token });
  await req('DELETE', `/admin/idioms/${missing.json.id}`, { token });
  await req('DELETE', `/admin/idioms/${badPinyin.json.id}`, { token });
  const listBack = await req('GET', '/idioms?page=1&pageSize=200');
  check('下架+删除后 App 列表恢复 30 条', listBack.json.total === 30, `total=${listBack.json?.total}`);

  // ---------- 订阅 verify（dev 模式伪造 JWS） ----------
  const now = Date.now();
  const payload = {
    transactionId: 'tx-test-1001',
    originalTransactionId: 'orig-test-1001',
    productId: 'com.dailyidiom.yearly',
    bundleId: 'com.dailyidiom.app',
    type: 'Auto-Renewable Subscription',
    expiresDate: now + 30 * 86400000,
    environment: 'Sandbox',
  };
  const verify = await req('POST', '/subscription/verify', { body: { jws: fakeJws(payload) } });
  check('伪造 JWS（dev 模式）verify 开通权益',
    verify.status === 200 || verify.status === 201,
    `status=${verify.status} body=${verify.text.slice(0, 120)}`);
  check('verify 返回 active 且 entitled=true', verify.json?.status === 'active' && verify.json?.entitled === true);

  const st = await req('GET', '/subscription/status?originalTransactionId=orig-test-1001');
  check('subscription/status 查询到有效权益', st.json?.entitled === true && st.json?.status === 'active');

  const detailUnlocked = await req('GET', `/idioms/${lockedItem.id}`, {
    headers: { 'x-original-transaction-id': 'orig-test-1001' },
  });
  check('开通权益后付费详情可读', detailUnlocked.status === 200 && !!detailUnlocked.json.definition_zh);
  const listUnlocked = await req('GET', '/idioms?page=1&pageSize=200', {
    headers: { 'x-original-transaction-id': 'orig-test-1001' },
  });
  check('开通权益后列表全部解锁', listUnlocked.json.items.every((i) => i.locked === false));

  // ---------- 苹果通知：REFUND 后权益失效 ----------
  const notifPayload = {
    notificationType: 'REFUND',
    data: { signedTransactionInfo: fakeJws(payload) },
  };
  const notif = await req('POST', '/apple/notifications', { body: { signedPayload: fakeJws(notifPayload) } });
  check('REFUND 通知处理成功', notif.status === 200 || notif.status === 201, `status=${notif.status}`);
  const stAfterRefund = await req('GET', '/subscription/status?originalTransactionId=orig-test-1001');
  check('退款后权益失效', stAfterRefund.json?.entitled === false && stAfterRefund.json?.status === 'refunded',
    `status=${stAfterRefund.json?.status}`);

  // ---------- today 参数决定当日免费成语 ----------
  // 用固定日期 2026-10-21（公式测试日的次日）验证，不依赖真实当天日期
  const dateT = '2026-10-21';
  const daysT = Math.floor((Date.UTC(2026, 9, 21) - Date.UTC(2026, 0, 1)) / 86400000);
  const expectedT = bySort[daysT % bySort.length];
  const listT = await req('GET', `/idioms?page=1&pageSize=200&today=${dateT}`);
  const unlockedT = listT.json.items.filter((i) => i.locked === false);
  check('today 参数切换当日免费成语',
    unlockedT.length === 1 && unlockedT[0].id === expectedT.id,
    `expected=${expectedT.idiom} got=${unlockedT[0]?.idiom}`);

  // ---------- free_count 变更不再影响锁定 ----------
  const putCfg = await req('PUT', '/admin/config', { token, body: { free_count: 25 } });
  check('后台修改 free_count=25 成功', (putCfg.status === 200) && putCfg.json.free_count === 25);
  const list25 = await req('GET', '/idioms?page=1&pageSize=200');
  const unlocked25 = list25.json.items.filter((i) => i.locked === false);
  check('free_count 变更不影响锁定（仍仅当日成语解锁）',
    unlocked25.length === 1 && unlocked25[0].id === dailyToday.json.id);
  const cfgAfter = await req('GET', '/config');
  check('free_count 变更后 content_version 自增', cfgAfter.json.content_version > version0,
    `${version0} -> ${cfgAfter.json.content_version}`);
  await req('PUT', '/admin/config', { token, body: { free_count: 20 } });

  // ---------- 批量导入错误行报告 ----------
  const csv = [
    'sort_order,idiom,pinyin,pinyin_chars,definition_zh,definition_en,example_zh,example_en,status',
    '41,一鸣惊人,yī míng jīng rén,yī míng jīng rén,比喻平时没有突出的表现，一下子做出惊人的成绩。,To amaze the world with a single feat.,他平时沉默寡言，比赛时一鸣惊人。,He is usually quiet, but amazed everyone in the competition.,draft',
    '42,缺少英文甲,quē shǎo yīng wén,quē shǎo yīng wén,测试释义,,这是缺少英文甲的例句。,Test sentence.,draft',
    '43,拼音短少甲,pīn yīn duǎn,pīn yīn duǎn,测试释义,Test definition,这是拼音短少甲的例句。,Test sentence.,draft',
    '44,画蛇添足,huà shé tiān zú,huà shé tiān zú,重复条目,Dup entry,画蛇添足的例句。,Test sentence.,draft',
  ].join('\n');
  const form = new FormData();
  form.append('file', new Blob([csv], { type: 'text/csv' }), 'import-test.csv');
  const imp = await req('POST', '/admin/idioms/import', { token, form });
  check('导入接口成功返回报告', imp.status === 200 || imp.status === 201, `status=${imp.status} ${imp.text.slice(0, 100)}`);
  check('导入成功数 = 1', imp.json?.success === 1, `success=${imp.json?.success}`);
  const failedRows = (imp.json?.failed || []).map((f) => f.row).sort((a, b) => a - b);
  check('导入失败行号为 3、4、5', JSON.stringify(failedRows) === '[3,4,5]', `rows=${JSON.stringify(failedRows)}`);
  check('导入失败原因齐全', (imp.json?.failed || []).every((f) => !!f.reason));
  const imported = await req('GET', '/admin/idioms?q=一鸣惊人', { token });
  check('导入成功的成语以 draft 入库',
    imported.json.total === 1 && imported.json.items[0].status === 'draft');
  if (imported.json.total === 1) await req('DELETE', `/admin/idioms/${imported.json.items[0].id}`, { token });

  // ---------- 后台轮换预览 ----------
  const preview = await req('GET', '/admin/daily/preview?days=14', { token });
  check('后台轮换预览返回 14 天', preview.status === 200 && preview.json.items?.length === 14);

  const failed = results.filter((r) => !r.pass);
  console.log(`\n===== 测试汇总：${results.length - failed.length}/${results.length} 通过 =====`);
  if (failed.length) {
    console.log('失败项：');
    failed.forEach((f) => console.log(' - ' + f.name));
    process.exit(1);
  }
}

main().catch((e) => {
  console.error('测试运行异常：', e);
  process.exit(2);
});
