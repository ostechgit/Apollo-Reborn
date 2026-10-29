import UIKit

// ApolloUltraViewController - shows Apollo Ultra features and purchase options
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ApolloUltraViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Apollo Ultra"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Upgrade to Apollo Ultra for premium features"
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
        
        // Purchase button
        let purchaseButton = UIButton(type: .system)
        purchaseButton.setTitle("Purchase Ultra", for: .normal)
        purchaseButton.addTarget(self, action: #selector(purchaseTapped), for: .touchUpInside)
        
        self.view.addSubview(purchaseButton)
        
        purchaseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            purchaseButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            purchaseButton.centerXAnchor.constraint(equalTo: self.view.centerXAnchor)
        ])
    }
    
    @objc private func purchaseTapped() {
        // In the original app, this would purchase Apollo Ultra
        // For now, just log
        LogBuddy.info("Ultra purchase tapped")
    }
}
