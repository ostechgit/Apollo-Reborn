import UIKit

// CrosspostPerformViewController - perform a crosspost to another subreddit
// Reconstructed from apollo-base 1.15.11 binary analysis.

class CrosspostPerformViewController: UIViewController {
    
    private let post: RDKLink
    
    init(post: RDKLink) {
        self.post = post
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        guard let dummyPost = RDKLink(dictionary: [:]) else {
            return nil
        }
        self.post = dummyPost
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Crosspost"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Crosspost to another subreddit"
        label.textAlignment = .center
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        
        self.view.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 100),
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16)
        ])
    }
}
