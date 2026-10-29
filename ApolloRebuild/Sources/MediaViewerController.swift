import UIKit
import AsyncDisplayKit

// MediaViewerController - fullscreen media viewer for images and videos
// Reconstructed from apollo-base 1.15.11 binary analysis.

class MediaViewerController: UIViewController {
    
    private var imageView: UIImageView?
    private var mediaURL: URL?
    
    init(mediaURL: URL?) {
        self.mediaURL = mediaURL
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        self.view.addSubview(imageView)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: self.view.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.imageView = imageView
        
        // Load image
        if let url = self.mediaURL {
            DispatchQueue.global().async { [weak self] in
                if let data = try? Data(contentsOf: url),
                   let image = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self?.imageView?.image = image
                    }
                }
            }
        }
    }
}
