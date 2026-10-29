import UIKit

// PrivateMessageViewController - displays a private message thread
// Reconstructed from apollo-base 1.15.11 binary analysis.

class PrivateMessageViewController: UIViewController {
    
    private let message: RDKMessage
    
    init(message: RDKMessage) {
        self.message = message
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        do {
            let dummyMessage = try RDKMessage(dictionary: [:])
            self.message = dummyMessage
        } catch {
            return nil
        }
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = self.message.subject ?? "Message"
        self.view.backgroundColor = UIColor.systemBackground
        
        let label = UILabel()
        label.text = self.message.messageBody ?? ""
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
