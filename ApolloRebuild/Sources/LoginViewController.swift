import UIKit

// LoginViewController - signs in to Reddit through OAuth
// The user's own Reddit app (client ID + redirect URI, as in Apollo Reborn's
// Accounts & API Keys settings) drives Reddit's consent page in
// RedditWebSignInViewController; the authorization code from the redirect is
// traded for tokens by AccountManager/RDKClient.

class LoginViewController: UIViewController, UITextFieldDelegate {

    private let scrollView = UIScrollView()
    private let clientIDField = UITextField()
    private let clientSecretField = UITextField()
    private let redirectURIField = UITextField()
    private let userAgentField = UITextField()
    private let signInButton = UIButton(type: .system)

    private var expectedState: String?

    private var isSigningIn = false {
        didSet {
            self.signInButton.configuration?.showsActivityIndicator = self.isSigningIn
            self.signInButton.isEnabled = !self.isSigningIn
            self.isModalInPresentation = self.isSigningIn
        }
    }

    // Presents the sign-in screen as a sheet over `presenter`
    static func present(from presenter: UIViewController) {
        let navigationController = UINavigationController(rootViewController: LoginViewController())
        navigationController.modalPresentationStyle = .formSheet
        presenter.present(navigationController, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = "Sign In"
        self.view.backgroundColor = UIColor.systemBackground
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))

