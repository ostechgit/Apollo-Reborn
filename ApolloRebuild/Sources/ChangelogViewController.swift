import UIKit

// ChangelogViewController - shows the app changelog
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ChangelogViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Changelog"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Version 1.15.11\n\n- Bug fixes and performance improvements\n- New features and enhancements"
        label.textAlignment = .left
        label.numberOfLines = 0
        label.font = UIFont.systemFont(ofSize: 14)
        
        self.view.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            label.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            label.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}
