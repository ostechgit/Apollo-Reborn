import UIKit
import AsyncDisplayKit

// ModeratorLogsViewController - view moderator action logs
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModeratorLogsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var logs: [RDKModeratorAction] = []
    private var subredditName: String
    private var isLoading = false
    
    init(subredditName: String) {
        self.subredditName = subredditName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.subredditName = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Mod Logs"
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
        
        // Load logs
        loadLogs()
    }
    
    private func loadLogs() {
        // Fetch mod logs from Reddit
        self.isLoading = true
        
        RDKClient.shared().moderationLogForSubreddit(withName: self.subredditName, pagination: nil) { [weak self] logs, pagination, error in
            if let logs = logs {
                self?.logs = logs as? [RDKModeratorAction] ?? []
            } else if let error = error {
                print("Failed to load mod logs: \(error.localizedDescription)")
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
        return self.logs.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let log = self.logs[indexPath.row]
            let node = ModLogCellNode(log: log)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

// ModLogCellNode - displays a moderator log entry
class ModLogCellNode: ASCellNode {
    
    private let log: RDKModeratorAction
    
    init(log: RDKModeratorAction) {
        self.log = log
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let action = ASTextNode()
        action.attributedText = NSAttributedString(
            string: self.log.action ?? "",
            attributes: [
                .font: UIFont.boldSystemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        let mod = ASTextNode()
        mod.attributedText = NSAttributedString(
            string: "by " + (self.log.moderatorUsername ?? "unknown"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        self.addSubnode(action)
        self.addSubnode(mod)
        
        action.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        mod.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    
    override func layout() {
        super.layout()
        guard let nodes = self.subnodes, nodes.count >= 2 else { return }
        let action = nodes[0]
        let mod = nodes[1]
        
        action.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        mod.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
