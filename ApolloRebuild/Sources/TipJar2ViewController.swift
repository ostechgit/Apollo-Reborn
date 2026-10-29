import UIKit

// TipJar2ViewController - shows the tip jar for supporting the developer
// Reconstructed from apollo-base 1.15.11 binary analysis.

class TipJar2ViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Tip Jar"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "If you enjoy Apollo, consider tipping the developer!"
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
        
        // Tip button
        let tipButton = UIButton(type: .system)
        tipButton.setTitle("Tip $1", for: .normal)
        tipButton.addTarget(self, action: #selector(tipTapped), for: .touchUpInside)
        
        self.view.addSubview(tipButton)
        
        tipButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tipButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            tipButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
    }
    
    @objc private func tipTapped() {
        // In the original app, this would process a tip
        // For now, just log
        LogBuddy.info("Tip tapped")
    }
}
