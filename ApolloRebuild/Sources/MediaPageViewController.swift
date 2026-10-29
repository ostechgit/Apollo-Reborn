import UIKit

// MediaPageViewController - displays media in a page view controller
// Reconstructed from apollo-base 1.15.11 binary analysis.

class MediaPageViewController: UIPageViewController {
    
    private var mediaURLs: [URL] = []
    private var currentIndex: Int = 0
    
    init(mediaURLs: [URL]) {
        self.mediaURLs = mediaURLs
        super.init(transitionStyle: .scroll, navigationOrientation: .horizontal)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.dataSource = self
        self.delegate = self
        
        if !self.mediaURLs.isEmpty {
            let firstVC = MediaViewerController(mediaURL: self.mediaURLs[0])
            self.setViewControllers([firstVC], direction: .forward, animated: false)
        }
    }
}

extension MediaPageViewController: UIPageViewControllerDataSource {
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        if let currentVC = viewController as? MediaViewerController {
            // Find index of current VC
            for (index, url) in self.mediaURLs.enumerated() {
                if index > 0 {
                    return MediaViewerController(mediaURL: self.mediaURLs[index - 1])
                }
            }
        }
        return nil
    }
    
    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        if let currentVC = viewController as? MediaViewerController {
            // Find index of current VC
            for (index, url) in self.mediaURLs.enumerated() {
                if index < self.mediaURLs.count - 1 {
                    return MediaViewerController(mediaURL: self.mediaURLs[index + 1])
                }
            }
        }
        return nil
    }
}

extension MediaPageViewController: UIPageViewControllerDelegate {
}
