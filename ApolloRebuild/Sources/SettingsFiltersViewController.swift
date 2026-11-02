import UIKit

// SettingsFiltersViewController - stock's "Filters & Blocks".
//
// Recovered scaffolding: the keyword list is `NSUserDefaults` key
// `KeywordFilters`, a plain `[String]` (read via `stringArrayForKey:` in
// `FUN_1000bca84`, which falls back from a suite to standard defaults). The
// feed hides any post whose title contains one of the entries.
//
// Stock also has "Add User" (blocked users) and "Add Subreddit" (locally
// filtered subreddits), stored under `blockedUsers` / `filteredSubreddits` /
// `locallyFilteredSubreddits`. Those need the corresponding feed-side filtering
// and the account APIs, so they are not reproduced here yet — see the footer.

class SettingsFiltersViewController: UITableViewController {

    private static let keywordsKey = "KeywordFilters"
    private var keywords: [String] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Filters & Blocks"
        self.tableView.register(UITableViewCell.self, forCellReuseIdentifier: "keyword")
        self.tableView.tableFooterView = self.makeFooter()
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .add, target: self, action: #selector(addKeyword))
        self.reload()
    }

    private func makeFooter() -> UIView {
        let label = UILabel()
        label.text = "Posts whose title contains a keyword are hidden from your feeds. "
            + "Blocked users and filtered subreddits are not available yet."
        label.numberOfLines = 0
        label.font = .preferredFont(forTextStyle: .footnote)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        let width = UIScreen.main.bounds.width
        let size = label.sizeThatFits(CGSize(width: width - 40, height: .greatestFiniteMagnitude))
        label.frame = CGRect(x: 20, y: 12, width: width - 40, height: size.height)
        let host = UIView(frame: CGRect(x: 0, y: 0, width: width, height: size.height + 40))
        host.addSubview(label)
        return host
    }

    private func reload() {
        self.keywords = UserDefaults.standard.stringArray(forKey: Self.keywordsKey) ?? []
        self.tableView.reloadData()
    }

    private func persist(_ list: [String]) {
        UserDefaults.standard.set(list, forKey: Self.keywordsKey)
        self.reload()
    }

    @objc private func addKeyword() {
        let alert = UIAlertController(
            title: "Add Keyword",
            message: "Posts whose title contains this word are hidden.",
            preferredStyle: .alert)
        alert.addTextField { field in
            field.placeholder = "Keyword"
            field.autocapitalizationType = .none
            field.autocorrectionType = .no
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Add", style: .default) { [weak self, weak alert] _ in
            guard let self = self,
                  let raw = alert?.textFields?.first?.text else { return }
            let keyword = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !keyword.isEmpty else { return }
            guard !self.keywords.contains(where: {
                $0.caseInsensitiveCompare(keyword) == .orderedSame
            }) else { return }
            var list = self.keywords
            list.append(keyword)
            self.persist(list)
        })
        self.present(alert, animated: true)
    }

    // MARK: - Table

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.keywords.count
    }

    override func tableView(_ tableView: UITableView,
                            cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "keyword", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = self.keywords[indexPath.row]
        cell.contentConfiguration = content
        return cell
    }

    override func tableView(_ tableView: UITableView,
                            commit editingStyle: UITableViewCell.EditingStyle,
                            forRowAt indexPath: IndexPath) {
        guard editingStyle == .delete else { return }
        var list = self.keywords
        list.remove(at: indexPath.row)
        self.persist(list)
    }
}
