import UIKit
import AsyncDisplayKit

// SubredditSearchResultsViewController - displays search results for subreddits
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SubredditSearchResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var searchResults: [RDKSubreddit] = []
    private var searchQuery: String
    private var isLoading = false
    
    init(searchQuery: String) {
        self.searchQuery = searchQuery
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.searchQuery = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Search: " + self.searchQuery
        self.view.backgroundColor = UIColor.systemBackground
        
        let tableView = ASTableView(frame: .zero)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 60
        self.view.addSubview(tableView)
        
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        
        self.tableView = tableView
        
        // Load search results
        loadSearchResults()
    }
    
    private func loadSearchResults() {
        // Search Reddit for subreddits
        self.isLoading = true
        
        RDKClient.shared().searchSubreddits(query: self.searchQuery, limit: 25) { [weak self] subreddits, error in
            if let subreddits = subreddits {
                self?.searchResults = subreddits as? [RDKSubreddit] ?? []
            } else if let error = error {
                print("Subreddit search failed: \(error.localizedDescription)")
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
        return self.searchResults.count
    }
    
    func tableView(_ tableView: ASTableView, nodeBlockForRowAt indexPath: IndexPath) -> ASCellNodeBlock {
        return {
            let subreddit = self.searchResults[indexPath.row]
            let node = SubredditCellNode(subreddit: subreddit)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
