import Foundation

/// 测试难度三档：题型不同——简单看成语选释义，中等看释义选成语，困难例句挖空选词。
enum QuizDifficulty: String, CaseIterable, Identifiable {
    case easy
    case medium
    case hard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .easy: return "简单"
        case .medium: return "中等"
        case .hard: return "困难"
        }
    }

    var subtitle: String {
        switch self {
        case .easy: return "看成语，选释义"
        case .medium: return "看释义，选成语"
        case .hard: return "例句挖空，选成语"
        }
    }

    /// 成绩卡 / 难度标签文案，如「中等难度」
    var tagText: String { title + "难度" }
}

/// 一道题：subject 是被考的成语；promptText 为题面文字（中等 = 中文释义，困难 = 挖空后的例句），
/// 简单档题面直接用 subject 渲染（成语 + 逐字拼音），promptText 为 nil。
struct QuizQuestion: Identifiable {
    let id = UUID()
    let subject: Idiom
    let promptText: String?
    let options: [String]
    let answer: String
}

/// 出题与答题状态机：一轮内题目 / 选项均打乱、同成语不重复；计时从开轮（第一题出现）起算。
/// 成绩只写 LocalStore 本地记录，本期不上传服务器、不做排行榜（见 LocalStore 注释）。
@MainActor
final class QuizEngine: ObservableObject {
    enum Phase {
        case selecting
        case playing
        case finished
    }

    @Published private(set) var phase: Phase = .selecting
    @Published private(set) var difficulty: QuizDifficulty = .easy
    @Published private(set) var questions: [QuizQuestion] = []
    @Published private(set) var currentIndex = 0
    /// 本题已选选项（nil = 尚未作答，作答后锁定并出对错反馈）
    @Published private(set) var selectedOption: String?
    @Published private(set) var correctCount = 0
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var isNewRecord = false

    private var startDate: Date?

    // MARK: 派生

    var currentQuestion: QuizQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    var totalCount: Int { questions.count }

    /// 得分：答对数等比换算成百分制（10 题时即答对数 × 10）
    var score: Int {
        guard totalCount > 0 else { return 0 }
        return Int((Double(correctCount) / Double(totalCount) * 100).rounded())
    }

    var hasAnsweredCurrent: Bool { selectedOption != nil }

    var isLastQuestion: Bool { currentIndex == questions.count - 1 }

    /// 细进度条进度：当前题答完才计入
    var progress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(currentIndex + (hasAnsweredCurrent ? 1 : 0)) / Double(totalCount)
    }

    // MARK: 题池

    /// 题池：未锁定且释义齐全的条目；困难档另要求例句包含成语本体（挖空才成立）。
    static func pool(for difficulty: QuizDifficulty, in idioms: [Idiom]) -> [Idiom] {
        let base = idioms.filter { item in
            !item.locked && !(item.definitionZh ?? "").isEmpty
        }
        switch difficulty {
        case .easy, .medium:
            return base
        case .hard:
            return base.filter { item in
                guard let example = item.exampleZh, !example.isEmpty else { return false }
                return example.contains(item.idiom)
            }
        }
    }

    // MARK: 流程

    /// 开一轮：从题池随机抽至多 10 题（题池更小时取题池数），同轮不重复出同一成语。
    func start(difficulty: QuizDifficulty, idioms: [Idiom]) {
        self.difficulty = difficulty
        let pool = Self.pool(for: difficulty, in: idioms)
        let subjects = Array(pool.shuffled().prefix(10))
        questions = subjects.map { makeQuestion(subject: $0, difficulty: difficulty, pool: pool) }
        currentIndex = 0
        selectedOption = nil
        correctCount = 0
        elapsedSeconds = 0
        isNewRecord = false
        startDate = Date()
        phase = .playing
    }

    /// 选一项：立即锁定并计分，之后不可改选。
    func select(option: String) {
        guard phase == .playing, selectedOption == nil, let question = currentQuestion else { return }
        selectedOption = option
        if option == question.answer {
            correctCount += 1
        }
    }

    /// 「下一题」/「查看成绩」：最后一题时结算用时、落本地记录并标记是否破纪录。
    func advance() {
        guard phase == .playing, hasAnsweredCurrent else { return }
        if isLastQuestion {
            if let startDate = startDate {
                elapsedSeconds = Int(Date().timeIntervalSince(startDate))
            }
            isNewRecord = LocalStore.recordQuizScore(
                difficultyKey: difficulty.rawValue,
                score: score,
                correct: correctCount
            )
            phase = .finished
        } else {
            currentIndex += 1
            selectedOption = nil
        }
    }

    /// 回到难度选择（中途退出不保存半轮；成绩页「返回首页」前也会调用清状态）
    func reset() {
        phase = .selecting
        questions = []
        currentIndex = 0
        selectedOption = nil
        correctCount = 0
        elapsedSeconds = 0
        isNewRecord = false
        startDate = nil
    }

    // MARK: 出题

    private func makeQuestion(subject: Idiom, difficulty: QuizDifficulty, pool: [Idiom]) -> QuizQuestion {
        switch difficulty {
        case .easy:
            // 选项 = 中文释义；干扰项取其他条目释义（按文本去重，避免同义重复混淆）
            let answer = subject.definitionZh ?? ""
            var distractors = Array(
                Set(pool.filter { $0.id != subject.id }.map { $0.definitionZh ?? "" })
            )
            .filter { !$0.isEmpty && $0 != answer }
            .shuffled()
            distractors = Array(distractors.prefix(3))
            return QuizQuestion(
                subject: subject,
                promptText: nil,
                options: ([answer] + distractors).shuffled(),
                answer: answer
            )
        case .medium:
            // 选项 = 成语名；题面 = 中文释义
            let answer = subject.idiom
            let distractors = Array(
                pool.filter { $0.id != subject.id }.map { $0.idiom }.shuffled().prefix(3)
            )
            return QuizQuestion(
                subject: subject,
                promptText: subject.definitionZh,
                options: ([answer] + distractors).shuffled(),
                answer: answer
            )
        case .hard:
            // 选项 = 成语名；题面 = 例句挖空（成语本体替换为（　　），题池已保证例句含本体）
            let answer = subject.idiom
            let blanked = (subject.exampleZh ?? "").replacingOccurrences(of: subject.idiom, with: "（　　）")
            let distractors = Array(
                pool.filter { $0.id != subject.id }.map { $0.idiom }.shuffled().prefix(3)
            )
            return QuizQuestion(
                subject: subject,
                promptText: blanked,
                options: ([answer] + distractors).shuffled(),
                answer: answer
            )
        }
    }
}
