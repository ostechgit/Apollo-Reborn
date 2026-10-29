import UIKit
import AsyncDisplayKit

// MultiredditViewController - displays a multireddit
// Reconstructed from apollo-base 1.15.11 binary analysis.

class MultiredditViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var posts: [RDKLink] = []
    private var multiredditName: String
    private var isLoading = false
    
    init(multiredditName: String) {
        self.multiredditName = multiredditName
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.multiredditName = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "m/" + self.multiredditName
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
        
        // Load posts
        loadPosts()
    }
    
    private func loadPosts() {
        // Fetch posts from the multireddit
        self.isLoading = true
        
        RDKClient.shared.multiredditWithName(self.multiredditName) { [weak self] multireddit, error in
            if let multireddit = multireddit {
                // Load posts from the multireddit's subreddits
                RDKClient.shared.linksInMultireddit(multireddit, category: .hot, pagination: nil) { links, error in
                    if let links = links {
                        self?.posts = links
                    }
                    
                    self?.isLoading = false
                    self?.tableView?.reloadData()
                }
            } else if let error = error {
                print("Failed to load multireddit: \(error.localizedDescription)")
                self?.isLoading = false
                self?.tableView?.reloadData()
            }
        }
    }
    
    // MARK: - ASDataSource
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.posts.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let post = self.posts[indexPath.row]
            let node = PostCellNode(post: post)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
