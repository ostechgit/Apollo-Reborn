import UIKit
import WebKit

// RedditWebSignInViewController - Reddit's OAuth consent flow in an in-app WKWebView
// Ported from Apollo Reborn's ApolloWebAuthViewController / ApolloWebAuthPopupViewController,
// which replace Apollo's ASWebAuthenticationSession there (on by default). Native here,
// with Reborn's API-key path only: its cookie harvest for chat and its external-browser
// manual sign-in are not carried over.
//
// Why a web view rather than ASWebAuthenticationSession:
// - The callback is matched on the whole redirect URI (scheme + host + path), so
//   http/https redirect URIs from Reddit "web app" keys work, not just custom schemes.
// - Reddit's new consent page doesn't validate client_id / redirect_uri when it
//   renders: a key that matches no Reddit app still shows Accept, and only the POST
//   to /svc/shreddit/oauth-grant fails with a bare 400 "{}". That response is caught
//   and explained here, with Old Reddit (which names the bad field) one tap away.
// - iOS 15 can't render the modern login page, so the flow stays on old.reddit.com.

enum RedditWebSignInError: Error {
    case cancelled
}

class RedditWebSignInViewController: UIViewController, WKNavigationDelegate, WKUIDelegate, UIAdaptivePresentationControllerDelegate {

    private var authURL: URL
    private let redirectURL: URL?
    private let completion: (URL?, Error?) -> Void
    private var webView: WKWebView!
    private let spinner = UIActivityIndicatorView(style: .medium)
    private var finished = false
    // Set once a rejected sign-in has been explained, so Reddit's own 400 authorize
    // page (Old Reddit's names the bad field) doesn't stack a second alert
    private var explainedRejectedSignIn = false

    // Presents the sign-in sheet over `presenter`. `completion` gets the callback URL
    // (with ?state=&code= or ?error=), RedditWebSignInError.cancelled, or a load error.
    static func present(from presenter: UIViewController, authURL: URL, redirectURI: String, completion: @escaping (URL?, Error?) -> Void) {
        let signIn = RedditWebSignInViewController(authURL: authURL, redirectURI: redirectURI, completion: completion)
        let navigationController = UINavigationController(rootViewController: signIn)
        navigationController.modalPresentationStyle = .formSheet
        navigationController.presentationController?.delegate = signIn
        presenter.present(navigationController, animated: true)
    }

    init(authURL: URL, redirectURI: String, completion: @escaping (URL?, Error?) -> Void) {
        self.authURL = authURL
        self.redirectURL = URL(string: redirectURI)
        self.completion = completion
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var supportsModernReddit: Bool {
        if #available(iOS 16, *) { return true }
        return false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Sign In to Reddit"
        self.view.backgroundColor = .systemBackground
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        self.navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: nil)
        self.rebuildOptionsMenu()

        if !self.supportsModernReddit {
            LogBuddy.info("RedditWebSignIn: iOS 15, using old.reddit.com")
            self.authURL = self.oldRedditURL(for: self.authURL)
        }

        // Non-persistent store: every sign-in starts logged out, so adding a different account works
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        self.webView = WKWebView(frame: self.view.bounds, configuration: configuration)
        self.webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        self.webView.navigationDelegate = self
        self.webView.uiDelegate = self
        self.view.addSubview(self.webView)

        self.spinner.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        self.view.addSubview(self.spinner)
        self.spinner.startAnimating()

        self.webView.load(URLRequest(url: self.authURL))
    }

    // MARK: - Old Reddit

    private func oldRedditURL(for url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.host == "www.reddit.com" || components.host == "reddit.com" else {
            return url
        }
        components.host = "old.reddit.com"
        return components.url ?? url
    }

    private func switchToOldReddit() {
        // The grant endpoint has no Old Reddit equivalent; restart from the authorize request then
        let current = self.webView.url
        let base = current.flatMap { self.isGrantEndpoint($0) ? nil : $0 } ?? self.authURL
        self.webView.load(URLRequest(url: self.oldRedditURL(for: base)))
    }

    private func rebuildOptionsMenu() {
        let onOldReddit = self.webView?.url?.host == "old.reddit.com"
        let oldReddit = UIAction(title: "Switch to Old Reddit", image: UIImage(systemName: "arrow.triangle.2.circlepath"),
                                 attributes: onOldReddit ? .disabled : []) { [weak self] _ in
            self?.switchToOldReddit()
        }
        self.navigationItem.rightBarButtonItem?.menu = UIMenu(title: "Sign-In Options", children: [oldReddit])
    }

    // MARK: - Finishing

    @objc private func cancelTapped() {
        self.finish(url: nil, error: RedditWebSignInError.cancelled)
    }

