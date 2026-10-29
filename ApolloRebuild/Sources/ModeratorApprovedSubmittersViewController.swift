import UIKit

// ModeratorApprovedSubmittersViewController - manages approved submitters
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModeratorApprovedSubmittersViewController: UIViewController {
    
    private let subredditName: String
    
    init(subredditName: String) {
        self.subredditName = subredditName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.subredditName = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Approved Submitters"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Approved submitters for r/" + self.subredditName
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
