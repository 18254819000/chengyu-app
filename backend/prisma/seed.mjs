// 种子脚本：建管理员、导入 30 个成语（draft 后全部 publish 为开发数据）、写默认配置。
// 运行：node prisma/seed.mjs（需先 prisma generate + db push/migrate）
import { PrismaClient } from '@prisma/client';
import bcrypt from 'bcryptjs';
import { readFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const prisma = new PrismaClient();

function parseCsv(text) {
  const rows = [];
  let row = [], field = '', inQ = false;
  const s = text.replace(/^﻿/, '');
  for (let i = 0; i < s.length; i++) {
    const ch = s[i];
    if (inQ) {
      if (ch === '"') {
        if (s[i + 1] === '"') { field += '"'; i++; } else inQ = false;
      } else field += ch;
    } else if (ch === '"') inQ = true;
    else if (ch === ',') { row.push(field); field = ''; }
    else if (ch === '\n' || ch === '\r') {
      if (ch === '\r' && s[i + 1] === '\n') i++;
      row.push(field); field = '';
      if (row.length > 1 || row[0] !== '') rows.push(row);
      row = [];
    } else field += ch;
  }
  if (field !== '' || row.length) { row.push(field); if (row.length > 1 || row[0] !== '') rows.push(row); }
  return rows;
}

async function main() {
  // 1) 管理员（密码取 ADMIN_PASSWORD，默认 admin123，上线必改）
  const password = process.env.ADMIN_PASSWORD || 'admin123';
  const passwordHash = await bcrypt.hash(password, 10);
  await prisma.adminUser.upsert({
    where: { username: 'admin' },
    update: { passwordHash },
    create: { username: 'admin', passwordHash },
  });
  console.log('管理员已就绪：admin');

  // 2) 默认配置（已存在则不覆盖）
  const defaults = { free_count: '20', monthly_product_id: '', yearly_product_id: '', content_version: '1' };
  for (const [key, value] of Object.entries(defaults)) {
    await prisma.appConfig.upsert({ where: { key }, update: {}, create: { key, value } });
  }
  console.log('默认配置已就绪：free_count=20');

  // 3) 导入内容 CSV 并全部 publish（开发数据）
  // 种子 CSV：content-30.csv（原 30 条，8 列）与 content-new.csv（扩量新条，含 story 列）都读；
  // 缺 story 列的旧文件默认空字符串，不覆盖、不报错
  const seedFiles = ['content-30.csv', 'content-new.csv'].filter((f) =>
    existsSync(join(__dirname, f)),
  );
  let count = 0;
  for (const seedFile of seedFiles) {
    const rows = parseCsv(readFileSync(join(__dirname, seedFile), 'utf8'));
    const header = rows[0].map((h) => h.trim());
    const col = (n) => header.indexOf(n);
    for (let i = 1; i < rows.length; i++) {
      const r = rows[i];
      const g = (n) => (col(n) >= 0 ? (r[col(n)] ?? '').trim() : '');
      const idiom = g('idiom');
      if (!idiom) continue;
      const data = {
        idiom,
        pinyin: g('pinyin'),
        pinyinChars: g('pinyin_chars').split(/\s+/).filter(Boolean).join(' '),
        definitionZh: g('definition_zh'),
        definitionEn: g('definition_en'),
        exampleZh: g('example_zh'),
        exampleEn: g('example_en'),
        storyZh: g('story_zh'),
        storyEn: g('story_en'),
        sortOrder: parseInt(g('sort_order'), 10) || i,
        status: 'published',
        deleted: false,
      };
      // 典故空值不参与更新：避免旧 CSV（无 story 列）在每次启动重跑 seed 时
      // 把管理端已填好的典故刷回空；管理端编辑仍可正常改典故
      const update = { ...data };
      if (!data.storyZh) delete update.storyZh;
      if (!data.storyEn) delete update.storyEn;
      await prisma.idiom.upsert({
        where: { idiom },
        update,
        create: data,
      });
      count++;
    }
  }
  console.log(`成语已导入并发布：${count} 条`);

  // 4) 协议与政策初稿（仅当该 key 不存在时写入；已存在绝不覆盖管理员的后续编辑）
  const contentDir = join(__dirname, 'content');
  const pageSeeds = [
    { key: 'privacy', title: 'Privacy Policy', file: 'privacy.md' },
    { key: 'terms', title: 'Terms of Use', file: 'terms.md' },
  ];
  for (const p of pageSeeds) {
    const existing = await prisma.contentPage.findUnique({ where: { key: p.key } });
    if (!existing) {
      const content = readFileSync(join(contentDir, p.file), 'utf8');
      await prisma.contentPage.create({ data: { key: p.key, title: p.title, content } });
      console.log(`内容页初稿已写入：${p.key}`);
    }
  }
  console.log('内容页已就绪（已存在的未覆盖）');
}

main()
  .catch((e) => { console.error(e); process.exit(1); })
  .finally(() => prisma.$disconnect());
