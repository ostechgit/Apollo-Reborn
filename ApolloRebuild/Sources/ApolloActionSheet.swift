import UIKit

// ApolloActionSheet - Apollo's own action sheet.
//
// Reconstructed from Apollo 1.15.11. The original is `ActionController`
// (0x1007a05f0) plus `ActionControllerPresentationController` (0x1004ca9dc).
// Established facts this file follows:
//   * custom presentation, bottom-flush, 10pt side margins, 13pt corners,
//     414pt maximum width (0x1004ca9dc);
//   * rows are 57pt, icon gutter 66pt, title 20pt regular, title width
//     min(fit, width - 66 - 50), accessory inset 15pt (0x100171f7c);
//   * separator inset left 66; no group dividers, one section;
//   * a separate "Cancel" button 57pt tall with an 8pt gap below the list,
//     corner radius 13, 20pt semibold (0x100796324);
//   * height: at most 90% of the safe area, capped at 484.5pt of list once
//     there are 9+ rows (0x1004cade0);
//   * the action runs after the dismissal completes, not before
//     (0x10079ef48).
//
// NOT established: the animator's curve/spring and its start offset (the
// animator bodies are Swift witness glue), the cell reuse identifiers, and
// whether UIKit contributes any backdrop treatment. This uses a plain 0.4s
// slide, the only duration the original pins down (0x1007a00f4).

struct ApolloActionSheetItem {
    enum Accessory {
        case none
        case checkmark
        case disclosure
    }

    let title: String
    let image: UIImage?
    var subtitle: String? = nil
    var accessory: Accessory = .none
    var isEnabled: Bool = true
    let handler: () -> Void
}

final class ApolloActionSheetViewController: UIViewController {

    private let items: [ApolloActionSheetItem]

    /// Read by the presentation controller before layout.
    var itemCount: Int { self.items.count }
    private let cancelTitle: String
    private let cancelAction: (() -> Void)?
    private let tableView = UITableView(frame: .zero, style: .plain)
    private let cancelButton = UIButton(type: .custom)

    /// Native constants, kept named so the layout reads like the original.
    private static let sideMargin: CGFloat = 10
    private static let maximumWidth: CGFloat = 414
    private static let cornerRadius: CGFloat = 13
    private static let rowHeight: CGFloat = 57
    private static let iconGutter: CGFloat = 66
    private static let cancelGap: CGFloat = 8
    private static let listCap: CGFloat = 484.5
    private static let overflowAdjustment: CGFloat = 28.5
    private static let availableFraction: CGFloat = 0.9

    init(items: [ApolloActionSheetItem], cancelTitle: String = "Cancel",
         cancelAction: (() -> Void)? = nil) {
        self.items = items
        self.cancelTitle = cancelTitle
        self.cancelAction = cancelAction
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .custom
        self.transitioningDelegate = self
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .clear

        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.rowHeight = Self.rowHeight
        self.tableView.separatorInset = UIEdgeInsets(top: 0, left: Self.iconGutter, bottom: 0, right: 0)
        self.tableView.separatorColor = .separator
        self.tableView.showsVerticalScrollIndicator = false
        self.tableView.alwaysBounceVertical = false
        self.tableView.register(ApolloActionSheetCell.self, forCellReuseIdentifier: "action")
        self.tableView.tableFooterView = UIView(frame: .zero)
        self.tableView.layer.cornerRadius = Self.cornerRadius
        self.tableView.layer.masksToBounds = true
        self.tableView.backgroundColor = .systemBackground
        self.view.addSubview(self.tableView)

        self.cancelButton.setTitle(self.cancelTitle, for: .normal)
        self.cancelButton.titleLabel?.font = .systemFont(ofSize: 20, weight: .semibold)
        self.cancelButton.setTitleColor(.label, for: .normal)
        self.cancelButton.backgroundColor = .systemBackground
        self.cancelButton.layer.cornerRadius = Self.cornerRadius
        self.cancelButton.layer.masksToBounds = true
        self.cancelButton.addAction(UIAction { [weak self] _ in
            self?.dismiss(animated: true) { self?.cancelAction?() }
        }, for: .touchUpInside)
        self.view.addSubview(self.cancelButton)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let bounds = self.view.bounds
        // Native: table (0, 0, W, H - 65); cancel (0, H - 57, W, 57).
        let cancelTop = bounds.height - Self.rowHeight
        self.cancelButton.frame = CGRect(x: 0, y: cancelTop, width: bounds.width, height: Self.rowHeight)
        self.tableView.frame = CGRect(x: 0, y: 0, width: bounds.width,
                                      height: cancelTop - Self.cancelGap)
    }

}

