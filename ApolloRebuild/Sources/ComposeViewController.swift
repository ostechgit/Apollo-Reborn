import UIKit

// ComposeViewController - compose new posts or comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ComposeViewController: UIViewController {
    
    private var titleField: UITextField?
    private var bodyTextView: UITextView?
    private var subredditField: UITextField?
    private var isPost = true
    
    init(isPost: Bool) {
        self.isPost = isPost
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.isPost ? "New Post" : "New Comment"
        self.view.backgroundColor = UIColor.systemBackground
        
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(stack)
        
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        
        if self.isPost {
            // Subreddit field
            let subredditField = UITextField()
            subredditField.placeholder = "Subreddit (e.g., r/funny)"
            subredditField.borderStyle = .roundedRect
            stack.addArrangedSubview(subredditField)
            self.subredditField = subredditField
            
            // Title field
            let titleField = UITextField()
            titleField.placeholder = "Title"
            titleField.borderStyle = .roundedRect
            stack.addArrangedSubview(titleField)
            self.titleField = titleField
        }
        
        // Body text view
        let bodyTextView = UITextView()
        bodyTextView.placeholder = self.isPost ? "Body (optional)" : "Comment"
        bodyTextView.font = UIFont.systemFont(ofSize: 14)
        stack.addArrangedSubview(bodyTextView)
        self.bodyTextView = bodyTextView
        
        // Submit button
        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        stack.addArrangedSubview(submitButton)
    }
    
    @objc private func submitTapped() {
        // In the original app, this would submit the post/comment to Reddit
        // For now, we'll just dismiss
        self.dismiss(animated: true, completion: nil)
    }
}

// UITextView placeholder extension
extension UITextView {
    var placeholder: String? {
        get {
            return self.value(forKey: "placeholder") as? String
        }
        set {
            self.setValue(newValue, forKey: "placeholder")
        }
    }
}
