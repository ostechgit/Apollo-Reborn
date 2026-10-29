import UIKit
import AsyncDisplayKit

// AllSubredditCommentsViewController - displays all comments for a subreddit
// Reconstructed from apollo-base 1.15.11 binary analysis.

class AllSubredditCommentsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var comments: [RDKComment] = []
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
        
        self.title = "All Comments"
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
        
        // Load comments
        loadComments()
    }
    
    private func loadComments() {
        // Fetch all comments for the subreddit
        self.isLoading = true
        
        RDKClient.shared().commentsInSubreddit(withName:self.subredditName, category: .new, pagination: nil) { [weak self] comments, pagination, error in
            if let comments = comments {
                self?.comments = comments as? [RDKComment] ?? []
            } else if let error = error {
                print("Failed to load comments: \(error.localizedDescription)")
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
        return self.comments.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let comment = self.comments[indexPath.row]
            let node = CommentCellNode(comment: comment)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
