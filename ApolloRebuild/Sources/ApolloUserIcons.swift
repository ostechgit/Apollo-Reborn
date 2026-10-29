import UIKit

// ApolloUserIcons - the author avatars on a post's byline.
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// The 22pt disc before a post's author is the AUTHOR's own Reddit profile icon,
// not the subreddit's avatar: two posts from the same subreddit by different
// authors show different discs. The listing itself carries no image, so Apollo
// looks the authors up in bulk through
// `api/user_data_by_account_ids.json?ids=t2_…,t2_…` and reads each account's
// `profile_img` (the snoovatar headshot). Requests are debounced so a page's
// worth of cells becomes one round trip, and results are cached for the session.
final class ApolloUserIcons {

    static let shared = ApolloUserIcons()

    /// How long to wait before asking, so all the cells laid out in one pass land
    /// in the same request.
    private static let debounce: TimeInterval = 0.15

    private let lock = NSLock()
    private var icons: [String: URL] = [:]
    private var pending: Set<String> = []
    private var waiting: [String: [(URL?) -> Void]] = [:]
    private var failed: Set<String> = []
    private var flushScheduled = false

    /// Ask for one author's icon. The block runs on the main thread: now if the
    /// icon is already known, otherwise once the batch returns.
    func icon(forAccount fullName: String?, completion: @escaping (URL?) -> Void) {
        guard let fullName = fullName, !fullName.isEmpty else {
            completion(nil)
            return
        }

        var cached: URL?
        var isKnown = false
        var scheduleFlush = false
        self.lock.lock()
        if let url = self.icons[fullName] {
            cached = url
            isKnown = true
        } else if self.failed.contains(fullName) {
            isKnown = true
        } else {
            self.waiting[fullName, default: []].append(completion)
            self.pending.insert(fullName)
            if !self.flushScheduled {
                self.flushScheduled = true
                scheduleFlush = true
            }
        }
        self.lock.unlock()

        if isKnown {
            completion(cached)
            return
        }
        if scheduleFlush {
            DispatchQueue.main.asyncAfter(deadline: .now() + ApolloUserIcons.debounce) { [weak self] in
                self?.flush()
            }
        }
    }

    /// Seed a known icon (the signed-in account's own, for instance) so it never
    /// needs a request.
    func cache(url: URL, forAccount fullName: String) {
        self.lock.lock()
        self.icons[fullName] = url
        self.lock.unlock()
    }

    // MARK: - Batching

    /// One request for everything asked for during the debounce window.
    private func flush() {
        var batch: [String] = []
        self.lock.lock()
        batch = Array(self.pending)
        self.pending.removeAll()
        self.flushScheduled = false
        self.lock.unlock()

        guard !batch.isEmpty else { return }

        RDKClient.shared().userIcons(forAccountFullNames: batch) { icons, _ in
            var urlFor: [String: URL] = [:]
            var blocksFor: [String: [(URL?) -> Void]] = [:]
            self.lock.lock()
            for name in batch {
                if let string = icons?[name], let url = URL(string: string) {
                    self.icons[name] = url
                    urlFor[name] = url
                } else {
                    // A user without a profile icon keeps the neutral placeholder
                    // and isn't asked for again this session.
                    self.failed.insert(name)
                }
                if let blocks = self.waiting.removeValue(forKey: name) {
                    blocksFor[name] = blocks
                }
            }
            self.lock.unlock()

            var callbacks: [() -> Void] = []
            for (name, blocks) in blocksFor {
                let url = urlFor[name]
                for block in blocks {
                    callbacks.append { block(url) }
                }
            }
            guard !callbacks.isEmpty else { return }
            DispatchQueue.main.async {
                for callback in callbacks { callback() }
            }
        }
    }
}
