import UIKit

final class CustomTopLayerView: UIView {
    let backArea = UIButton(type: .custom)
    let trailingArea = UIButton(type: .custom)
    private let backIconView = UIImageView(image: UIImage(named: "navigation_back_circle"))
    private let trailingIconView = UIImageView()
    private let titleLabel = UILabel()
    private var navigationCenterYConstraint: NSLayoutConstraint?
    private var titleLeadingConstraint: NSLayoutConstraint?

    var showsBackIcon = false {
        didSet {
            backIconView.isHidden = !showsBackIcon
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        backIconView.contentMode = .scaleAspectFit
        backIconView.isHidden = true
        backIconView.isUserInteractionEnabled = false
        trailingIconView.contentMode = .scaleAspectFit
        trailingIconView.isHidden = true
        trailingIconView.isUserInteractionEnabled = false
        titleLabel.textColor = .black
        titleLabel.numberOfLines = 1
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.55
        titleLabel.lineBreakMode = .byClipping
        addSubview(backIconView)
        addSubview(trailingIconView)
        addSubview(titleLabel)
        addSubview(backArea)
        addSubview(trailingArea)
        backIconView.translatesAutoresizingMaskIntoConstraints = false
        trailingIconView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        backArea.translatesAutoresizingMaskIntoConstraints = false
        trailingArea.translatesAutoresizingMaskIntoConstraints = false
        let centerY = backIconView.centerYAnchor.constraint(equalTo: topAnchor, constant: 82)
        let titleLeading = titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 96)
        navigationCenterYConstraint = centerY
        titleLeadingConstraint = titleLeading
        NSLayoutConstraint.activate([
            backIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            centerY,
            backIconView.widthAnchor.constraint(equalToConstant: 58),
            backIconView.heightAnchor.constraint(equalToConstant: 58),

            trailingIconView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -20),
            trailingIconView.centerYAnchor.constraint(equalTo: backIconView.centerYAnchor),
            trailingIconView.widthAnchor.constraint(equalToConstant: 58),
            trailingIconView.heightAnchor.constraint(equalToConstant: 58),

            titleLeading,
            titleLabel.centerYAnchor.constraint(equalTo: backIconView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),

            backArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            backArea.topAnchor.constraint(equalTo: topAnchor),
            backArea.bottomAnchor.constraint(equalTo: bottomAnchor),
            backArea.widthAnchor.constraint(equalToConstant: 88),

            trailingArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingArea.topAnchor.constraint(equalTo: topAnchor),
            trailingArea.bottomAnchor.constraint(equalTo: bottomAnchor),
            trailingArea.widthAnchor.constraint(equalToConstant: 92),
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        if showsBackIcon, backArea.frame.contains(point) {
            return super.hitTest(point, with: event)
        }
        if trailingIconView.isHidden == false, trailingArea.frame.contains(point) {
            return super.hitTest(point, with: event)
        }
        return nil
    }

    func configure(
        title: String?,
        statusBarHeight: CGFloat,
        showsBackIcon: Bool,
        trailingIconName: String? = nil,
        titleLeading: CGFloat = 96
    ) {
        self.showsBackIcon = showsBackIcon
        backArea.isUserInteractionEnabled = showsBackIcon
        trailingIconView.image = trailingIconName.flatMap { UIImage(named: $0) }
        trailingIconView.isHidden = trailingIconName == nil
        trailingArea.isUserInteractionEnabled = trailingIconName != nil
        titleLabel.text = title
        titleLabel.isHidden = title == nil
        titleLabel.font = AppFont.fredoka(31)
        navigationCenterYConstraint?.constant = statusBarHeight + 38
        titleLeadingConstraint?.constant = titleLeading
    }

    static func totalHeight(statusBarHeight: CGFloat) -> CGFloat {
        statusBarHeight + 76
    }
}
