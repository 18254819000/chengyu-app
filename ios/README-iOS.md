# 每日成语 iOS App + 小组件 — Mac 跑通指南

工程：`DailyIdiom.xcodeproj`（手写工程文件，Xcode 15 / 16 均可打开）
Target：`DailyIdiom`（App，com.mengma.dailyidiom）+ `DailyIdiomWidget`（Widget Extension，com.mengma.dailyidiom.widget，已 Embed 进 App）
最低系统：iOS 15.0；Swift 5；SwiftUI + StoreKit 2。

> ⚠️ 本工程在 Linux 环境下编写，未经 Xcode 编译验证。首次在 Mac 上打开时如有个别报错，按文末排查表处理，多为小问题。

---

## 1. 打开工程与签名设置

1. 用 Xcode 打开 `ios/DailyIdiom.xcodeproj`。
2. 选中项目根节点 → Target `DailyIdiom` → Signing & Capabilities：
   - Team：选你的开发者团队（付费开发者账号）。
   - Bundle Identifier 应为 `com.mengma.dailyidiom`。
   - Capabilities 里应能看到 **App Groups**，且勾选了 `group.com.mengma.dailyidiom`（由 `DailyIdiom/DailyIdiom.entitlements` 提供）。若报 App Group 不可用，去开发者后台为该 App ID 启用 App Groups 并勾选同名分组，或让 Xcode 自动创建同名分组（名字必须一致，代码里写死的是这个值）。
3. Target `DailyIdiomWidget` 同样设置 Team，Bundle Identifier 应为 `com.mengma.dailyidiom.widget`，App Groups 同上（`DailyIdiomWidget/DailyIdiomWidget.entitlements`）。
4. 两个 Target 的 Bundle ID 若与你账号里已注册的 App ID 不同，可改 ID，但 **App Group 名、URL Scheme（dailyidiom）不要改**；如需改 App Group，必须同步改 `Shared/AppConfig.swift` 的 `appGroupID` 与两份 entitlements。

## 2. 先启动后端（App 依赖它取数据）

在项目根目录（`chengyu-app/`）另开终端，按根目录 `README.md` 的本地步骤启动后端，监听 3000 端口：

```bash
cd backend
npm install
npx prisma generate --schema prisma/schema.local.prisma
npx prisma db push --schema prisma/schema.local.prisma
node prisma/seed.mjs
npm run build && npm start
```

种子数据含 30 个已发布成语（前 20 免费）与默认配置。可用浏览器打开 `http://localhost:3000/api/v1/config` 验证后端已起来。

## 3. 运行 App

- API 地址在 `Shared/AppConfig.swift` 的 `apiBaseURL` 集中配置，默认 `http://localhost:3000`：
  - **模拟器**：直接用 localhost，无需改动（工程 Info.plist 已配 ATS 本地网络放行 `NSAllowsLocalNetworking`）。
  - **真机**：把 `apiBaseURL` 改成开发机局域网 IP，如 `http://192.168.1.10:3000`（手机与 Mac 需同一 Wi-Fi）。
  - **上线**：改成正式 HTTPS 域名。
- Xcode 里选模拟器或真机，Run `DailyIdiom`。
- 首次启动应落在当日每日成语详情页；左右滑切换；齿轮与「我的」进同一设置页；「全部」里可搜索。

## 4. 添加桌面小组件

1. 运行过一次 App（让它把未来 7 天数据写进 App Group 共享存储）后，回到桌面。
2. 长按桌面空白处 → 左上角「+」→ 找到「每日成语」→ 选 **大尺寸**（本 App 只提供大尺寸）→ 添加小组件。
3. 组件只展示成语大字 + 中文解释 + 英文解释；点组件任意处会打开 App 并直达该成语详情页。
4. 组件数据来源优先级：App 写入的共享缓存 → 组件直连后端 `/daily/week` → 内置兜底（画蛇添足）。本地联调时若后端没开，组件会退到缓存或兜底，不会空白。

## 5. 在 App Store Connect 建订阅商品（沙盒测试）

1. 在 App Store Connect 为 App（Bundle ID `com.mengma.dailyidiom`）创建 **订阅组**，组内建两个 **自动续期订阅**：
   - 月订阅：商品 ID `com.mengma.dailyidiom.monthly`，价格档位选 $9.99。
   - 年订阅：商品 ID `com.mengma.dailyidiom.yearly`，价格档位选 $99.00。
2. 分别为两个商品添加 **介绍性优惠 - 免费试用**（暂定：年 7 天 / 月 3 天，最终时长以确认为准）。
3. 商品 ID 也可以自定义，但必须与后台「参数配置」里的月/年商品 ID 保持一致；后台未配置时，App 用上面这两个默认 ID。改了商品 ID 后，在管理后台参数配置页填上新值即可，App 下次同步自动生效。
4. 沙盒测试：真机在「设置 → 开发者 → 沙盒 Apple ID」登录沙盒账号（或 Xcode 运行自动用沙盒），在 App 内点锁定成语 → 订阅页购买。沙盒订阅会快速续期，便于测到期/续费。
5. 购买成功后 App 会把交易 JWS 提交后端 `POST /api/v1/subscription/verify`。注意：后端未配齐苹果环境变量时走 **dev 解码模式**（不验签，仅联调用）；上线前必须按根 README 配齐 `APPLE_BUNDLE_ID / APPLE_KEY_ID / APPLE_ISSUER_ID / APPLE_PRIVATE_KEY / APPLE_APP_ID` 走生产校验，并把 App Store Server Notifications 回调地址配为 `https://正式域名/api/v1/apple/notifications`。
6. 「恢复购买」在订阅页与设置页都有入口；换设备/重装后点它即可找回权益。

