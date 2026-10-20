# 每日成语 — 后端与管理后台

项目结构：`backend/`（NestJS + Prisma API)+ `admin/`（Vue 3 管理后台）。需求口径见 `~/workspace/your_files/chengyu-ios-app-requirements-v8.md`，技术方案见 `chengyu-tech-solution-v3.md`。

## 本地运行（SQLite，无需装数据库）

后端：

```bash
cd backend
npm install
# 若 Prisma 引擎下载失败（网络原因），用镜像重试：
# PRISMA_ENGINES_MIRROR=https://registry.npmmirror.com/-/binary/prisma npm install
npx prisma generate --schema prisma/schema.local.prisma   # 生成本地客户端
npx prisma db push --schema prisma/schema.local.prisma     # 建表（SQLite 文件 prisma/dev.db）
node prisma/seed.mjs                                       # 种子：管理员 + 30 个成语（全部发布）+ 默认配置
npm run build && npm start                                 # 启动，监听 3000，接口前缀 /api/v1
```

管理后台：

```bash
cd admin
npm install
npm run dev    # http://localhost:5173，已代理 /api 到后端 3000
npm run build  # 生产构建，产物在 admin/dist/
```

登录：用户名 `admin`，密码取后端环境变量 `ADMIN_PASSWORD`，默认 `admin123`。
**上线前必须修改 `ADMIN_PASSWORD` 与 `JWT_SECRET`**（见 backend/.env）。

测试（需先按上面步骤启动后端）：

```bash
cd backend && node test/api.test.mjs
```

## 切换到生产 PostgreSQL

1. 准备 PostgreSQL，设置 `DATABASE_URL="postgresql://用户:密码@主机:5432/库名?schema=public"`。
2. 生成生产客户端并建表（或走迁移）：
   ```bash
   npx prisma generate --schema prisma/schema.prisma
   npx prisma migrate dev --schema prisma/schema.prisma   # 或 db push
   node prisma/seed.mjs
   npm run build && npm start
   ```
   两份 schema 只有 datasource provider 不同（生产 `schema.prisma` = postgresql，本地 `schema.local.prisma` = sqlite），模型字段完全一致，且全部为标量类型（`pinyin_chars` 存空格分隔字符串、`tags` 存普通字符串），可直接切换。
3. 设置强 `ADMIN_PASSWORD`、`JWT_SECRET`，并配齐苹果参数（下节）才走生产校验。

## 苹果订阅校验（两种模式）

- 环境变量 `APPLE_BUNDLE_ID / APPLE_KEY_ID / APPLE_ISSUER_ID / APPLE_PRIVATE_KEY / APPLE_APP_ID` **全部配齐** → 生产模式：用官方 `@apple/app-store-server-library` 向苹果服务器按 transactionId 查询交易并解码，作为权威数据落档。
- 未配齐 → **dev-only 模式**：仅 base64 解码 JWS payload 取字段，不验签，服务日志会打印警告。仅供开发联调，生产禁用。

App Store Server Notifications 回调地址：`POST /api/v1/apple/notifications`。

## 主要接口速览（前缀 /api/v1）

| 接口 | 说明 |
| --- | --- |
| POST /admin/login | 管理员登录，返回 JWT（其余 /admin/* 均需 Bearer JWT） |
| GET/POST /admin/idioms，GET/PUT/DELETE /admin/idioms/:id | 成语管理（删除为软删除） |
| POST /admin/idioms/:id/publish \| /unpublish | 发布（严格校验）/下架 |
| POST /admin/idioms/import | CSV 批量导入，返回逐行报告 |
| GET /admin/idioms/template | 导入模板 |
| GET/PUT /admin/config | 参数配置（free_count、月/年商品 ID） |
| GET /admin/daily/preview?days=14 | 每日轮换预览 |
| GET /config | App 全局配置（含 content_version） |
| GET /idioms、GET /idioms/:id | App 成语列表/详情（付费锁定逻辑，权益请求头 x-original-transaction-id） |
| GET /daily、GET /daily/week | 每日成语（轮换纯函数）及未来 7 天 |
| POST /subscription/verify | 提交 StoreKit 2 签名交易（{ jws }）校验开通权益 |
| GET /subscription/status | 按 originalTransactionId 查权益 |
| POST /apple/notifications | 苹果服务端通知 V2 回调 |
