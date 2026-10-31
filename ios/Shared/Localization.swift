import Foundation

/// App 界面语言：只看系统首选语言，以 "zh" 开头（简体、繁体都算中文）显示中文，其他一律英文。
/// 实现方式是代码查表（与 Glow Selfie 的 L() 同一套思路）：界面文案在代码里仍以英文原文写，
/// 显示时过一遍 L()，中文时查表换成中文，英文时直接返回原文。这样不用改 Xcode 工程的
/// .lproj，也不用为每句文案建 strings 文件。
/// 边界：成语、拼音、释义、例句、故事等内容本身就是中英双语，不受 L() 影响；
/// 分享卡是特意做成英文的对外图片（代码注释有说明），也不跟随系统语言。
enum AppLanguage {
    static var isChinese: Bool {
        let first = Locale.preferredLanguages.first ?? "en"
        return first.hasPrefix("zh")
    }

    static var isEnglish: Bool { !isChinese }

    /// 展示用日期 Locale：中文时用中文格式，英文时用美式格式。计算用的 POSIX 格式不动。
    static var displayLocale: Locale {
        isChinese ? Locale(identifier: "zh_Hans") : Locale(identifier: "en_US")
    }

    /// 打卡日历星期头：中文 日一二三四五六，英文 S M T W T F S。
    static var weekdayHeaders: [String] {
        isChinese ? ["日", "一", "二", "三", "四", "五", "六"] : ["S", "M", "T", "W", "T", "F", "S"]
    }
}

/// 查表：英文原文 -> 中文。英文时直接返回原文；中文时查不到的也返回原文兜底，
/// 不会因为漏一条就显示空白。带数字的文案用模板（模板里留 %@ / %d），
/// 各处用 String(format: L(...), ...) 把数字填进去。
func L(_ en: String) -> String {
    guard AppLanguage.isChinese else { return en }
    return zhStrings[en] ?? en
}

