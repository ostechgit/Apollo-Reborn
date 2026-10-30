import UIKit

// ComposeViewController - compose new posts or comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ComposeViewController: UIViewController {
    
    private var titleField: UITextField?
    private var bodyTextView: UITextView?
    private var subredditField: UITextField?
    private var isPost = true
    private var replyTarget: String?
    private var onSubmitted: ((RDKComment) -> Void)?
    private var submitButton: UIButton?
    private var submitting = false

    convenience init(replyTo fullName: String, onSubmitted: @escaping (RDKComment) -> Void) {
        self.init(isPost: false)
        self.replyTarget = fullName
        self.onSubmitted = onSubmitted
    }
    
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
        
        // Keep Submit reachable while editing rather than behind the keyboard.
        let bottom = self.view.safeAreaLayoutGuide.bottomAnchor
        let composerBottom: NSLayoutYAxisAnchor
        if #available(iOS 15.0, *) {
            composerBottom = self.view.keyboardLayoutGuide.topAnchor
        } else {
            composerBottom = bottom
        }
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: self.view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: self.view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: composerBottom, constant: -16)
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
        bodyTextView.accessibilityLabel = self.isPost ? "Body" : "Comment"
        bodyTextView.font = UIFont.systemFont(ofSize: 14)
        stack.addArrangedSubview(bodyTextView)
        self.bodyTextView = bodyTextView
        
        // Submit button
        let submitButton = UIButton(type: .system)
        submitButton.setTitle("Submit", for: .normal)
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        stack.addArrangedSubview(submitButton)
        self.submitButton = submitButton
        submitButton.isEnabled = self.replyTarget != nil
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel,
            primaryAction: UIAction { [weak self] _ in self?.dismiss(animated: true) })
    }
    
    @objc private func submitTapped() {
        guard !self.submitting, let target = self.replyTarget,
              let text = self.bodyTextView?.text,
              !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        self.submitting = true
        self.isModalInPresentation = true
        self.navigationController?.isModalInPresentation = true
        self.submitButton?.isEnabled = false
        self.navigationItem.leftBarButtonItem?.isEnabled = false
        RDKClient.shared().submitComment(text, onThingWithFullName: target) { [weak self] comment, error in
            guard let self = self else { return }
            self.submitting = false
            self.isModalInPresentation = false
            self.navigationController?.isModalInPresentation = false
            self.submitButton?.isEnabled = true
            self.navigationItem.leftBarButtonItem?.isEnabled = true
            guard let comment = comment, error == nil else {
                // Keep text intact. Never silently dismiss a rejected/uncertain write.
                let alert = UIAlertController(title: nil, message: error?.localizedDescription, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                self.present(alert, animated: true)
                return
            }
            self.onSubmitted?(comment)
            self.dismiss(animated: true)
        }
    }
}

// Reply transport is functional; native context preview, draft handling and
// formatting toolbar remain a separate composer-parity investigation.
