import UIKit

// Holla - status toast notifications
// Reconstructed from apollo-base 1.15.11 binary analysis.
//
// Original function signatures recovered from RE:
// - showStatus(_:text:duration:savedItemFullName:fromViewController:tappedBlock:)
// - HollaSavedItemStatusView class

class Holla {
    
    // Show a status toast notification
    // title: The main title of the toast
    // text: Optional subtitle text
    // duration: How long to show the toast (in seconds)
    // savedItemFullName: If set, shows a "View" button that opens the item
    // fromViewController: The view controller to present from
    // tappedBlock: Called when the toast is tapped
    static func showStatus(_ title: String,
                          text: String? = nil,
                          duration: TimeInterval = 3.0,
                          savedItemFullName: String? = nil,
                          fromViewController viewController: UIViewController,
                          tappedBlock: (() -> Void)? = nil) {
        
        // Create the toast view
        let toastView = HollaSavedItemStatusView()
        toastView.title = title
        toastView.text = text
        toastView.savedItemFullName = savedItemFullName
        toastView.tappedBlock = tappedBlock
        
        // Add to the view controller's view
        toastView.translatesAutoresizingMaskIntoConstraints = false
        viewController.view.addSubview(toastView)
        
        // Position at the bottom of the screen
        let safeAreaBottom = viewController.view.safeAreaLayoutGuide.bottomAnchor
        NSLayoutConstraint.activate([
            toastView.leadingAnchor.constraint(equalTo: viewController.view.leadingAnchor, constant: 16),
            toastView.trailingAnchor.constraint(equalTo: viewController.view.trailingAnchor, constant: -16),
            toastView.bottomAnchor.constraint(equalTo: safeAreaBottom, constant: -16)
        ])
        
        // Animate in
        toastView.alpha = 0
        toastView.transform = CGAffineTransform(translationX: 0, y: 50)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) {
            toastView.alpha = 1
            toastView.transform = .identity
        }
        
        // Auto-dismiss after duration
        DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
            self.dismiss(toastView: toastView)
        }
    }
    
    // Dismiss a toast view
    private static func dismiss(toastView: UIView) {
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseIn) {
            toastView.alpha = 0
            toastView.transform = CGAffineTransform(translationX: 0, y: 50)
        } completion: { _ in
            toastView.removeFromSuperview()
        }
    }
}

// The toast view itself
class HollaSavedItemStatusView: UIView {
    
    var title: String = "" {
        didSet { titleLabel.text = title }
    }
    
    var text: String? = nil {
        didSet {
            if let text = text {
                subtitleLabel.text = text
                subtitleLabel.isHidden = false
            } else {
                subtitleLabel.isHidden = true
            }
        }
    }
    
    var savedItemFullName: String? = nil
    var tappedBlock: (() -> Void)? = nil
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.textColor = .white
        label.numberOfLines = 1
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = .white.withAlphaComponent(0.8)
        label.numberOfLines = 2
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        // Dark background with rounded corners
        backgroundColor = UIColor.black.withAlphaComponent(0.85)
        layer.cornerRadius = 8
        layer.masksToBounds = true
        
        // Add labels
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            subtitleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -12)
        ])
        
        // Add tap gesture
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tapGesture)
    }
    
    @objc private func handleTap() {
        tappedBlock?()
    }
}
