import UIKit

// WallpaperAlertView - shows wallpaper-related alerts
// Reconstructed from apollo-base 1.15.11 binary analysis.

class WallpaperAlertView: UIView {
    
    private let label: UILabel
    
    init(message: String) {
        self.label = UILabel()
        self.label.text = message
        self.label.textAlignment = .center
        self.label.numberOfLines = 0
        self.label.font = UIFont.systemFont(ofSize: 14)
        
        super.init(frame: .zero)
        
        self.backgroundColor = UIColor.systemBackground
        self.layer.cornerRadius = 12
        self.layer.shadowColor = UIColor.black.cgColor
        self.layer.shadowOpacity = 0.1
        self.layer.shadowRadius = 4
        self.layer.shadowOffset = CGSize(width: 0, height: 2)
        
        self.addSubview(self.label)
        
        self.label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            self.label.topAnchor.constraint(equalTo: self.topAnchor, constant: 16),
            self.label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 16),
            self.label.trailingAnchor.constraint(equalTo: self.trailingAnchor, constant: -16),
            self.label.bottomAnchor.constraint(equalTo: self.bottomAnchor, constant: -16)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
