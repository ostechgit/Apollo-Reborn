import UIKit
import AsyncDisplayKit

// ModQueueViewController - moderator queue for reviewing posts
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModQueueViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var queueItems: [RDKLink] = []
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
        
        self.title = "Mod Queue"
        self.view.backgroundColor = UIColor.systemBackground
        
        let tableView = ASTableView(frame: .zero)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 100
        self.view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.tableView = tableView
        
        // Load queue items
        loadQueue()
    }
    
    private func loadQueue() {
        // Fetch mod queue items from Reddit
        self.isLoading = true
        
        RDKClient.shared.moderationQueueForSubredditWithName(self.subredditName, pagination: nil) { [weak self] links, error in
            if let links = links {
                self?.queueItems = links
            } else if let error = error {
                print("Failed to load mod queue: \(error.localizedDescription)")
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
        return self.queueItems.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let item = self.queueItems[indexPath.row]
            let node = QueueItemCellNode(item: item)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

// QueueItemCellNode - displays a mod queue item
class QueueItemCellNode: ASCellNode {
    
    private let item: RDKLink
    
    init(item: RDKLink) {
        self.item = item
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let title = ASTextNode()
        title.attributedText = NSAttributedString(
            string: self.item.title ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        let author = ASTextNode()
        author.attributedText = NSAttributedString(
            string: "by " + (self.item.author ?? "unknown"),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        self.addSubnode(title)
        self.addSubnode(author)
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        author.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    
    override func layout() {
        super.layout()
        guard let nodes = self.subnodes, nodes.count >= 2 else { return }
        let title = nodes[0]
        let author = nodes[1]
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        author.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