## 6. 上线前要替换的占位项（`Shared/AppConfig.swift`）

| 项 | 当前占位 | 说明 |
| --- | --- | --- |
| `apiBaseURL` | `http://localhost:3000` | 改正式 HTTPS 域名 |
| `privacyPolicyURL` | `https://example.com/dailyidiom/privacy` | 改正式隐私政策公开页（审核强制要求） |
| `termsOfUseURL` | `https://example.com/dailyidiom/terms` | 改正式用户协议公开页 |
| `supportEmail` | `support@example.com` | 改正式客服邮箱 |

App 图标：`DailyIdiom/Assets.xcassets/AppIcon.appiconset` 目前只有尺寸槽位、无图片文件，需放入正式图标（至少 1024×1024 营销图标），否则提审会被拒、本地运行会给警告。

## 7. 已知未验证项

- **未在本机编译**：开发环境是 Linux、无 Xcode。全部 Swift 代码经过人工语法复核（括号配平、字段与后端接口对齐、只用 iOS 15 可用 API，未用 NavigationStack），工程文件经脚本校验（每个文件引用都能在磁盘找到、两个 Target 的 Sources/Frameworks/Embed 关系完整）。但「人工复核」不等于「编译通过」，首次构建请预留少量修错时间。
- StoreKit 沙盒全链路（购买 → verify → 权益解锁 → 退款回收）未实测，需按第 5 节在 Mac + 真机/模拟器上走通。
- 小组件在 iOS 15 真机上的添加、跨天刷新未实测。

## 8. 首编可能遇到的小问题排查表

| 现象 | 可能原因与处理 |
| --- | --- |
| 打开工程提示缺少文件（红色文件名） | 文件引用是相对工程目录的路径；确认整个 `ios/` 目录完整拷贝，不要只拷 `.xcodeproj` |
| 签名失败 / App Group 报错 | 两个 Target 的 Team 未选或不一致；在开发者后台确认 App Group `group.com.mengma.dailyidiom` 已创建并分配给两个 App ID |
| 小组件添加列表里找不到 | 先运行一次 App Target（组件是 Embed 的扩展），确认 Scheme 选的是 DailyIdiom 而非 DailyIdiomWidget 单独运行 |
| App 打开是空白 / 一直加载失败 | 后端没启动或地址不对：先确认 `http://localhost:3000/api/v1/config` 在 Mac 浏览器可达；真机改用局域网 IP 并确认同一 Wi-Fi |
| 小组件一直显示「画蛇添足」 | 这是内置兜底：说明共享缓存为空且组件连不上后端。先打开一次 App 让它同步并写共享数据，确认 App Group 配置正确 |
| 订阅页没有商品 / 一直加载中 | App Store Connect 商品未建、商品 ID 与后台配置不一致、或未签付费协议；沙盒环境下还要等商品状态生效（新建后可能需数分钟） |
| 购买成功但未解锁 | 后端 verify 未通：看后端日志（dev 模式会有提示）；检查手机时间、后端 3000 端口可达性 |
| 点小组件没进 App / 进错页 | 确认 App 的 Info.plist 里 URL Scheme 为 `dailyidiom`（工程已配）；深链接格式 `dailyidiom://idiom/{id}` |
| Swift 并发相关黄色警告（如 Sendable） | Swift 5 模式下多为警告不影响运行；若开了 Swift 6 语言模式会变错误——工程已设 `SWIFT_VERSION = 5.0`，不要改 |
| 报错指向某个 View 的类型推断超时（type-check 慢） | 多为个别复杂表达式导致；可先将对应 `body` 拆为子 View 临时绕过，并把报错文件与行号记录下来反馈定位 |

## 9. 工程结构速览

```
ios/
├── DailyIdiom.xcodeproj/          工程文件（App + Widget 两 Target）
├── DailyIdiom/                    App 源码
│   ├── DailyIdiomApp.swift        入口
│   ├── Views/                     根视图 / 学习页 / 翻页容器 / 详情与锁定页 / 全部列表 / 订阅页 / 设置页 / 组件引导
│   ├── State/                     AppState（同步、落点、新增提醒）/ StoreManager（StoreKit 2）
│   ├── Services/                  LocalStore（本地缓存与位置）
│   ├── Assets.xcassets/           图标槽位与主题色
│   ├── Info.plist                 URL Scheme dailyidiom + ATS 本地网络
│   └── DailyIdiom.entitlements    App Group
├── Shared/                        App 与 Widget 共用源码（加入两个 Target）
│   ├── AppConfig.swift            地址、商品 ID、链接等集中配置
│   ├── Models.swift               与后端契约对齐的 Codable 模型
│   ├── APIClient.swift            接口客户端（自动带权益请求头）
│   ├── SharedStore.swift          App Group 共享存储
│   ├── DateUtil.swift             日期与轮换公式（与后端一致）
│   └── Theme.swift                视觉 token（纸面 / 墨色 / 朱红）
└── DailyIdiomWidget/              小组件源码（仅大尺寸）+ Info.plist + entitlements
```
