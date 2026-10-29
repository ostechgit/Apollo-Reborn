import UIKit
import AsyncDisplayKit

// NotificationsViewController - displays user notifications
// Reconstructed from apollo-base 1.15.11 binary analysis.

class NotificationsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var notifications: [RDKMessage] = []
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Notifications"
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
        
        // Load notifications
        loadNotifications()
    }
    
    private func loadNotifications() {
        // Fetch notifications from Reddit (using unread inbox as proxy)
        self.isLoading = true
        
        RDKClient.shared().unreadInboxMessages(pagination: nil) { [weak self] messages, pagination, error in
            if let messages = messages {
                self?.notifications = messages as? [RDKMessage] ?? []
            } else if let error = error {
                print("Failed to load notifications: \(error.localizedDescription)")
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
        return self.notifications.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let notification = self.notifications[indexPath.row]
            let node = NotificationCellNode(notification: notification)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

// NotificationCellNode - displays a single notification
class NotificationCellNode: ASCellNode {
    
    private let notification: RDKMessage
    
    init(notification: RDKMessage) {
        self.notification = notification
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let label = ASTextNode()
        label.attributedText = NSAttributedString(
            string: self.notification.subject ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        self.addSubnode(label)
        
        label.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 40)
    }
    
    override func layout() {
        super.layout()
        if let nodes = self.subnodes {
            for subnode in nodes {
                subnode.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 40)
            }
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
