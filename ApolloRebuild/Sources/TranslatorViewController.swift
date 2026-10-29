import UIKit

// TranslatorViewController - translates post/comment text
// Reconstructed from apollo-base 1.15.11 binary analysis.

class TranslatorViewController: UIViewController {
    
    private let textToTranslate: String
    
    init(textToTranslate: String) {
        self.textToTranslate = textToTranslate
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.textToTranslate = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Translate"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = "Translation: " + self.textToTranslate
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
