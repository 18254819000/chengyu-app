import SwiftUI
import UIKit

/// 成语测试：选难度（三档）→ 答题（即时对错反馈）→ 成绩页（本地最佳对比 + 分享成绩）。
/// 入口在首页顶栏「测试」，由 AppState.showQuiz 驱动 NavigationLink 推入，返回走系统导航返回。
struct QuizView: View {
    @EnvironmentObject var state: AppState
    @StateObject private var engine = QuizEngine()

    @State private var shareItem: ShareItem?

    /// 答对绿（Theme 无绿色 token，测试页局部定义）
    private let correctGreen = Color(red: 46 / 255, green: 125 / 255, blue: 50 / 255)
    private let correctBg = Color(red: 232 / 255, green: 245 / 255, blue: 233 / 255)

    var body: some View {
        Group {
            switch engine.phase {
            case .selecting:
                selectingView
            case .playing:
                playingView
            case .finished:
                resultView
            }
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle("Chengyu Quiz")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
    }

    // MARK: 难度选择

    @ViewBuilder
    private var selectingView: some View {
        let easyPool = QuizEngine.pool(for: .easy, in: state.idioms)
        if easyPool.count < 4 {
            VStack(spacing: 12) {
                Spacer()
                Text("Not Enough Content Yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.ink)
                Text("There aren't enough idioms available for a quiz yet. Please try again once content has finished syncing.")
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
                    .multilineTextAlignment(.center)
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 40)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    Text("Choose a difficulty to start")
                        .font(.system(size: 15))
                        .foregroundColor(.ink2)
                        .padding(.top, 26)

                    ForEach(QuizDifficulty.allCases) { difficulty in
                        difficultyRow(difficulty)
                            .padding(.top, 16)
                    }

                    Text("\(min(10, easyPool.count)) questions per round, with your score at the end")
                        .font(.system(size: 12.5))
                        .foregroundColor(.ink3)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func difficultyRow(_ difficulty: QuizDifficulty) -> some View {
        let pool = QuizEngine.pool(for: difficulty, in: state.idioms)
        let available = pool.count >= 4
        let best = LocalStore.quizBestScore(difficultyKey: difficulty.rawValue)
        return Button {
            engine.start(difficulty: difficulty, idioms: state.idioms)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(difficulty.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.ink)
                    Text(available ? difficulty.subtitle : "\(difficulty.subtitle) (Not enough questions)")
                        .font(.system(size: 13))
                        .foregroundColor(.ink3)
                }
                Spacer()
                if best > 0 {
                    Text("Best: \(best)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentRed)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.ink3)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.cardBg)
            .cornerRadius(16)
        }
        .disabled(!available)
        .opacity(available ? 1 : 0.5)
    }

    // MARK: 答题

    @ViewBuilder
    private var playingView: some View {
        if let question = engine.currentQuestion {
            VStack(spacing: 0) {
                progressHeader
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        questionPrompt(question)
                            .padding(.top, 22)

                        VStack(spacing: 12) {
                            ForEach(question.options, id: \.self) { option in
                                optionRow(option, question: question)
                            }
                        }
                        .padding(.top, 28)

                        if engine.hasAnsweredCurrent {
                            Button {
                                engine.advance()
                            } label: {
                                Text(engine.isLastQuestion ? "See Results" : "Next")
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentRed)
                                    .cornerRadius(999)
                            }
                            .padding(.top, 26)
                        }

                        Spacer(minLength: 30)
                    }
                    .padding(.horizontal, 26)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
    }

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(engine.difficulty.tagText)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.ink3)
                Spacer()
                Text("\(engine.currentIndex + 1)/\(engine.totalCount)")
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.line)
                        .frame(height: 3)
                    Rectangle()
                        .fill(Color.accentRed)
                        .frame(width: geo.size.width * engine.progress, height: 3)
                }
            }
            .frame(height: 3)
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
    }

