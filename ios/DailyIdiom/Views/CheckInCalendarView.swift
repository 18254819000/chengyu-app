import SwiftUI

/// 打卡日历（个人中心内）：月历 + 统计；点已打卡日，下方卡片显示当日成语，点卡片回到首页并定位。
/// 打卡规则：打开 App 当天即算打卡（任意学习动作也算）；连续天数按自然日计算，中断后从 1 重计，v1 无补签。
struct CheckInCalendarView: View {
    @EnvironmentObject var state: AppState

    @State private var year: Int
    @State private var month: Int
    @State private var selectedDay: Int?

    init() {
        let comps = Calendar.current.dateComponents([.year, .month], from: Date())
        _year = State(initialValue: comps.year ?? 2026)
        _month = State(initialValue: comps.month ?? 1)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                statsRow
                monthHeader
                calendarGrid
                if let day = selectedDay,
                   let idiom = idiom(for: day) {
                    dayCard(day: day, idiom: idiom)
                }
                Text(L("Checked days are marked red. A missed day breaks the streak — there is no make-up in this version."))
                    .font(.system(size: 12.5))
                    .foregroundColor(.ink3)
                    .lineSpacing(4)
                    .padding(.top, 20)
            }
            .padding(.horizontal, 26)
            .padding(.top, 16)
            .padding(.bottom, 30)
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle(L("Check-in"))
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: 统计

    private var statsRow: some View {
        HStack(spacing: 10) {
            statBox(value: "🔥 \(state.streakDays)", label: L("day streak"))
            statBox(value: "\(LocalStore.totalCheckInDays)", label: L("total days"))
            statBox(value: "\(Set(LocalStore.learnedIdiomIds).count)", label: L("idioms learned"))
        }
    }

    private func statBox(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.ink)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.ink2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Color.cardBg)
        .cornerRadius(14)
    }

    // MARK: 月历

    private var monthHeader: some View {
        HStack {
            Button { shiftMonth(by: -1) } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ink2)
            }
            Spacer()
            Text(monthTitle)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.ink)
            Spacer()
            Button { shiftMonth(by: 1) } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.ink2)
            }
        }
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.locale = AppLanguage.displayLocale
        f.dateFormat = "MMMM yyyy"
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        let date = Calendar.current.date(from: comps) ?? Date()
        return f.string(from: date)
    }

    private var calendarGrid: some View {
        let cal = Calendar.current
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = 1
        guard let first = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: first) else {
            return AnyView(EmptyView())
        }
        let firstWeekday = cal.component(.weekday, from: first) // 1 = Sunday
        let leading = firstWeekday - 1
        let days = range.count
        let checked = Set(LocalStore.checkInDates)
        let todayString = LocalStore.dayString()
        return AnyView(
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 6) {
                ForEach(AppLanguage.weekdayHeaders, id: \.self) { h in
                    Text(h)
                        .font(.system(size: 11.5))
                        .foregroundColor(.ink3)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<leading, id: \.self) { _ in
                    Text("")
                }
                ForEach(1...days, id: \.self) { day in
                    let key = String(format: "%04d-%02d-%02d", year, month, day)
                    let isChecked = checked.contains(key)
                    let isToday = key == todayString
                    Button {
                        if isChecked { selectedDay = day }
                    } label: {
                        Text("\(day)")
                            .font(.system(size: 14, weight: isChecked ? .bold : .regular))
                            .foregroundColor(isChecked ? .accentRed : .ink)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(isChecked ? Color.accentSoft : Color.clear)
                            .cornerRadius(999)
                            .overlay(
                                RoundedRectangle(cornerRadius: 999)
                                    .stroke(isToday ? Color.accentRed : Color.clear, lineWidth: 1.5)
                            )
                    }
                    .disabled(!isChecked)
                }
            }
        )
    }

    private func shiftMonth(by delta: Int) {
        var comps = DateComponents()
        comps.year = year
        comps.month = month + delta
        comps.day = 1
        if let date = Calendar.current.date(from: comps) {
            let parts = Calendar.current.dateComponents([.year, .month], from: date)
            year = parts.year ?? year
            month = parts.month ?? month
        }
        selectedDay = nil
    }

    // MARK: 当日成语卡

    private func idiom(for day: Int) -> Idiom? {
        guard !state.idioms.isEmpty else { return nil }
        let key = String(format: "%04d-%02d-%02d", year, month, day)
        let idx = DateUtil.dailyIndex(dateString: key, count: state.idioms.count)
        return state.idioms.indices.contains(idx) ? state.idioms[idx] : nil
    }

    private func dayCard(day: Int, idiom: Idiom) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(monthTitle) \(day) · \(idiom.idiom)")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.ink)
            if idiom.locked {
                Text(L("This idiom is locked — subscribe to read it."))
                    .font(.system(size: 13))
                    .foregroundColor(.ink2)
            } else {
                Text(idiom.definitionEn ?? "")
                    .font(.system(size: 13, design: .serif))
                    .foregroundColor(.ink2)
                    .lineSpacing(3)
            }
            Button {
                state.selectIdiom(id: idiom.id)
            } label: {
                Text(L("Open in Home →"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.accentRed)
            }
            .padding(.top, 6)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.cardBg)
        .cornerRadius(14)
        .padding(.top, 16)
    }
}
