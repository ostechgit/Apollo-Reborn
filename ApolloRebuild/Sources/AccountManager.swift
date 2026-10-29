import Foundation

// AccountManager - manages Reddit user accounts
// Reconstructed from apollo-base 1.15.11 binary analysis.

// RedditAPICredentials - the Reddit app the user signs in through.
// Reddit no longer hands out a shared key, so (as in Apollo Reborn) the client ID
// and redirect URI are entered by the user and must match their Reddit app exactly.
struct RedditAPICredentials {
    
    static let defaultRedirectURI = "apollo://reddit-oauth"
    
    // Apollo Reborn's default User-Agent for Reddit requests (Defaults.m defaultUserAgent),
    // the one known to work with user API keys; overridable like Reborn's User Agent setting
    static let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36"
    
    private static let clientIDKey = "redditClientID"
    private static let clientSecretKey = "redditClientSecret"
    private static let redirectURIKey = "redditRedirectURI"
    private static let userAgentKey = "redditUserAgent"
    
    static var clientID: String {
        get { return UserDefaults.standard.string(forKey: clientIDKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: clientIDKey) }
    }
    
    // Empty for "installed app" keys, which have no secret
    static var clientSecret: String {
        get { return UserDefaults.standard.string(forKey: clientSecretKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: clientSecretKey) }
    }
    
    static var redirectURI: String {
        get {
            let saved = UserDefaults.standard.string(forKey: redirectURIKey) ?? ""
            return saved.isEmpty ? defaultRedirectURI : saved
        }
        set { UserDefaults.standard.set(newValue, forKey: redirectURIKey) }
    }
    
    // Empty means defaultUserAgent
    static var customUserAgent: String {
        get { return UserDefaults.standard.string(forKey: userAgentKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userAgentKey) }
    }
    
    static var userAgent: String {
        return customUserAgent.isEmpty ? defaultUserAgent : customUserAgent
    }
    
    static var isConfigured: Bool {
        return !clientID.isEmpty
    }
}

class AccountManager {
    
    static let shared = AccountManager()
    
    // Posted on sign-in and sign-out so open screens can refresh
    static let accountDidChangeNotification = Notification.Name("AccountManagerAccountDidChange")
    
    private var currentUsername: String?
    private let defaults = UserDefaults.standard
    
    private init() {
        // Load saved account
        self.currentUsername = defaults.string(forKey: "redditUsername")
        
        // The old password-grant login stored the password in plain text; drop anything it left behind,
        // along with the tokens ServerBuddy used to keep before RDKClient took over
        for key in ["redditPassword", "redditLoggedIn", "redditAccessToken", "redditRefreshToken", "redditTokenExpiry"] {
            defaults.removeObject(forKey: key)
        }
        
        self.configureClient()
    }
    
    // Points RDKClient at the user's Reddit app. Call again after the credentials change.
    func configureClient() {
        let client = RDKClient.shared()
        client.userAgent = RedditAPICredentials.userAgent
        guard RedditAPICredentials.isConfigured else { return }
        client.clientSecret = RedditAPICredentials.clientSecret
        client.authenticate(withClientIdentifier: RedditAPICredentials.clientID, redirectURI: URL(string: RedditAPICredentials.redirectURI))
        
        // A token for a different Reddit app was just dropped
        if !client.isAuthenticatedWithOAuth && self.currentUsername != nil {
            self.forgetAccount()
        }
    }
    
    // Finishes the OAuth sign-in: trades the authorization code from Reddit's
    // redirect for tokens, then looks up which account just signed in.
    func signIn(authorizationCode: String, completion: @escaping (Bool) -> Void) {
        let client = RDKClient.shared()
        client.signIn(withAuthorizationCode: authorizationCode) { error in
            if let error = error {
                LogBuddy.error("AccountManager: code exchange failed (\((error as NSError).code))")
                completion(false)
                return
            }
            
            client.currentUser { user, error in
                guard let username = (user as? [String: Any])?["name"] as? String else {
                    LogBuddy.error("AccountManager: /api/v1/me failed after sign-in")
                    client.signOut(completion: nil)
                    completion(false)
                    return
                }
                
                self.currentUsername = username
                self.defaults.set(username, forKey: "redditUsername")
                LogBuddy.info("AccountManager: signed in")
                NotificationCenter.default.post(name: AccountManager.accountDidChangeNotification, object: self)
                completion(true)
            }
        }
    }
    
    func logout() {
        RDKClient.shared().signOut(completion: nil)
        self.forgetAccount()
    }
    
    private func forgetAccount() {
        self.currentUsername = nil
        
        // Clear saved account
        self.defaults.removeObject(forKey: "redditUsername")
        NotificationCenter.default.post(name: AccountManager.accountDidChangeNotification, object: self)
    }
    
    var isLogged: Bool {
        return self.currentUsername != nil && RDKClient.shared().isAuthenticatedWithOAuth
    }
    
    var username: String? {
        return self.isLogged ? self.currentUsername : nil
    }
}
