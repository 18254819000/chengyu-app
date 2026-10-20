import SwiftUI
import UIKit

/// UIPageViewController 包装的左右翻页容器：
/// 左滑 = 下一个、右滑 = 上一个；相邻页由 dataSource 自然预加载。
/// 外部修改 currentIndex（如列表定位、深链接）会驱动它动画跳页；手势翻页完成后回写 currentIndex。
struct PagerView<Content: View>: UIViewControllerRepresentable {
    var pageCount: Int
    @Binding var currentIndex: Int
    var content: (Int) -> Content

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIViewController(context: Context) -> UIPageViewController {
        let pvc = UIPageViewController(transitionStyle: .scroll,
                                       navigationOrientation: .horizontal,
                                       options: nil)
        pvc.dataSource = context.coordinator
        pvc.delegate = context.coordinator
        pvc.view.backgroundColor = .clear
        if pageCount > 0 {
            let index = min(max(currentIndex, 0), pageCount - 1)
            let vc = context.coordinator.makeController(at: index)
            context.coordinator.displayedIndex = index
            pvc.setViewControllers([vc], direction: .forward, animated: false)
        }
        return pvc
    }

    func updateUIViewController(_ pvc: UIPageViewController, context: Context) {
        context.coordinator.parent = self
        let coordinator = context.coordinator
        // 内容数据变化（如同步完成、权益翻转导致锁定状态变化）时刷新已缓存页面的内容
        for (index, vc) in coordinator.cache {
            if index < pageCount {
                vc.rootView = content(index)
            }
        }
        coordinator.pruneCache(around: currentIndex)
        guard pageCount > 0 else { return }
        let target = min(max(currentIndex, 0), pageCount - 1)
        if coordinator.displayedIndex != target {
            let direction: UIPageViewController.NavigationDirection =
                (coordinator.displayedIndex ?? 0) < target ? .forward : .reverse
            let vc = coordinator.makeController(at: target)
            coordinator.displayedIndex = target
            pvc.setViewControllers([vc], direction: direction, animated: true)
        }
    }

    final class Coordinator: NSObject, UIPageViewControllerDataSource, UIPageViewControllerDelegate {
        var parent: PagerView
        var displayedIndex: Int?
        var cache: [Int: UIHostingController<Content>] = [:]
        private var indexByController: [ObjectIdentifier: Int] = [:]

        init(parent: PagerView) {
            self.parent = parent
        }

        func makeController(at index: Int) -> UIHostingController<Content> {
            if let cached = cache[index] { return cached }
            let vc = UIHostingController(rootView: parent.content(index))
            vc.view.backgroundColor = .clear
            cache[index] = vc
            indexByController[ObjectIdentifier(vc)] = index
            return vc
        }

        /// 只保留当前页附近的托管控制器，避免长列表滑动时无限积累
        func pruneCache(around index: Int) {
            for key in cache.keys where abs(key - index) > 2 {
                if let vc = cache[key] {
                    indexByController.removeValue(forKey: ObjectIdentifier(vc))
                }
                cache.removeValue(forKey: key)
            }
        }

        private func index(of vc: UIViewController) -> Int? {
            indexByController[ObjectIdentifier(vc)]
        }

        // MARK: UIPageViewControllerDataSource

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerBefore viewController: UIViewController) -> UIViewController? {
            guard let idx = index(of: viewController), idx > 0 else { return nil }
            return makeController(at: idx - 1)
        }

        func pageViewController(_ pageViewController: UIPageViewController,
                                viewControllerAfter viewController: UIViewController) -> UIViewController? {
            guard let idx = index(of: viewController), idx < parent.pageCount - 1 else { return nil }
            return makeController(at: idx + 1)
        }

        // MARK: UIPageViewControllerDelegate

        func pageViewController(_ pageViewController: UIPageViewController,
                                didFinishAnimating finished: Bool,
                                previousViewControllers: [UIViewController],
                                transitionCompleted completed: Bool) {
            guard completed,
                  let visible = pageViewController.viewControllers?.first,
                  let idx = index(of: visible) else { return }
            displayedIndex = idx
            if parent.currentIndex != idx {
                // 避免在视图更新周期内直接改 Binding，下一轮主队列再回写
                DispatchQueue.main.async { [weak self] in
                    self?.parent.currentIndex = idx
                }
            }
        }
    }
}
