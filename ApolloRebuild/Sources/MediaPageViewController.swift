import UIKit

// Basic reachable gallery paging. Native viewer transitions, zoom, animation,
// and sharing remain separate parity work; this is not a complete reconstruction.
class MediaPageViewController: UIPageViewController, UIPageViewControllerDataSource {
    private let mediaURLs: [URL]
    private var pages: [MediaViewerController] = []

    init(mediaURLs: [URL]) {
        self.mediaURLs = mediaURLs
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.pages = self.mediaURLs.map { MediaViewerController(mediaURL: $0) }
        self.dataSource = self
        if let first = self.pages.first {
            self.setViewControllers([first], direction: .forward, animated: false)
        }
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let index = self.pages.firstIndex(where: { $0 === viewController }), index > 0 else { return nil }
        return self.pages[index - 1]
    }

    func pageViewController(_ pageViewController: UIPageViewController,
                            viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let index = self.pages.firstIndex(where: { $0 === viewController }), index + 1 < self.pages.count else { return nil }
        return self.pages[index + 1]
    }
}