    // Swiping the sheet down is a cancel too, or the sign-in screen would wait forever
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        guard !self.finished else { return }
        self.finished = true
        self.completion(nil, RedditWebSignInError.cancelled)
    }

    private func finish(url: URL?, error: Error?) {
        guard !self.finished else { return }
        self.finished = true
        let completion = self.completion
        RedditWebSignInPopupViewController.closePopups(above: self) { [weak self] in
            guard let self = self else {
                completion(url, error)
                return
            }
            self.navigationController?.dismiss(animated: true) {
                completion(url, error)
            }
        }
    }

    // MARK: - Rejected sign-in

    private func isRedditHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "reddit.com" || host.hasSuffix(".reddit.com")
    }

    private func isGrantEndpoint(_ url: URL) -> Bool {
        return self.isRedditHost(url.host) && url.path == "/svc/shreddit/oauth-grant"
    }

    // Apollo requests /api/v1/authorize.compact; Old Reddit answers a bad key there with a 400 page
    private func isAuthorizePage(_ url: URL) -> Bool {
        return self.isRedditHost(url.host) && url.path.hasPrefix("/api/v1/authorize")
    }

    private func explainRejectedSignIn(status: Int, offerOldReddit: Bool) {
        guard !self.finished, self.presentedViewController == nil else { return }
        self.explainedRejectedSignIn = true
        LogBuddy.error("RedditWebSignIn: Reddit refused the sign-in (HTTP \(status))")

        let fix = "check the client ID and redirect URI on the sign-in screen against your app at reddit.com/prefs/apps"
        let title: String
        let message: String
        if status == 400 {
            title = "Reddit Didn\u{2019}t Accept This API Key"
            message = "The client ID and redirect URI used for this sign-in don\u{2019}t match a Reddit app, so Reddit won\u{2019}t connect your account. Both have to match the app exactly.\n\nTo fix it, \(fix)."
        } else {
            // Can be an outage, but Old Reddit also answers some malformed client IDs with a 500
            title = "Reddit Couldn\u{2019}t Finish Signing In"
            let retry = offerOldReddit ? "Wait a few minutes and try again, or switch to Old Reddit and accept there." : "Wait a few minutes and try again."
            message = "Reddit returned an error (HTTP \(status)). \(retry)\n\nIf it keeps happening, \(fix)."
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        if offerOldReddit {
            alert.addAction(UIAlertAction(title: "Switch to Old Reddit", style: .default) { [weak self] _ in
                self?.switchToOldReddit()
            })
        }
        alert.addAction(UIAlertAction(title: "OK", style: .cancel))
        self.present(alert, animated: true)
    }

    // MARK: - WKUIDelegate

    // "Continue with Google" / "Continue with Apple" open their page in a popup window
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard !self.finished else { return nil }
        return RedditWebSignInPopupViewController.presentPopup(from: self, configuration: configuration, navigationAction: navigationAction)
    }

    // MARK: - WKNavigationDelegate

    // Scheme + host + path against the redirect URI, ignoring the ?state=&code= Reddit appends.
    // A custom scheme (apollo://reddit-oauth) may carry its "host" as part of the URI; matching the
    // scheme alone is unambiguous there because no Reddit page uses it.
    private func isCallback(_ url: URL) -> Bool {
        guard let redirectURL = self.redirectURL, let scheme = url.scheme, let redirectScheme = redirectURL.scheme,
              scheme.caseInsensitiveCompare(redirectScheme) == .orderedSame else {
            return false
        }
        if redirectScheme.lowercased() == "http" || redirectScheme.lowercased() == "https" {
            return url.host?.lowercased() == redirectURL.host?.lowercased() && url.path == redirectURL.path
        }
        return true
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.allow)
            return
        }

        if self.isCallback(url) {
            // Stop it here: the OS can't route an unregistered scheme, and an https redirect mustn't hit the network
            decisionHandler(.cancel)
            LogBuddy.info("RedditWebSignIn: got the OAuth callback")
            self.finish(url: url, error: nil)
            return
        }

        // On iOS 15 Reddit's own redirects lead back to www.reddit.com (e.g. the consent page after login)
        if !self.supportsModernReddit {
            let rewritten = self.oldRedditURL(for: url)
            if rewritten != url {
                decisionHandler(.cancel)
                webView.load(URLRequest(url: rewritten))
                return
            }
        }
        decisionHandler(.allow)
    }

    // A successful Accept never gets here (it redirects to the callback). Only error
    // responses from the two consent endpoints are handled.
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        guard navigationResponse.isForMainFrame, let response = navigationResponse.response as? HTTPURLResponse,
              response.statusCode >= 400, let url = response.url else {
            decisionHandler(.allow)
            return
        }

        if self.isGrantEndpoint(url) {
            // Keep the consent page on screen instead of committing the bare "{}" body
            decisionHandler(.cancel)
            self.explainRejectedSignIn(status: response.statusCode, offerOldReddit: true)
            return
        }
        if self.isAuthorizePage(url) {
            // Reddit's error page names the bad field itself; let it render and add where to fix it
            decisionHandler(.allow)
            if !self.explainedRejectedSignIn {
                self.explainRejectedSignIn(status: response.statusCode, offerOldReddit: false)
            }
            return
        }
        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.spinner.startAnimating()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.spinner.stopAnimating()
        self.rebuildOptionsMenu()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.spinner.stopAnimating()
        if self.isExpectedCancellation(error) { return }
        LogBuddy.error("RedditWebSignIn: page failed to load (\((error as NSError).domain) \((error as NSError).code))")
        self.finish(url: nil, error: error)
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.spinner.stopAnimating()
        if self.isExpectedCancellation(error) { return }
        LogBuddy.error("RedditWebSignIn: navigation failed (\((error as NSError).domain) \((error as NSError).code))")
        self.finish(url: nil, error: error)
    }

    // -999 and WebKit's 102 ("frame load interrupted") come from our own decisionHandler cancels
    private func isExpectedCancellation(_ error: Error) -> Bool {
        let error = error as NSError
        return error.code == NSURLErrorCancelled || (error.domain == "WebKitErrorDomain" && error.code == 102)
    }
}

