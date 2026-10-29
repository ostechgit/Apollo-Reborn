import UIKit
import AsyncDisplayKit

// SavedPostsCommentsViewController - displays saved posts and comments
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SavedPostsCommentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var savedItems: [RDKLink] = []
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Saved"
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
        
        // Load saved items
        loadSavedItems()
    }
    
    private func loadSavedItems() {
        // Fetch saved items from Reddit
        self.isLoading = true
        
        RDKClient.shared().savedLinks(pagination: nil) { [weak self] links, pagination, error in
            if let links = links {
                self?.savedItems = links as? [RDKLink] ?? []
            } else if let error = error {
                print("Failed to load saved items: \(error.localizedDescription)")
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
        return self.savedItems.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let item = self.savedItems[indexPath.row]
            let node = PostCellNode(post: item)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