extension ApolloActionSheetViewController: UITableViewDataSource, UITableViewDelegate {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "action", for: indexPath)
        guard let cell = cell as? ApolloActionSheetCell else { return cell }
        let item = self.items[indexPath.row]
        cell.configure(title: item.title, image: item.image, subtitle: item.subtitle,
                       accessory: item.accessory, isEnabled: item.isEnabled)
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        // Native runs the action in the dismissal completion.
        let handler = self.items[indexPath.row].handler
        self.dismiss(animated: true) { handler() }
    }
}

// ApolloActionSheetCell - 57pt icon + title row.
final class ApolloActionSheetCell: UITableViewCell {

    private let iconView = UIImageView()
    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let sheetAccessoryView = UIImageView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        self.backgroundColor = .systemBackground
        self.contentView.backgroundColor = .clear

        self.iconView.contentMode = .scaleAspectFit
        self.iconView.translatesAutoresizingMaskIntoConstraints = false
        self.titleLabel.font = .systemFont(ofSize: 20, weight: .regular)
        self.titleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.subtitleLabel.font = .systemFont(ofSize: 14)
        self.subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        self.sheetAccessoryView.contentMode = .scaleAspectFit
        self.sheetAccessoryView.tintColor = UIColor(white: 0.78, alpha: 1)
        self.sheetAccessoryView.translatesAutoresizingMaskIntoConstraints = false

        self.contentView.addSubview(self.iconView)
        self.contentView.addSubview(self.titleLabel)
        self.contentView.addSubview(self.subtitleLabel)
        self.contentView.addSubview(self.sheetAccessoryView)

        NSLayoutConstraint.activate([
            self.iconView.centerXAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 33),
            self.iconView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor),
            self.iconView.widthAnchor.constraint(lessThanOrEqualToConstant: 24),
            self.iconView.heightAnchor.constraint(lessThanOrEqualToConstant: 24),
            self.titleLabel.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 66),
            self.subtitleLabel.leadingAnchor.constraint(equalTo: self.titleLabel.leadingAnchor),
            self.sheetAccessoryView.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -15),
            self.sheetAccessoryView.centerYAnchor.constraint(equalTo: self.contentView.centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(title: String, image: UIImage?, subtitle: String?,
                   accessory: ApolloActionSheetItem.Accessory, isEnabled: Bool) {
        self.titleLabel.text = title
        self.iconView.image = image?.withRenderingMode(.alwaysTemplate)
        self.subtitleLabel.text = subtitle
        // Native: disabled rows use the theme's tertiary colour; every other
        // icon row uses the normal text colour (destructive red is only used
        // by the text-action cell, which these menus do not use).
        let tint = isEnabled ? UIColor.label : UIColor.tertiaryLabel
        self.titleLabel.textColor = tint
        self.iconView.tintColor = tint
        self.iconView.isHidden = (image == nil)

        let symbol: String?
        switch accessory {
        case .none: symbol = nil
        case .checkmark: symbol = "checkmark"
        case .disclosure: symbol = "chevron.right"
        }
        self.sheetAccessoryView.image = symbol.flatMap { UIImage(systemName: $0) }
        self.sheetAccessoryView.isHidden = (symbol == nil)

        // Native lays the title slightly above centre when a subtitle exists.
        self.subtitleLabel.isHidden = (subtitle == nil)
        self.titleLabel.isHidden = false
        self.setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let hasSubtitle = !self.subtitleLabel.isHidden
        let width = self.contentView.bounds.width - 66 - 50
        let titleHeight = self.titleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        let subtitleHeight = self.subtitleLabel.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height
        if hasSubtitle {
            self.titleLabel.frame = CGRect(x: 66, y: 7, width: width, height: titleHeight)
            self.subtitleLabel.frame = CGRect(x: 66, y: self.titleLabel.frame.maxY + 1,
                                              width: width, height: subtitleHeight)
        } else {
            self.titleLabel.frame = CGRect(x: 66, y: (self.contentView.bounds.height - titleHeight) / 2,
                                           width: width, height: titleHeight)
            self.subtitleLabel.frame = .zero
        }
    }
}