// RedditWebSignInPopupViewController - a Google / Apple sign-in popup opened by Reddit's login page
class RedditWebSignInPopupViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    private var webView: WKWebView?
    private let spinner = UIActivityIndicatorView(style: .medium)

    // Returns the popup's web view for WebKit to load the request into, or nil to drop the request
    static func presentPopup(from presenter: UIViewController, configuration: WKWebViewConfiguration, navigationAction: WKNavigationAction) -> WKWebView? {
        // Only while nothing covers the sign-in sheet; closePopups relies on the popup sitting directly on it
        let host = presenter.navigationController ?? presenter
        guard host.view.window != nil, !host.isBeingDismissed, host.presentedViewController == nil else {
            return nil
        }

        let popup = RedditWebSignInPopupViewController()
        // WebKit requires exactly this configuration (same process pool and data store as the opener)
        let webView = WKWebView(frame: .zero, configuration: configuration)
        // Google can refuse an embedded web view's default UA; the provider page gets Safari's
        webView.customUserAgent = RedditWebSignInPopupViewController.mobileSafariUserAgent
        webView.uiDelegate = popup
        webView.navigationDelegate = popup
        popup.webView = webView
        popup.title = navigationAction.request.url?.host ?? "Sign In"

        let navigationController = UINavigationController(rootViewController: popup)
        navigationController.modalPresentationStyle = .formSheet
        host.present(navigationController, animated: true)
        return webView
    }

    // Closes a popup still open above the sign-in sheet, then runs `then`
    static func closePopups(above signIn: UIViewController, then: @escaping () -> Void) {
        let sheet = signIn.navigationController ?? signIn
        guard let above = sheet.presentedViewController as? UINavigationController,
              above.viewControllers.first is RedditWebSignInPopupViewController else {
            then()
            return
        }
        if above.isBeingDismissed, let coordinator = above.transitionCoordinator {
            // Already closing; UIKit ignores a second dismiss mid-animation
            coordinator.animate(alongsideTransition: nil) { _ in
                DispatchQueue.main.async(execute: then)
            }
            return
        }
        sheet.dismiss(animated: false, completion: then)
    }

    static var mobileSafariUserAgent: String {
        let parts = UIDevice.current.systemVersion.split(separator: ".")
        let major = parts.first.map(String.init) ?? "18"
        let minor = parts.count > 1 ? String(parts[1]) : "0"
        let platform = UIDevice.current.userInterfaceIdiom == .pad
            ? "iPad; CPU OS \(major)_\(minor) like Mac OS X"
            : "iPhone; CPU iPhone OS \(major)_\(minor) like Mac OS X"
        return "Mozilla/5.0 (\(platform)) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/\(major).\(minor) Mobile/15E148 Safari/604.1"
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .systemBackground
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        if let webView = self.webView {
            webView.frame = self.view.bounds
            webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            self.view.addSubview(webView)
        }
        self.spinner.center = CGPoint(x: self.view.bounds.midX, y: self.view.bounds.midY)
        self.spinner.autoresizingMask = [.flexibleTopMargin, .flexibleBottomMargin, .flexibleLeftMargin, .flexibleRightMargin]
        self.view.addSubview(self.spinner)
        if self.webView?.isLoading == true {
            self.spinner.startAnimating()
        }
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Releasing the web view closes the popup's page, so the opener sees window.closed
        if self.navigationController?.isBeingDismissed == true || self.isBeingDismissed {
            self.tearDownWebView()
        }
    }

    deinit {
        self.webView?.stopLoading()
    }

    private func tearDownWebView() {
        guard let webView = self.webView else { return }
        webView.uiDelegate = nil
        webView.navigationDelegate = nil
        webView.stopLoading()
        webView.removeFromSuperview()
        self.webView = nil
    }

    @objc private func cancelTapped() {
        self.close()
    }

    private func close() {
        guard self.navigationController?.isBeingDismissed != true else { return }
        self.dismiss(animated: true)
    }

    // Google and Apple call window.close() once the result is posted back to the opener
    func webViewDidClose(_ webView: WKWebView) {
        self.close()
    }

    // Help/privacy links asking for yet another window would replace the page the opener waits on
    func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
        return nil
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        self.spinner.startAnimating()
    }

    // The title shows the host the popup is on, as Safari's address bar would
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let host = webView.url?.host, !host.isEmpty {
            self.title = host
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        self.spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        self.spinner.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        self.spinner.stopAnimating()
    }
}
