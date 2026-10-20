# 每日成语后端（NestJS + TypeScript + Prisma）

本地运行、切换 PostgreSQL、苹果校验模式等说明见项目根目录 `../README.md`。

目录：

- `src/main.ts` 入口（全局前缀 /api/v1）
- `src/auth/` 管理员登录与 JWT 守卫
- `src/idioms/` 后台成语管理（CRUD、发布校验、CSV 导入）与字段视图工具
- `src/app-api/` App 端接口（列表/详情/每日）与后台轮换预览
- `src/config/` 参数配置与 content_version 管理
- `src/subscription/` 订阅校验、权益状态、苹果通知、权益判定工具
- `src/common/` CSV 解析、每日轮换纯函数
- `prisma/schema.prisma` 生产 schema（PostgreSQL）
- `prisma/schema.local.prisma` 本地 schema（SQLite，仅 provider 不同）
- `prisma/seed.mjs` 种子脚本
- `prisma/content-30.csv` 开发阶段 30 个成语内容
- `test/api.test.mjs` API 测试脚本（39 项）
