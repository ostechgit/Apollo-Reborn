import UIKit
import AsyncDisplayKit

// ModmailSearchResultsViewController - displays search results for modmail
// Reconstructed from apollo-base 1.15.11 binary analysis.

class ModmailSearchResultsViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
    
    private var tableView: ASTableView?
    private var searchResults: [RDKModmailConversation] = []
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
        
        // Load search results
        loadSearchResults()
    }
    
    private func loadSearchResults() {
        // Search modmail conversations
        self.isLoading = true
        
        RDKClient.shared().searchModmail(query: self.searchQuery, limit: 25) { [weak self] conversations, error in
            if let conversations = conversations {
                self?.searchResults = conversations as? [RDKModmailConversation] ?? []
            } else if let error = error {
                print("Modmail search failed: \(error.localizedDescription)")
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
            let conversation = self.searchResults[indexPath.row]
            let node = ModmailConversationCellNode(conversation: conversation)
            return node
        }
    }
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "Cell")
        return cell
    }
}
