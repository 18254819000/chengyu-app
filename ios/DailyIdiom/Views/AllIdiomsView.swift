import SwiftUI

/// 全部成语列表：每行只有成语 + 拼音（新角标、锁定锁图标），搜索走后端 q 参数并防抖。
struct AllIdiomsView: View {
    @EnvironmentObject var state: AppState
    @State private var query: String = ""
    /// nil = 未在搜索，展示本地全量；非 nil = 搜索结果
    @State private var results: [Idiom]?
    @State private var isSearching = false
    @State private var searchTask: Task<Void, Never>?

    var body: some View {
        Group {
            if let results = results {
                if results.isEmpty {
                    emptySearchState
                } else {
                    list(of: results)
                }
            } else {
                list(of: state.idioms)
            }
        }
        .background(Color.paperBg.ignoresSafeArea())
        .navigationTitle(L("All Idioms"))
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: L("Search idioms or pinyin…"))
        .onChange(of: query) { newValue in
            scheduleSearch(newValue)
        }
    }

    private func list(of items: [Idiom]) -> some View {
        List {
            ForEach(items) { item in
                Button {
                    // selectIdiom 会置 showAllList=false 收起本页回首页，并翻到该成语
                    state.selectIdiom(id: item.id)
                } label: {
                    row(for: item)
                }
                .listRowBackground(Color.paperBg)
                .listRowSeparatorTint(Color.line)
            }
        }
        .listStyle(.plain)
        .overlay {
            if isSearching {
                ProgressView()
            }
        }
    }

    private func row(for item: Idiom) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(item.idiom)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(item.locked ? .ink2 : .ink)
                    if state.newIdiomIds.contains(item.id) {
                        Text(L("NEW"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentRed)
                            .cornerRadius(5)
                    }
                    // 当日免费成语标记（免费用户在几百条里一眼找到今天那条）
                    if item.id == state.dailyIdiomId {
                        Text(L("TODAY"))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.accentRed)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.accentSoft)
                            .cornerRadius(5)
                    }
                }
                Text(item.pinyin)
                    .font(.system(size: 12.5, design: .serif))
                    .foregroundColor(.ink3)
            }
            Spacer()
            if item.locked {
                Image(systemName: "lock")
                    .font(.system(size: 14))
                    .foregroundColor(.ink3)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.ink3)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    /// 搜索无结果必须有明确提示与清空入口（需求 F3）
    private var emptySearchState: some View {
        VStack(spacing: 0) {
            Text(L("No idioms found"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.ink)
                .padding(.top, 64)
            Text(L("Check your spelling or try another keyword.\nYou can also search by pinyin, e.g. shou zhu"))
                .font(.system(size: 13))
                .foregroundColor(.ink3)
                .multilineTextAlignment(.center)
                .lineSpacing(6)
                .padding(.top, 8)
            Button(L("Clear Search")) {
                query = ""
            }
            .font(.system(size: 13.5))
            .foregroundColor(.ink)
            .padding(.horizontal, 22)
            .padding(.vertical, 9)
            .overlay(Capsule().stroke(Color.line, lineWidth: 1))
            .padding(.top, 18)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    /// 防抖 350ms 后调后端搜索；清空搜索词时回到本地全量
    private func scheduleSearch(_ text: String) {
        searchTask?.cancel()
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            results = nil
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 350_000_000)
            if Task.isCancelled { return }
            let found = try? await state.api.fetchAllIdioms(query: trimmed)
            if Task.isCancelled { return }
            results = found ?? []
            isSearching = false
        }
    }
}