private let zhStrings: [String: String] = [
    // MARK: - 通用弹窗 / 按钮
    "Notice": "提示",
    "OK": "好",
    "Close": "关闭",
    "Retry": "重试",
    "Later": "稍后",
    "Cancel anytime": "随时可取消",

    // MARK: - 强制更新
    "Update Required": "需要更新",
    "This version is too old to continue. Please update to the latest version.": "这个版本太旧，无法继续使用。请更新到最新版本。",
    "Update on the App Store": "去 App Store 更新",

    // MARK: - 首页 LearnView
    "Loading idioms…": "正在加载成语…",
    "Loading today's idiom…": "正在加载今日成语…",
    "No content yet": "暂无内容",
    "Profile": "个人中心",
    "Start your streak today": "今天就开始连续打卡",
    "Swipe to explore more idioms": "滑动查看更多成语",
    "Today's idiom isn't available offline yet": "今日成语暂无离线内容",
    "Connect to the internet and reopen the app to load today's free idiom.": "联网后重新打开 App，即可加载今日免费成语。",
    "%d-day streak": "连续打卡 %d 天",

    // MARK: - 全部成语列表
    "All Idioms": "全部成语",
    "No idioms found": "没有找到成语",
    "Check your spelling or try another keyword.\nYou can also search by pinyin, e.g. shou zhu": "检查一下拼写，或换个关键词试试。\n也可以按拼音搜索，例如 shou zhu",
    "Clear Search": "清除搜索",
    "Search idioms or pinyin…": "搜索成语或拼音…",
    "NEW": "新",
    "TODAY": "今日",

    // MARK: - 成语详情 / 锁定页
    "Subscribe to Unlock All Idioms": "订阅解锁全部成语",
    "Subscribers Only": "仅订阅用户",

    // MARK: - 订阅页
    "Subscribe": "订阅",
    "Unlock ": "解锁",
    "One idiom a day adds up.": "每天一个成语，积少成多。",
    "Subscribe to access the full idiom library, including every new idiom we add.": "订阅后可畅读全部成语库，包括今后新增的每一个成语。",
    "No subscription? No problem — you can still enjoy one free idiom every day on the Home page. It changes daily.": "不订阅也没关系，每天都可以在首页免费看一个成语，而且每天都会换。",
    "Idioms to learn": "可学成语",
    "Full example sentences": "完整例句",
    "New idioms as they're added": "新增成语",
    "Free": "免费",
    "Premium": "高级版",
    "1 per day": "每天 1 个",
    "All": "全部",
    "Today's idiom": "今日成语",
    "Unlocked automatically": "自动解锁",
    "Loading plans…": "正在加载套餐…",
    "Yearly": "年订阅",
    "Monthly": "月订阅",
    "/ year": "/年",
    "/ month": "/月",
    "Best Value": "最划算",
    "About %@/month": "约 %@/月",
    "Subscribe Now": "立即订阅",
    "Start Free Trial": "开始免费试用",
    "Restore Purchases": "恢复购买",
    "Redeem Code": "兑换码",
    "Privacy Policy": "隐私政策",
    "Terms of Use": "使用条款",
    "Payment will be charged to your Apple ID at confirmation of purchase. Your subscription automatically renews unless canceled at least 24 hours before the end of the current period, and your account will be charged for renewal within 24 hours prior to that. You can manage or cancel your subscription anytime in your App Store account settings.": "购买确认后，费用将从你的 Apple ID 扣除。订阅会自动续订，除非在当前周期结束前至少 24 小时取消；续订费用会在周期结束前 24 小时内扣除。你可以随时在 App Store 账号设置中管理或取消订阅。",

    // MARK: - 设置页
    "ABOUT": "关于",
    "HOME SCREEN": "主屏幕",
    "LEARNING": "学习",
    "SUBSCRIPTION": "订阅",
    "About Daily Chengyu": "关于每日成语",
    "Add Widget to Home Screen": "添加小组件到主屏幕",
    "Check-in Calendar": "打卡日历",
    "Contact Us": "联系我们",
    "Daily Chengyu · Version %@": "每日成语 · 版本 %@",
    "Manage Subscription": "管理订阅",
    "My Subscription": "我的订阅",
    "Not Subscribed · Subscribe": "未订阅 · 去订阅",
    "Restoring…": "正在恢复…",
    "Review": "复习",
    "Subscribed": "已订阅",
    "Subscribed · Expires %@": "已订阅 · %@ 到期",
    "Achievements": "成就",
    "Leaderboard": "排行榜",
    "%d days": "%d 天",

    // MARK: - 关于页
    "About": "关于",
    "Daily Chengyu brings you one Chinese idiom (chengyu) every day. Each idiom comes with character-by-character pinyin, meanings in English and Chinese, and a bilingual example sentence.": "每日成语每天为你带来一个汉语成语。每个成语都有逐字拼音、中英释义和一句中英对照例句。",
    "New idioms are added regularly. Free users enjoy one idiom a day; a subscription unlocks the full collection.": "成语会定期新增。免费用户每天可看一个成语；订阅后解锁全部内容。",
    "Our logo tells the story of The Old Man Who Moved the Mountains (愚公移山): a tiny figure, a huge mountain, and progress made one basket at a time. That is exactly how we hope you learn — one idiom a day, every day.": "我们的图标讲的是愚公移山的故事：一个小小的人、一座巨大的山、一点一点搬走的土石。这正是我们希望你学习的样子——每天一个成语，天天如此。",
    "Test yourself with three levels of quizzes, from everyday meanings to fill-in-the-blank challenges, and share beautiful idiom cards with friends.": "三档测验等你挑战，从日常释义到挖空填空，还可以把精美的成语卡片分享给朋友。",
    "Questions or feedback: %@": "问题或反馈：%@",
    "Version %@": "版本 %@",

    // MARK: - 成就
    "Achievements sync with Game Center and follow your Apple ID across devices. Progress is tracked locally first, so it never gets lost when offline.": "成就与 Game Center 同步，跟随你的 Apple ID 跨设备。进度先记在本地，离线也不会丢。",
    "%d of %d unlocked": "%d/%d 已解锁",

    // MARK: - 排行榜
    "All time": "全部时间",
    "This week": "本周",
    "Check-in days": "打卡天数",
    "Longest streak": "最长连续",
    "Quiz best": "测验最佳",
    "No scores yet — be the first on this board!": "还没有成绩，快来当这个榜的第一名！",
    "Sign in to Game Center to see the global leaderboard and rank against other players.": "登录 Game Center 查看全球排行榜，与其他玩家一较高下。",
    "Sign in to Game Center": "登录 Game Center",
    "Sorted by best single-round quiz score, highest first": "按单局测验最高分排序，从高到低",
    "Sorted by longest endless streak, highest first": "按连答最长纪录排序，从高到低",
    "Sorted by total check-in days, highest first": "按累计打卡天数排序，从高到低",
    " · ties go to whoever reached it first · your best score only": " · 并列时先达到者排在前面 · 只记你的最好成绩",
    "View in Game Center ↗": "在 Game Center 中查看 ↗",
    "Your best on this board: %@": "你在这个榜的最好成绩：%@",
    "%d players on this board": "这个榜共有 %d 位玩家",

    // MARK: - 打卡日历
    "Check-in": "打卡",
    "day streak": "连续打卡",
    "total days": "累计天数",
    "idioms learned": "已学成语",
    "Checked days are marked red. A missed day breaks the streak — there is no make-up in this version.": "打卡的日子标为红色。断签一天，连续天数就会重新计算，本版本没有补签。",
    "Open in Home →": "在首页打开 →",
    "This idiom is locked — subscribe to read it.": "这个成语已锁定，订阅后可阅读。",

    // MARK: - 测验
    "Back to Home": "返回首页",
    "Best: %@": "最佳：%@",
    "Chengyu Quiz": "成语测验",
    "Choose a difficulty to start": "选个难度开始吧",
    "Fill in the blank with the correct idiom": "选正确的成语填空",
    "Look at the story image, pick the idiom · Regular 10 / Endless": "看故事图，选成语 · 常规 10 题 / 连答",
    "More games": "更多游戏",
    "New Record!": "新纪录！",
    "Next": "下一题",
    "Not Enough Content Yet": "内容还不够",
    "Picture Guess": "看图猜",
    "See Results": "查看结果",
    "Share My Score": "分享我的成绩",
    "Subscribe to unlock all idioms and a bigger question bank": "订阅解锁全部成语和更大题库",
    "There aren't enough idioms available for a quiz yet. Please try again once content has finished syncing.": "可出题的成语还不够，等内容同步完成后再试。",
    "Try Again": "再试一次",
    "Which idiom does this English definition describe?": "哪个成语符合这条英文释义？",
    "%@ (Not enough questions)": "%@（题目不够）",
    "%d/%d correct · %ds": "%d/%d 答对 · 用时 %d 秒",
    "%d questions per round, with your score at the end": "每轮 %d 道题，最后出分",
    "Easy": "简单",
    "Medium": "中等",
    "Hard": "困难",
    "Read the idiom, choose the English meaning": "看成语，选英文释义",
    "Read the English meaning, choose the idiom": "看英文释义，选成语",
    "Read the Chinese example, choose the idiom": "看中文例句，选成语",

    // MARK: - 看图猜
    "Back to Games": "返回游戏",
    "Best: %@/10": "最佳：%@/10",
    "Not Enough Pictures Yet": "图片还不够",
    "Image unavailable": "图片暂不可用",
    "Loading image…": "正在加载图片…",
    "Look at the story image, pick the idiom": "看故事图，选成语",
    "PICTURE GUESS": "看图猜",
    "Picture pool: %d illustrated idioms · wrong answers go to your mistake book": "题库：%d 个有图成语 · 答错的会记入错题本",
    "Play Again": "再玩一次",
    "Review your misses (%d)": "复习错题（%d）",
    "Story →": "故事 →",
    "Streak %d": "连对 %d",
    "Subscribe to unlock all 114 illustrated idioms": "订阅解锁全部 114 个有图成语",
    "There aren't enough illustrated idioms available yet. Please try again once content has finished syncing.": "有图成语还不够，等内容同步完成后再试。",
    "View Story": "查看故事",
    "Which idiom does this picture tell?": "这张图讲的是哪个成语？",
    "correct · %ds": "答对 · 用时 %d 秒",
    "correct": "答对",
    "longest streak · %d correct · %ds": "最长连对 · 答对 %d 题 · 用时 %d 秒",
    "longest streak": "最长连对",
    "Regular": "常规",
    "Endless": "连答",
    "10 questions, picture prompts": "10 道题，看图出题",
    "Answer until one miss — your streak is your score": "答错即止，连对数就是你的分数",

    // MARK: - 复习
    "Back to Review": "返回复习",
    "Due today": "今日待复习",
    "End": "结束",
    "Got It": "掌握了",
    "How review works: see the idiom → recall it → tap to reveal the meaning → “Got it” moves it to a later round, “Still learning” brings it back tomorrow.": "复习方法：先看成语 → 回忆意思 → 点一下显示释义 → 点“掌握了”推到更晚的轮次，点“还没掌握”明天再来。",
    "Idiom": "成语",
    "Missed %d× · last missed %@": "错 %d 次 · 上次错在 %@",
    "Mistake book (%d)": "错题本（%d）",
    "Mistakes first, then due reviews · 1 / 3 / 7-day rotation": "错题优先，再按到期复习 · 1 / 3 / 7 天轮换",
    "No mistakes yet — keep playing and anything you miss will land here.": "还没有错题，继续玩，错过的都会记到这里。",
    "Nothing Due Today 🎉": "今天没有待复习 🎉",
    "Reveal Meaning": "显示释义",
    "Review Complete 🎉": "复习完成 🎉",
    "Review %d/%d": "复习 %d/%d",
    "Start Review": "开始复习",
    "Still Learning": "还没掌握",
    "%d idioms": "%d 个成语",
    "%d of %d mastered this round": "本轮掌握了 %d/%d 个",

    // MARK: - 新增提醒 / 小组件提示
    "New Idioms Are Here": "新成语来了",
    "Take a Look": "去看看",
    "NEW ARRIVALS": "新到成语",
    "%d new idioms have been added to your collection. Come and meet them.": "你的成语库新增了 %d 个成语，快来认识它们。",
    "+ %d more in All Idioms": "全部成语里还有 %d 个",
    "Add the Daily Widget": "添加每日小组件",
    "See today's idiom right on your Home Screen — no need to open the app.": "不用打开 App，在主屏幕上就能看到今日成语。",
    "See How": "看看怎么加",
    "Not Now": "以后再说",

    // MARK: - 小组件引导
    "Add the Widget": "添加小组件",
    "Touch and hold the Home Screen": "长按主屏幕",
    "Touch and hold an empty area on your Home Screen until the app icons start to jiggle.": "长按主屏幕空白处，直到图标开始抖动。",
    "Scroll down the widget list, find \"Daily Chengyu\", and tap it.": "在小组件列表里找到“Daily Chengyu”，点它。",
    "Swipe to the medium size, tap \"Add Widget\", then tap \"Done\". A new idiom will be waiting on your Home Screen every day.": "滑动到中等尺寸，点“添加小组件”，再点“完成”。每天都会有一个新成语等在主屏幕上。",
    "Choose the medium size and add it": "选中号尺寸并添加",
    "Tap the \"+\" button": "点左上角的“+”按钮",

    // MARK: - 启动页
    "One idiom a day, wisdom for a lifetime.": "每天一个成语，受用一生。",

    // MARK: - 订阅状态 / 购买提示
    "No subscription found to restore.": "没有找到可恢复的订阅。",
    "Purchase cancelled.": "购买已取消。",
    "Purchase complete. Your access is being confirmed — just a moment.": "购买完成，正在确认你的权益，稍等片刻。",
    "Purchase didn't go through. Please try again later.": "购买没有成功，请稍后再试。",
    "Purchase failed: %@": "购买失败：%@",
    "Purchase pending: your idioms will unlock automatically once it's approved.": "购买待处理，批准后成语会自动解锁。",
    "Restore failed: %@": "恢复失败：%@",
    "Subscribed! All idioms are now unlocked.": "订阅成功！全部成语已解锁。",
    "Your subscription has been restored.": "订阅已恢复。",
    "Couldn't load content. Check your connection and try again.": "加载内容失败，请检查网络后重试。",
    "You're offline. Showing cached content.": "你当前离线，正在显示缓存内容。",

    // MARK: - 小组件
    "A new Chinese idiom every day": "每天一个新成语",
]
