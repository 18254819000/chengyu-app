import Foundation

/// 看图猜成语模式：一个游戏、两种模式，不分难度（需求第 20 章）。
enum PictureGameMode: String, CaseIterable, Identifiable {
    case regular
    case endless

    var id: String { rawValue }

    var title: String {
        switch self {
        case .regular: return "Regular"
        case .endless: return "Endless"
        }
    }

    var subtitle: String {
        switch self {
        case .regular: return "10 questions, picture prompts"
        case .endless: return "Answer until one miss — your streak is your score"
        }
    }
}

/// 一道看图题：题面为 subject 的故事图，选项为成语名
struct PictureQuestion: Identifiable {
    let id = UUID()
    let subject: Idiom
    let options: [String]
    let answer: String
}

/// 看图猜出题与答题状态机：常规固定 10 题；连答无限出题、错一题结束。
/// 答错自动进错题本（LocalStore）；成绩只写本地最佳，榜单上报由结算页经 GameCenterManager 触发。
@MainActor
final class PictureGameEngine: ObservableObject {
    enum Phase {
        case selecting
        case playing
        case finished
    }

    @Published private(set) var phase: Phase = .selecting
    @Published private(set) var mode: PictureGameMode = .regular
    @Published private(set) var questions: [PictureQuestion] = []
    @Published private(set) var currentIndex = 0
    @Published private(set) var selectedOption: String?
    @Published private(set) var correctCount = 0
    @Published private(set) var currentStreak = 0
    @Published private(set) var bestStreak = 0
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var isNewRecord = false
    /// 连答模式答错后置 true：本局已结束，界面出「查看成绩」按钮（先让用户看到对错反馈再结算）
    @Published private(set) var runOver = false
    /// 本局答错的成语（结算页错题列表用）
    @Published private(set) var missedSubjects: [Idiom] = []

    private var startDate: Date?
    private var pool: [Idiom] = []
    private var queue: [Idiom] = []
    private var lastSubjectId: Int?

    // MARK: 派生

    var currentQuestion: PictureQuestion? {
        questions.indices.contains(currentIndex) ? questions[currentIndex] : nil
    }

    /// 常规局总题数；连答局显示已答题数（currentIndex 即已答题数，因答完才推进）
    var totalCount: Int {
        mode == .regular ? questions.count : currentIndex + (hasAnsweredCurrent ? 1 : 0)
    }

    var hasAnsweredCurrent: Bool { selectedOption != nil }

    var isLastQuestion: Bool {
        mode == .regular && currentIndex >= questions.count - 1
    }

    /// 常规局细进度条：当前题答完才计入；连答局不显示进度条
    var progress: Double {
        guard mode == .regular, !questions.isEmpty else { return 0 }
        return Double(currentIndex + (hasAnsweredCurrent ? 1 : 0)) / Double(questions.count)
    }

    // MARK: 题池

    /// 题池：未锁定且有故事图的已发布成语（免费 20 张 / 订阅 114 张，天然按权益区分）
    static func pool(in idioms: [Idiom]) -> [Idiom] {
        idioms.filter { !$0.locked && $0.hasStoryImage }
    }

    // MARK: 流程

    func start(mode: PictureGameMode, idioms: [Idiom]) {
        self.mode = mode
        pool = Self.pool(in: idioms)
        queue = pool.shuffled()
        lastSubjectId = nil
        questions = []
        currentIndex = 0
        selectedOption = nil
        correctCount = 0
        currentStreak = 0
        bestStreak = 0
        elapsedSeconds = 0
        isNewRecord = false
        runOver = false
        missedSubjects = []
        startDate = Date()
        if mode == .regular {
            let subjects = Array(pool.shuffled().prefix(10))
            questions = subjects.map { makeQuestion(subject: $0) }
        } else {
            if let first = dequeueSubject() {
                questions = [makeQuestion(subject: first)]
            }
        }
        phase = questions.isEmpty ? .selecting : .playing
    }

    /// 选一项：立即锁定并计分，之后不可改选；答错进错题本；连答答错标记本局结束
    func select(option: String) {
        guard phase == .playing, selectedOption == nil, let question = currentQuestion else { return }
        selectedOption = option
        if option == question.answer {
            correctCount += 1
            currentStreak += 1
            bestStreak = max(bestStreak, currentStreak)
            LocalStore.pictureBestStreak = max(LocalStore.pictureBestStreak, currentStreak)
        } else {
            currentStreak = 0
            missedSubjects.append(question.subject)
            LocalStore.recordMistake(id: question.subject.id)
            if mode == .endless {
                runOver = true
            }
        }
    }

    /// 「下一题」/「查看成绩」：常规最后一题或连答结束时结算并落本地最佳
    func advance() {
        guard phase == .playing, hasAnsweredCurrent else { return }
        if mode == .endless && runOver {
            finish()
            return
        }
        if isLastQuestion {
            finish()
            return
        }
        if mode == .endless {
            if let next = dequeueSubject() {
                questions.append(makeQuestion(subject: next))
            }
        }
        currentIndex += 1
        selectedOption = nil
    }

    private func finish() {
        if let startDate = startDate {
            elapsedSeconds = Int(Date().timeIntervalSince(startDate))
        }
        LocalStore.pictureRoundsTotal += 1
        if mode == .regular {
            isNewRecord = correctCount > LocalStore.pictureRegularBest
            if isNewRecord { LocalStore.pictureRegularBest = correctCount }
        } else {
            isNewRecord = bestStreak > LocalStore.pictureEndlessBest
            if isNewRecord { LocalStore.pictureEndlessBest = bestStreak }
        }
        phase = .finished
    }

    /// 回到模式选择（中途退出不保存半局；结算页「返回」前也会调用清状态）
    func reset() {
        phase = .selecting
        questions = []
        currentIndex = 0
        selectedOption = nil
        correctCount = 0
        currentStreak = 0
        bestStreak = 0
        elapsedSeconds = 0
        isNewRecord = false
        runOver = false
        missedSubjects = []
        startDate = nil
    }

    // MARK: 出题

    private func dequeueSubject() -> Idiom? {
        if queue.isEmpty {
            queue = pool.shuffled()
        }
        // 避免与上一题连续重复（题库 > 1 时）
        if pool.count > 1, queue.first?.id == lastSubjectId, queue.count > 1 {
            queue.append(queue.removeFirst())
        }
        guard let subject = queue.first else { return nil }
        queue.removeFirst()
        lastSubjectId = subject.id
        return subject
    }

    private func makeQuestion(subject: Idiom) -> PictureQuestion {
        let answer = subject.idiom
        let distractors = Array(
            pool.filter { $0.id != subject.id }.map { $0.idiom }.shuffled().prefix(3)
        )
        return PictureQuestion(
            subject: subject,
            options: ([answer] + distractors).shuffled(),
            answer: answer
        )
    }
}