// MARK: - Presentation

extension ApolloActionSheetViewController: UIViewControllerTransitioningDelegate {

    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return ApolloActionSheetPresentationController(presentedViewController: presented,
                                                      presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ApolloActionSheetAnimator(presenting: true)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ApolloActionSheetAnimator(presenting: false)
    }
}

final class ApolloActionSheetPresentationController: UIPresentationController {

    /// Native frame (0x1004ca9dc): bottom-flush, 10pt margins, max 414pt wide.
    override var frameOfPresentedViewInContainerView: CGRect {
        guard let container = self.containerView else { return .zero }
        let width = min(container.bounds.width - 20, 414)
        let height = (self.presentedViewController as? ApolloActionSheetViewController)?
            .preferredHeight(in: container.bounds, safeInsets: container.safeAreaInsets)
            ?? container.bounds.height * 0.5
        return CGRect(x: (container.bounds.width - width) / 2,
                      y: container.bounds.height - height,
                      width: width, height: height)
    }

    override func containerViewWillLayoutSubviews() {
        super.containerViewWillLayoutSubviews()
        self.presentedView?.frame = self.frameOfPresentedViewInContainerView
    }
}

final class ApolloActionSheetAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    private let presenting: Bool

    init(presenting: Bool) {
        self.presenting = presenting
        super.init()
    }

    func transitionDuration(using context: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.4   // native animator duration (0x1007a00f4)
    }

    func animateTransition(using context: UIViewControllerContextTransitioning) {
        let duration = self.transitionDuration(using: context)
        let container = context.containerView
        if self.presenting {
            guard let to = context.view(forKey: .to),
                  let controller = context.viewController(forKey: .to) as? ApolloActionSheetViewController else {
                context.completeTransition(false)
                return
            }
            let width = min(container.bounds.width - 20, 414)
            let height = controller.preferredHeight(in: container.bounds, safeInsets: container.safeAreaInsets)
            let frame = CGRect(x: (container.bounds.width - width) / 2,
                               y: container.bounds.height - height,
                               width: width, height: height)
            to.frame = frame.offsetBy(dx: 0, dy: frame.height)
            container.addSubview(to)
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseOut]) {
                to.frame = frame
            } completion: { _ in
                context.completeTransition(!context.transitionWasCancelled)
            }
        } else if let from = context.view(forKey: .from) {
            UIView.animate(withDuration: duration, delay: 0, options: [.curveEaseIn]) {
                from.frame = from.frame.offsetBy(dx: 0, dy: from.frame.height)
            } completion: { _ in
                from.removeFromSuperview()
                context.completeTransition(!context.transitionWasCancelled)
            }
        } else {
            context.completeTransition(false)
        }
    }
}

extension ApolloActionSheetViewController {
    /// Exposed for the presentation controller, which must know the sheet
    /// height before the view controller is laid out.
    func preferredHeight(in container: CGRect, safeInsets: UIEdgeInsets) -> CGFloat {
        let available = ceil((container.height - safeInsets.top - safeInsets.bottom) * 0.9)
        let cancelExtra: CGFloat = 65          // 57pt button + 8pt gap
        let tableHeight = CGFloat(self.itemCount) * 57
        if tableHeight > available { return available - 28.5 + cancelExtra }
        if self.itemCount >= 9 { return 484.5 + cancelExtra }
        return tableHeight + cancelExtra
    }
}
