import UIKit
import AsyncDisplayKit

// SearchViewController - search for posts, users, or subreddits
// Reconstructed from apollo-base 1.15.11 binary analysis.

class SearchViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var searchResults: [RDKLink] = []
    private var searchQuery = ""
    private var isLoading = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Search"
        self.view.backgroundColor = UIColor.systemBackground
        
        // Add search bar
        let searchController = UISearchController(searchResultsController: nil)
        searchController.searchBar.placeholder = "Search Reddit"
        searchController.searchBar.delegate = self
        self.navigationItem.searchController = searchController
        self.definesPresentationContext = true
        
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
    }
    
    private func performSearch(query: String) {
        // Search Reddit for posts matching the query
        self.searchQuery = query
        self.isLoading = true
        
        RDKClient.shared.search(query: query, sort: .relevance, time: .all, subreddit: nil, pagination: nil) { [weak self] links, error in
            if let links = links {
                self?.searchResults = links
            } else if let error = error {
                print("Search failed: \(error.localizedDescription)")
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
            let post = self.searchResults[indexPath.row]
            let node = SearchResultCellNode(post: post)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}

extension SearchViewController: UISearchBarDelegate {
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        self.performSearch(query: searchBar.text ?? "")
        searchBar.resignFirstResponder()
    }
}

// SearchResultCellNode - displays a search result
class SearchResultCellNode: ASCellNode {
    
    private let post: RDKLink
    
    init(post: RDKLink) {
        self.post = post
        super.init()
        
        self.backgroundColor = UIColor.clear
        
        let title = ASTextNode()
        title.attributedText = NSAttributedString(
            string: self.post.title ?? "",
            attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: UIColor.label
            ]
        )
        
        let subreddit = ASTextNode()
        subreddit.attributedText = NSAttributedString(
            string: "r/" + (self.post.subreddit ?? ""),
            attributes: [
                .font: UIFont.systemFont(ofSize: 12),
                .foregroundColor: UIColor.secondaryLabel
            ]
        )
        
        self.addSubnode(title)
        self.addSubnode(subreddit)
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        subreddit.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
    
    override func layout() {
        super.layout()
        guard let nodes = self.subnodes, nodes.count >= 2 else { return }
        let title = nodes[0]
        let subreddit = nodes[1]
        
        title.frame = CGRect(x: 16, y: 16, width: self.frame.width - 32, height: 20)
        subreddit.frame = CGRect(x: 16, y: 40, width: self.frame.width - 32, height: 16)
    }
}
