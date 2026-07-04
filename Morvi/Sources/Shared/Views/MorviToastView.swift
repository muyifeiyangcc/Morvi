import UIKit

final class MorviToastView: UIView {
    private static let activeToastTag = 82418

    private let cardView = UIView()
    private let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialDark))
    private let gradientLayer = CAGradientLayer()
    private let highlightLayer = CAGradientLayer()
    private let titleLabel = UILabel()

    static func show(_ text: String, in hostView: UIView? = nil, duration: TimeInterval = 1.8) {
        guard let parent = hostView ?? activeWindow else { return }
        parent.viewWithTag(activeToastTag)?.removeFromSuperview()

        let toastView = MorviToastView(text: text)
        toastView.tag = activeToastTag
        toastView.present(in: parent, duration: duration)
    }

    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
    }

    private init(text: String) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        configureCard()
        configureLabel(text)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = cardView.bounds
        gradientLayer.cornerRadius = cardView.layer.cornerRadius
        let highlightHeight: CGFloat = 3
        highlightLayer.frame = CGRect(
            x: 14,
            y: max(0, cardView.bounds.height - highlightHeight - 5),
            width: max(0, cardView.bounds.width - 28),
            height: highlightHeight
        )
        highlightLayer.cornerRadius = highlightHeight / 2
    }

    private func configureCard() {
        cardView.backgroundColor = .clear
        cardView.layer.cornerRadius = 20
        cardView.layer.cornerCurve = .continuous
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.30
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        cardView.layer.shadowRadius = 22
        addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        blurView.layer.cornerRadius = 20
        blurView.layer.cornerCurve = .continuous
        blurView.layer.masksToBounds = true
        blurView.layer.borderColor = UIColor(red: 0.80, green: 1.0, blue: 0.30, alpha: 0.65).cgColor
        blurView.layer.borderWidth = 1
        cardView.addSubview(blurView)
        blurView.translatesAutoresizingMaskIntoConstraints = false

        gradientLayer.colors = [
            UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 0.94).cgColor,
            UIColor(red: 0.08, green: 0.14, blue: 0.12, alpha: 0.92).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        blurView.contentView.layer.insertSublayer(gradientLayer, at: 0)

        highlightLayer.colors = [
            UIColor(red: 0.78, green: 1.0, blue: 0.24, alpha: 1).cgColor,
            UIColor(red: 0.87, green: 0.98, blue: 1.0, alpha: 0.95).cgColor
        ]
        highlightLayer.startPoint = CGPoint(x: 0, y: 0.5)
        highlightLayer.endPoint = CGPoint(x: 1, y: 0.5)
        blurView.contentView.layer.insertSublayer(highlightLayer, above: gradientLayer)

        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 28),
            cardView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -28),
            cardView.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),

            blurView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor),
            blurView.topAnchor.constraint(equalTo: cardView.topAnchor),
            blurView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor)
        ])
    }

    private func configureLabel(_ text: String) {
        titleLabel.text = text
        titleLabel.textColor = .white
        titleLabel.font = AppFont.source(15, weight: .medium)
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        blurView.contentView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: blurView.contentView.leadingAnchor, constant: 26),
            titleLabel.trailingAnchor.constraint(equalTo: blurView.contentView.trailingAnchor, constant: -26),
            titleLabel.topAnchor.constraint(equalTo: blurView.contentView.topAnchor, constant: 14),
            titleLabel.bottomAnchor.constraint(equalTo: blurView.contentView.bottomAnchor, constant: -16)
        ])
    }

    private func present(in parent: UIView, duration: TimeInterval) {
        alpha = 0
        transform = CGAffineTransform(scaleX: 0.96, y: 0.96).translatedBy(x: 0, y: 8)
        parent.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: {
                self.alpha = 1
                self.transform = .identity
            },
            completion: { _ in
                self.dismiss(after: duration)
            }
        )
    }

    private func dismiss(after duration: TimeInterval) {
        UIView.animate(
            withDuration: 0.22,
            delay: duration,
            options: [.curveEaseIn, .allowUserInteraction],
            animations: {
                self.alpha = 0
                self.transform = CGAffineTransform(scaleX: 0.98, y: 0.98).translatedBy(x: 0, y: -6)
            },
            completion: { _ in
                self.removeFromSuperview()
            }
        )
    }
}