    @ViewBuilder
    private func questionPrompt(_ question: QuizQuestion) -> some View {
        switch engine.difficulty {
        case .easy:
            subjectHead(question.subject)
        case .medium, .hard:
            VStack(alignment: .leading, spacing: 0) {
                Text(engine.difficulty == .medium ? "Which idiom does this English definition describe?" : "Fill in the blank with the correct idiom")
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
                Text(question.promptText ?? "")
                    .font(.system(size: engine.difficulty == .medium ? 18 : 17.5,
                                  weight: .medium,
                                  design: engine.difficulty == .medium ? .serif : .default))
                    .lineSpacing(7)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
        }
    }

    /// 简单档题面：逐字拼音 + 成语（与详情页同式，字号略小）
    private func subjectHead(_ idiom: Idiom) -> some View {
        let chars = Array(idiom.idiom)
        let pinyins = idiom.charPinyins
        return Group {
            if pinyins.count == chars.count {
                HStack(alignment: .top, spacing: 0) {
                    ForEach(Array(chars.enumerated()), id: \.offset) { item in
                        VStack(spacing: 6) {
                            Text(pinyins[item.offset])
                                .font(.system(size: 14, design: .serif))
                                .foregroundColor(.ink2)
                            Text(String(item.element))
                                .font(.system(size: 46, weight: .semibold))
                                .foregroundColor(.ink)
                        }
                        if item.offset < chars.count - 1 {
                            Spacer(minLength: 4)
                        }
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text(idiom.pinyin)
                        .font(.system(size: 14, design: .serif))
                        .foregroundColor(.ink2)
                    Text(idiom.idiom)
                        .font(.system(size: 46, weight: .semibold))
                        .foregroundColor(.ink)
                }
            }
        }
    }

    private func optionRow(_ option: String, question: QuizQuestion) -> some View {
        let answered = engine.hasAnsweredCurrent
        let isAnswer = option == question.answer
        let isSelected = option == engine.selectedOption
        return Button {
            engine.select(option: option)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(option)
                    .font(.system(size: engine.difficulty == .easy ? 15.5 : 17.5,
                                  weight: engine.difficulty == .easy ? .regular : .semibold,
                                  design: engine.difficulty == .easy ? .serif : .default))
                    .foregroundColor(optionForeground(isAnswer: isAnswer, isSelected: isSelected, answered: answered))
                    .lineSpacing(4)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if answered && isAnswer {
                    Text("✓")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(correctGreen)
                } else if answered && isSelected {
                    Text("✗")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.accentRed)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 15)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(optionBackground(isAnswer: isAnswer, isSelected: isSelected, answered: answered))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(optionBorder(isAnswer: isAnswer, isSelected: isSelected, answered: answered), lineWidth: 1)
            )
        }
        .disabled(answered)
    }

    private func optionBackground(isAnswer: Bool, isSelected: Bool, answered: Bool) -> Color {
        guard answered else { return Color.cardBg }
        if isAnswer { return correctBg }
        if isSelected { return Color.accentSoft }
        return Color.cardBg
    }

    private func optionBorder(isAnswer: Bool, isSelected: Bool, answered: Bool) -> Color {
        guard answered else { return Color.clear }
        if isAnswer { return correctGreen }
        if isSelected { return Color.accentRed }
        return Color.clear
    }

    private func optionForeground(isAnswer: Bool, isSelected: Bool, answered: Bool) -> Color {
        guard answered else { return .ink }
        if isAnswer { return correctGreen }
        if isSelected { return .accentRed }
        return .ink2
    }

    // MARK: 成绩页

    private var resultView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                Text(engine.difficulty.tagText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentRed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.accentSoft)
                    .cornerRadius(999)
                    .padding(.top, 36)

                Text("\(engine.score)")
                    .font(.system(size: 88, weight: .bold))
                    .foregroundColor(.ink)
                    .padding(.top, 22)

                Text("\(engine.correctCount)/\(engine.totalCount) correct · \(engine.elapsedSeconds)s")
                    .font(.system(size: 15))
                    .foregroundColor(.ink2)

                if engine.isNewRecord {
                    Text("New Record!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentRed)
                        .padding(.top, 12)
                }

                Button {
                    shareScore()
                } label: {
                    Text("Share My Score")
                        .font(.system(size: 15.5, weight: .semibold))
                        .tracking(1)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.accentRed)
                        .cornerRadius(999)
                }
                .padding(.top, 38)

                Button {
                    engine.start(difficulty: engine.difficulty, idioms: state.idioms)
                } label: {
                    Text("Try Again")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .overlay(
                            Capsule().stroke(Color.line, lineWidth: 1)
                        )
                }
                .padding(.top, 14)

                Button {
                    engine.reset()
                    state.showQuiz = false
                } label: {
                    Text("Back to Home")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.ink2)
                        .padding(.vertical, 10)
                }
                .padding(.top, 10)

                if !state.isEntitled {
                    Button {
                        state.showPaywall = true
                    } label: {
                        Text("Subscribe to unlock all idioms and a bigger question bank")
                            .font(.system(size: 12.5))
                            .foregroundColor(.ink3)
                            .underline()
                    }
                    .padding(.top, 30)
                }

                Spacer(minLength: 30)
            }
            .padding(.horizontal, 26)
            .frame(maxWidth: .infinity)
        }
    }

    /// 生成成绩分享卡并弹系统分享面板
    private func shareScore() {
        let card = ScoreShareCard(
            difficulty: engine.difficulty,
            score: engine.score,
            correct: engine.correctCount,
            total: engine.totalCount,
            date: Date()
        )
        if let image = ShareCardRenderer.render(card) {
            shareItem = ShareItem(image: image)
        }
    }
}