        self.scrollView.keyboardDismissMode = .interactive
        self.scrollView.alwaysBounceVertical = true
        self.view.addSubview(self.scrollView)
        self.scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.scrollView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.scrollView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.scrollView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.scrollView.bottomAnchor.constraint(equalTo: self.view.keyboardLayoutGuide.topAnchor)
        ])

        let iconView = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        iconView.tintColor = self.view.tintColor
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56)

        let titleLabel = UILabel()
        titleLabel.text = "Sign in with Reddit"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title2).withTraits(.traitBold)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0

        let messageLabel = UILabel()
        messageLabel.text = "Apollo signs in through your own Reddit app. Create an \u{201C}installed app\u{201D} at reddit.com/prefs/apps with the redirect URI below, then paste its client ID here."
        messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        self.configureField(self.clientIDField, placeholder: "Client ID", text: RedditAPICredentials.clientID)
        self.configureField(self.clientSecretField, placeholder: "Leave empty for installed apps", text: RedditAPICredentials.clientSecret)
        self.configureField(self.redirectURIField, placeholder: RedditAPICredentials.defaultRedirectURI, text: RedditAPICredentials.redirectURI)
        self.redirectURIField.keyboardType = .URL
        // Empty means Reborn's default; show that default as the placeholder
        self.configureField(self.userAgentField, placeholder: RedditAPICredentials.defaultUserAgent, text: RedditAPICredentials.customUserAgent)
        self.userAgentField.returnKeyType = .go

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Continue to Reddit"
        buttonConfiguration.cornerStyle = .large
        buttonConfiguration.buttonSize = .large
        buttonConfiguration.imagePadding = 8
        self.signInButton.configuration = buttonConfiguration
        self.signInButton.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)

        var appsButtonConfiguration = UIButton.Configuration.plain()
        appsButtonConfiguration.title = "Open reddit.com/prefs/apps"
        let appsButton = UIButton(configuration: appsButtonConfiguration)
        appsButton.addTarget(self, action: #selector(openRedditAppsTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            iconView,
            titleLabel,
            messageLabel,
            self.labeledField("Client ID", self.clientIDField),
            self.labeledField("Client Secret (optional)", self.clientSecretField),
            self.labeledField("Redirect URI", self.redirectURIField),
            self.labeledField("User Agent (optional)", self.userAgentField),
            self.signInButton,
            appsButton
        ])
        stackView.axis = .vertical
        stackView.spacing = 16
        stackView.setCustomSpacing(8, after: iconView)
        stackView.setCustomSpacing(8, after: titleLabel)
        stackView.setCustomSpacing(24, after: messageLabel)
        stackView.setCustomSpacing(24, after: stackView.arrangedSubviews[6])
        stackView.setCustomSpacing(4, after: self.signInButton)
        self.scrollView.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        let content = self.scrollView.contentLayoutGuide
        let readable = self.view.readableContentGuide
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: content.topAnchor, constant: 24),
            stackView.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -24),
            stackView.leadingAnchor.constraint(equalTo: readable.leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: readable.trailingAnchor)
        ])
    }

    // MARK: - Layout helpers

    private func configureField(_ field: UITextField, placeholder: String, text: String) {
        field.placeholder = placeholder
        field.text = text
        field.borderStyle = .roundedRect
        field.autocapitalizationType = .none
        field.autocorrectionType = .no
        field.spellCheckingType = .no
        field.smartDashesType = .no
        field.smartQuotesType = .no
        field.clearButtonMode = .whileEditing
        field.returnKeyType = .next
        field.font = UIFont.preferredFont(forTextStyle: .body)
        field.adjustsFontForContentSizeCategory = true
        field.delegate = self
        field.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func labeledField(_ title: String, _ field: UITextField) -> UIView {
        let label = UILabel()
        label.text = title
        label.font = UIFont.preferredFont(forTextStyle: .footnote)
        label.textColor = UIColor.secondaryLabel

        let stackView = UIStackView(arrangedSubviews: [label, field])
        stackView.axis = .vertical
        stackView.spacing = 6
        return stackView
    }

    // MARK: - UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField === self.clientIDField {
            self.clientSecretField.becomeFirstResponder()
        } else if textField === self.clientSecretField {
            self.redirectURIField.becomeFirstResponder()
        } else if textField === self.redirectURIField {
            self.userAgentField.becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            self.signInTapped()
        }
        return true
    }

    // MARK: - Actions

    @objc private func cancelTapped() {
        self.dismiss(animated: true)
    }

    @objc private func openRedditAppsTapped() {
        UIApplication.shared.open(URL(string: "https://www.reddit.com/prefs/apps")!)
    }

    @objc private func signInTapped() {
        guard !self.isSigningIn else { return }
        self.view.endEditing(true)

        let clientID = self.trimmed(self.clientIDField)
        let clientSecret = self.trimmed(self.clientSecretField)
        let redirectInput = self.trimmed(self.redirectURIField)
        let redirectURI = redirectInput.isEmpty ? RedditAPICredentials.defaultRedirectURI : redirectInput
        let userAgent = self.trimmed(self.userAgentField)

        guard !clientID.isEmpty else {
            self.showError(title: "Client ID Needed", message: "Paste the client ID of your Reddit app. It\u{2019}s the string shown under the app\u{2019}s name at reddit.com/prefs/apps.")
            return
        }

        // Custom schemes (installed apps) and http/https (web apps, which need a host) both work,
        // since the web sign-in matches the whole redirect URI
        guard let redirect = URL(string: redirectURI), let scheme = redirect.scheme?.lowercased(),
              (scheme != "http" && scheme != "https") || redirect.host?.isEmpty == false else {
            self.showError(title: "Unsupported Redirect URI", message: "Enter the redirect URI exactly as it appears on your Reddit app, such as \(RedditAPICredentials.defaultRedirectURI).")
            return
        }

        RedditAPICredentials.clientID = clientID
        RedditAPICredentials.clientSecret = clientSecret
        RedditAPICredentials.redirectURI = redirectURI
        RedditAPICredentials.customUserAgent = userAgent
        AccountManager.shared.configureClient()

        let state = UUID().uuidString
        guard let authorizationURL = RDKClient.shared().authorizationURL(withState: state) else {
            self.showError(title: "Couldn\u{2019}t Start Sign In", message: "The client ID or redirect URI couldn\u{2019}t be turned into a Reddit sign-in link.")
            return
        }

        self.expectedState = state
        self.isSigningIn = true
        RedditWebSignInViewController.present(from: self, authURL: authorizationURL, redirectURI: redirectURI) { [weak self] callbackURL, error in
            self?.handleAuthorizationCallback(callbackURL, error: error)
        }
    }

    // MARK: - OAuth callback

    private func handleAuthorizationCallback(_ callbackURL: URL?, error: Error?) {
        if let error = error {
            self.isSigningIn = false
            if case RedditWebSignInError.cancelled = error {
                return
            }
            LogBuddy.error("LoginViewController: web authentication failed (\((error as NSError).domain) \((error as NSError).code))")
            self.showError(title: "Sign In Failed", message: error.localizedDescription)
            return
        }

        let queryItems = callbackURL.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false)?.queryItems } ?? []
        let value = { (name: String) in queryItems.first { $0.name == name }?.value }

        guard value("state") == self.expectedState else {
            self.isSigningIn = false
            LogBuddy.error("LoginViewController: OAuth state mismatch")
            self.showError(title: "Sign In Failed", message: "Reddit\u{2019}s response didn\u{2019}t match this sign-in attempt. Please try again.")
            return
        }

        if let oauthError = value("error") {
            self.isSigningIn = false
            if oauthError == "access_denied" {
                self.showError(title: "Access Declined", message: "Apollo needs you to allow access on Reddit\u{2019}s page to sign in.")
            } else {
                self.showError(title: "Reddit Rejected the Sign In", message: "Reddit returned \u{201C}\(oauthError)\u{201D}. Check that the client ID and redirect URI match your Reddit app exactly.")
            }
            return
        }

        guard let code = value("code") else {
            self.isSigningIn = false
            self.showError(title: "Sign In Failed", message: "Reddit didn\u{2019}t send back an authorization code.")
            return
        }

        AccountManager.shared.signIn(authorizationCode: code) { [weak self] success in
            guard let self = self else { return }
            self.isSigningIn = false

            if success {
                self.dismiss(animated: true)
            } else {
                self.showError(title: "Sign In Failed", message: "Reddit didn\u{2019}t accept the sign in. If your Reddit app is a \u{201C}web app\u{201D}, enter its secret; installed apps leave it empty.")
            }
        }
    }

    // MARK: - Helpers

    private func trimmed(_ field: UITextField) -> String {
        return (field.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func showError(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        self.present(alert, animated: true)
    }
}

// SignInPromptView - the signed-out placeholder shown by account-only screens
class SignInPromptView: UIView {

    private let onSignIn: () -> Void

    init(message: String, onSignIn: @escaping () -> Void) {
        self.onSignIn = onSignIn
        super.init(frame: .zero)

        let iconView = UIImageView(image: UIImage(systemName: "person.crop.circle"))
        iconView.tintColor = UIColor.tertiaryLabel
        iconView.contentMode = .scaleAspectFit
        iconView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 56, weight: .light)

        let titleLabel = UILabel()
        titleLabel.text = "Not Signed In"
        titleLabel.font = UIFont.preferredFont(forTextStyle: .title3).withTraits(.traitBold)
        titleLabel.textAlignment = .center

        let messageLabel = UILabel()
        messageLabel.text = message
        messageLabel.font = UIFont.preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = UIColor.secondaryLabel
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.title = "Sign In"
        buttonConfiguration.cornerStyle = .capsule
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 28, bottom: 10, trailing: 28)
        let button = UIButton(configuration: buttonConfiguration)
        button.addTarget(self, action: #selector(signInTapped), for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [iconView, titleLabel, messageLabel, button])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = 8
        stackView.setCustomSpacing(20, after: messageLabel)
        self.addSubview(stackView)

        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: self.safeAreaLayoutGuide.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: self.readableContentGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: self.readableContentGuide.trailingAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func signInTapped() {
        self.onSignIn()
    }
}

private extension UIFont {
    func withTraits(_ traits: UIFontDescriptor.SymbolicTraits) -> UIFont {
        guard let descriptor = self.fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: 0)
    }
}
