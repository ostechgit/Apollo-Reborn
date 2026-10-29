import UIKit
import AsyncDisplayKit

// ModmailInboxViewController - displays the modmail inbox
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModmailInboxViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var conversations: [RDKModmailConversation] = []
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Modmail"
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
        
        // Load conversations
        loadConversations()
    }
    
    private func loadConversations() {
        // Fetch modmail conversations from Reddit
        self.isLoading = true
        
        RDKClient.shared.modmailConversations(pagination: nil) { [weak self] conversations, error in
            if let conversations = conversations {
                self?.conversations = conversations
            } else if let error = error {
                print("Failed to load modmail: \(error.localizedDescription)")
            }
            
            self?.isLoading = false
            self?.tableView?.reloadData()
        }
    }
    
    // MARK: - ASDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.conversations.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let conversation = self.conversations[indexPath.row]
            let node = ModmailConversationCellNode(conversation: conversation)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

// ModmailConversationCellNode - displays a modmail conversation
class ModmailConversationCellNode: ASCellNode {
    
    private let conversation: RDKModmailConversation
    
    init(conversation: RDKModmailConversation) {
        self.conversation = conversation
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let label = ASTextNode()
        label.attributedText = NSAttributedString(
            string: self.conversation.title ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        self.addSubnode(label)
        
        label.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
    }
    
    override func layout() {
        super.layout()
        if let nodes = self.subnodes {
            for subnode in nodes {
                subnode.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
            }
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
