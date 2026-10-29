import UIKit

// Missing view controller stubs for moderator actions and reporting
// These are referenced by ActionController extensions but not yet implemented.

class BanUserViewController: UIViewController {
    let username: String
    let subreddit: String
    
    init(username: String, subreddit: String) {
        self.username = username
        self.subreddit = subreddit
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.username = ""
        self.subreddit = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Ban User"
        self.view.backgroundColor = .systemBackground
    }
}

class CommentReportsViewController: UIViewController {
    let comment: RDKComment
    
    init(comment: RDKComment) {
        self.comment = comment
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.comment = RDKComment()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Reports"
        self.view.backgroundColor = .systemBackground
    }
}

class LinkReportsViewController: UIViewController {
    let link: RDKLink
    
    init(link: RDKLink) {
        self.link = link
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.link = RDKLink()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Reports"
        self.view.backgroundColor = .systemBackground
    }
}

class SuggestedSortViewController: UIViewController {
    let link: RDKLink
    
    init(link: RDKLink) {
        self.link = link
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.link = RDKLink()
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Suggested Sort"
        self.view.backgroundColor = .systemBackground
    }
}

class ModmailReportViewController: UIViewController {
    let thingFullname: String
    let subreddit: String
    
    init(thingFullname: String, subreddit: String) {
        self.thingFullname = thingFullname
        self.subreddit = subreddit
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.thingFullname = ""
        self.subreddit = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Report to Mods"
        self.view.backgroundColor = .systemBackground
    }
}

class UserReportViewController: UIViewController {
    let thingFullname: String
    let subreddit: String
    
    init(thingFullname: String, subreddit: String) {
        self.thingFullname = thingFullname
        self.subreddit = subreddit
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.thingFullname = ""
        self.subreddit = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Report"
        self.view.backgroundColor = .systemBackground
    }
}

class ReportViewController: UIViewController {
    let thingFullname: String
    let subreddit: String
    
    init(thingFullname: String, subreddit: String) {
        self.thingFullname = thingFullname
        self.subreddit = subreddit
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        self.thingFullname = ""
        self.subreddit = ""
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = "Report"
        self.view.backgroundColor = .systemBackground
    }
}
