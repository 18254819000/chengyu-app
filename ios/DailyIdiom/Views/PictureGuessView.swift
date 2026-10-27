import SwiftUI
import UIKit

/// 看图猜成语：测验页内第二游戏，一个游戏、两种模式，不分难度（需求第 20 章）。
/// 常规固定 10 题；连答无限出题、错一题结束，成绩 = 最高连答。题面为故事图，选项为成语名。
/// 入口在测验页；结算时经 GameCenterManager 同步榜单与成就（幂等，重复调用无害）。
struct PictureGuessView: View {
    @EnvironmentObject var state: AppState
    @Environment(\.dismiss) private var dismiss
    @StateObject private var engine = PictureGameEngine()

    @State private var shareItem: ShareItem?
    @State private var storySubject: Idiom?
    @State private var showingStory = false

    /// 答对绿（与测试页同款局部定义，Theme 无绿色 token）
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
        .navigationTitle("Picture Guess")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $shareItem) { item in
            ShareSheet(items: [item.image])
        }
        .sheet(isPresented: $showingStory) {
            if let subject = storySubject {
                StoryView(idiom: subject)
            }
        }
    }

    // MARK: 模式选择

    @ViewBuilder
    private var selectingView: some View {
        let pool = PictureGameEngine.pool(in: state.idioms)
        if pool.count < 4 {
            VStack(spacing: 12) {
                Spacer()
                Text("Not Enough Pictures Yet")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.ink)
                Text("There aren't enough illustrated idioms available yet. Please try again once content has finished syncing.")
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
                    Text("Look at the story image, pick the idiom")
                        .font(.system(size: 15))
                        .foregroundColor(.ink2)
                        .padding(.top, 26)

                    ForEach(PictureGameMode.allCases) { mode in
                        modeRow(mode, poolCount: pool.count)
                            .padding(.top, 16)
                    }

                    Text("Picture pool: \(pool.count) illustrated idioms · wrong answers go to your mistake book")
                        .font(.system(size: 12.5))
                        .foregroundColor(.ink3)
                        .padding(.top, 24)
                }
                .padding(.horizontal, 26)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private func modeRow(_ mode: PictureGameMode, poolCount: Int) -> some View {
        Button {
            engine.start(mode: mode, idioms: state.idioms)
        } label: {
            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(mode.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.ink)
                        .multilineTextAlignment(.leading)
                    Text(mode.subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.ink3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Spacer()
                if mode == .regular, LocalStore.pictureRegularBest > 0 {
                    Text("Best: \(LocalStore.pictureRegularBest)/10")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.accentRed)
                } else if mode == .endless, LocalStore.pictureEndlessBest > 0 {
                    Text("Best: \(LocalStore.pictureEndlessBest)")
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
    }

    // MARK: 答题

    @ViewBuilder
    private var playingView: some View {
        if let question = engine.currentQuestion {
            VStack(spacing: 0) {
                progressHeader
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        picturePrompt(question)
                            .padding(.top, 22)

                        VStack(spacing: 12) {
                            ForEach(question.options, id: \.self) { option in
                                optionRow(option, question: question)
                            }
                        }
                        .padding(.top, 28)

                        if engine.hasAnsweredCurrent {
                            Button {
                                storySubject = question.subject
                                LocalStore.recordStoryRead(id: question.subject.id)
                                state.gameCenter.syncProgress()
                                showingStory = true
                            } label: {
                                Text("View Story")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.accentRed)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 13)
                                    .overlay(
                                        Capsule().stroke(Color.accentRed, lineWidth: 1)
                                    )
                            }
                            .padding(.top, 18)

                            Button {
                                engine.advance()
                            } label: {
                                Text(engine.runOver || engine.isLastQuestion ? "See Results" : "Next")
                                    .font(.system(size: 15.5, weight: .semibold))
                                    .tracking(1)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(Color.accentRed)
                                    .cornerRadius(999)
                            }
                            .padding(.top, 12)
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
                Text(engine.mode.title)
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundColor(.ink3)
                Spacer()
                if engine.mode == .regular {
                    Text("\(engine.currentIndex + 1)/\(engine.totalCount)")
                        .font(.system(size: 12.5))
                        .foregroundColor(.ink3)
                } else {
                    Text("Streak \(engine.currentStreak)")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundColor(.accentRed)
                }
            }
            if engine.mode == .regular {
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
        }
        .padding(.horizontal, 26)
        .padding(.top, 16)
    }

    private func picturePrompt(_ question: PictureQuestion) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Which idiom does this picture tell?")
                .font(.system(size: 13))
                .foregroundColor(.ink3)
            if let urlString = question.subject.imageUrl, let url = URL(string: urlString) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(16 / 9, contentMode: .fill)
                    case .failure:
                        ZStack {
                            Color.cardBg
                            Text("Image unavailable")
                                .font(.system(size: 13))
                                .foregroundColor(.ink3)
                        }
                        .aspectRatio(16 / 9, contentMode: .fill)
                    default:
                        ZStack {
                            Color.cardBg
                            Text("Loading image…")
                                .font(.system(size: 13))
                                .foregroundColor(.ink3)
                        }
                        .aspectRatio(16 / 9, contentMode: .fill)
                    }
                }
                .cornerRadius(12)
                .padding(.top, 12)
            }
        }
    }

    private func optionRow(_ option: String, question: PictureQuestion) -> some View {
        let answered = engine.hasAnsweredCurrent
        let isAnswer = option == question.answer
        let isSelected = option == engine.selectedOption
        return Button {
            engine.select(option: option)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text(option)
                    .font(.system(size: 17.5, weight: .semibold))
                    .foregroundColor(optionForeground(isAnswer: isAnswer, isSelected: isSelected, answered: answered))
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
                Text("PICTURE GUESS · \(engine.mode.title.uppercased())")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.accentRed)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(Color.accentSoft)
                    .cornerRadius(999)
                    .padding(.top, 36)

                if engine.mode == .regular {
                    Text("\(engine.correctCount)/\(engine.totalCount)")
                        .font(.system(size: 88, weight: .bold))
                        .foregroundColor(.ink)
                        .padding(.top, 22)
                    Text("correct · \(engine.elapsedSeconds)s")
                        .font(.system(size: 15))
                        .foregroundColor(.ink2)
                } else {
                    Text("\(engine.bestStreak)")
                        .font(.system(size: 88, weight: .bold))
                        .foregroundColor(.ink)
                        .padding(.top, 22)
                    Text("longest streak · \(engine.correctCount) correct · \(engine.elapsedSeconds)s")
                        .font(.system(size: 15))
                        .foregroundColor(.ink2)
                }

                if engine.isNewRecord {
                    Text("New Record!")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.accentRed)
                        .padding(.top, 12)
                }

                if !engine.missedSubjects.isEmpty {
                    VStack(alignment: .leading, spacing: 0) {
                        Text("Review your misses (\(engine.missedSubjects.count))")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.ink)
                            .padding(.top, 30)
                            .padding(.bottom, 6)
                        ForEach(engine.missedSubjects, id: \.id) { idiom in
                            HStack {
                                Text(idiom.idiom)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.ink)
                                Spacer()
                                Button("Story →") {
                                    storySubject = idiom
                                    LocalStore.recordStoryRead(id: idiom.id)
                                    state.gameCenter.syncProgress()
                                    showingStory = true
                                }
                                .font(.system(size: 13))
                                .foregroundColor(.accentRed)
                            }
                            .padding(.vertical, 10)
                            Divider()
                        }
                    }
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
                    engine.start(mode: engine.mode, idioms: state.idioms)
                } label: {
                    Text("Play Again")
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
                    dismiss()
                } label: {
                    Text("Back to Games")
                        .font(.system(size: 14.5, weight: .medium))
                        .foregroundColor(.ink2)
                        .padding(.vertical, 10)
                }
                .padding(.top, 10)

                if !state.isEntitled {
                    Button {
                        state.showPaywall = true
                    } label: {
                        Text("Subscribe to unlock all 114 illustrated idioms")
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
        .onAppear {
            // 结算点同步榜单与成就（幂等，重复调用无害）
            state.gameCenter.syncProgress()
            state.refreshStreak()
        }
    }

    /// 生成看图成绩分享卡并弹系统分享面板
    private func shareScore() {
        let card = PictureScoreShareCard(
            mode: engine.mode,
            regularScore: "\(engine.correctCount)/\(engine.totalCount)",
            streak: engine.bestStreak,
            date: Date()
        )
        if let image = ShareCardRenderer.render(card) {
            shareItem = ShareItem(image: image)
        }
    }
}

/// 看图成绩分享卡：纸面风 + 朱红印章，与现有成绩卡同套视觉语言
private struct PictureScoreShareCard: View {
    let mode: PictureGameMode
    let regularScore: String
    let streak: Int
    let date: Date

    var body: some View {
        VStack(spacing: 0) {
            Text("PICTURE GUESS")
                .font(.system(size: 13, weight: .semibold))
                .tracking(3)
                .foregroundColor(.ink3)
            Text(mode == .regular ? regularScore : "\(streak)")
                .font(.system(size: 88, weight: .bold))
                .foregroundColor(.ink)
                .padding(.top, 18)
            Text(mode == .regular ? "correct" : "longest streak")
                .font(.system(size: 16))
                .foregroundColor(.ink2)
            Spacer()
            HStack {
                Text(dateString)
                    .font(.system(size: 13))
                    .foregroundColor(.ink3)
                Spacer()
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(Color.accentRed)
                        .frame(width: 96, height: 96)
                    Text("Daily\nChengyu")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
            }
        }
        .padding(44)
        .frame(width: 1080, height: 1350)
        .background(Color.paperBg)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "MMM d, yyyy"
        return f.string(from: date)
    }
}
