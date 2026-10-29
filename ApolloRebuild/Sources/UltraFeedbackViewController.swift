import UIKit

// UltraFeedbackViewController - shows feedback form for Apollo Ultra
// Reconstructed from apollo-base 1.15.11 binary analysis.

class UltraFeedbackViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Ultra Feedback"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Share your feedback about Apollo Ultra"
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
