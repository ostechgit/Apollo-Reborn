import UIKit

// DualLabelTitleButton - the button Apollo puts in a screen's navigation title.
// Reconstructed from apollo-base 1.15.11 binary analysis
// (Apollo.DualLabelTitleButton): a UIButton with a `primaryTitle` and an
// optional `subtitle`.
//
// On the feed it shows the feed's name and a small chevron, and tapping it
// opens the feed/sort menu; iOS 26 draws the glass capsule around it. A screen
// that has a subtitle (a subreddit's subscriber count, say) shows it under the
// primary title in small grey type.
class DualLabelTitleButton: UIButton {

    var primaryTitle: String? {
        didSet { self.applyConfiguration() }
    }

    var subtitle: String? {
        didSet { self.applyConfiguration() }
    }

    /// The chevron is what tells the person the title opens a menu.
    var showsChevron: Bool = true {
        didSet { self.applyConfiguration() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.showsMenuAsPrimaryAction = true
        self.applyConfiguration()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.showsMenuAsPrimaryAction = true
        self.applyConfiguration()
    }

    private func applyConfiguration() {
        var configuration = UIButton.Configuration.plain()
        configuration.title = self.primaryTitle
        // The original's chevron is small and grey, not the tinted system one.
        let chevron = UIImage(systemName: "chevron.down",
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .medium))?
            .withTintColor(.tertiaryLabel, renderingMode: .alwaysOriginal)
        configuration.image = self.showsChevron ? chevron : nil
        configuration.imagePlacement = .trailing
        configuration.imagePadding = 6
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 9, leading: 14, bottom: 9, trailing: 12)
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = UIFont.systemFont(ofSize: 17, weight: .semibold)
            outgoing.foregroundColor = .label
            return outgoing
        }
        self.configuration = configuration
    }
}
