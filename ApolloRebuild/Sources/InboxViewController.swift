import UIKit
import AsyncDisplayKit

// InboxViewController - displays user's inbox (messages and notifications)
// Reconstructed from apollo-base 1.15.11 binary analysis.

class InboxViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var messages: [RDKMessage] = []
    private var isLoading = false
    private var signInPromptView: SignInPromptView?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Inbox"
        self.view.backgroundColor = UIColor.systemBackground
        
        let tableView = ASTableView(frame: .zero)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 80
        self.view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.tableView = tableView

        NotificationCenter.default.addObserver(self, selector: #selector(accountDidChange), name: AccountManager.accountDidChangeNotification, object: nil)
        self.accountDidChange()
    }

    // The inbox needs an account: show a sign-in prompt instead while signed out
    @objc private func accountDidChange() {
        if AccountManager.shared.isLogged {
            self.signInPromptView?.removeFromSuperview()
            self.signInPromptView = nil
            self.tableView?.isHidden = false
            loadMessages()
            return
        }

        self.messages = []
        self.tableView?.reloadData()
        self.tableView?.isHidden = true

        guard self.signInPromptView == nil else { return }
        let promptView = SignInPromptView(message: "Sign in to see your messages, replies and mentions.") { [weak self] in
            guard let self = self else { return }
            LoginViewController.present(from: self)
        }
        self.view.addSubview(promptView)
        promptView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            promptView.topAnchor.constraint(equalTo: self.view.topAnchor),
            promptView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            promptView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            promptView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        self.signInPromptView = promptView
    }

    private func loadMessages() {
        // In the original app, this would fetch messages from Reddit
        // For now, we'll use placeholder data
        self.isLoading = true
        
        // Simulate loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            self?.isLoading = false
            self?.tableView?.reloadData()
        }
    }
    
    // MARK: - ASDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.messages.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let message = self.messages[indexPath.row]
            let node = MessageCellNode(message: message)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

// MessageCellNode - displays a single message
class MessageCellNode: ASCellNode {
    
    private let message: RDKMessage
    
    init(message: RDKMessage) {
        self.message = message
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let subjectLabel = ASTextNode()
        subjectLabel.attributedText = NSAttributedString(
            string: self.message.subject ?? "",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        let bodyLabel = ASTextNode()
        bodyLabel.attributedText = NSAttributedString(
            string: self.message.messageBody ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        self.addSubnode(subjectLabel)
        self.addSubnode(bodyLabel)
        
        subjectLabel.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        bodyLabel.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 30)
    }
    
    override func layout() {
        super.layout()
        guard let nodes = self.subnodes, nodes.count >= 2 else { return }
        let subjectLabel = nodes[0]
        let bodyLabel = nodes[1]
        
        subjectLabel.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        bodyLabel.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 30)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
