import UIKit

final class IntroCopyPanelView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let sizingLabel = UILabel()
    private let titleLabel = UILabel()
    private var revealTimer: Timer?
    private var revealCharacters: [Character] = []
    private var revealIndex = 0

    init(title: String, revealsCharacters: Bool = false) {
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        configureGradient()
        configureLabel(title: title, revealsCharacters: revealsCharacters)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        revealTimer?.invalidate()
    }

    override func didMoveToSuperview() {
        super.didMoveToSuperview()
        if superview == nil {
            revealTimer?.invalidate()
            revealTimer = nil
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    private func configureGradient() {
        gradientLayer.colors = [
            UIColor(red: 235 / 255, green: 254 / 255, blue: 175 / 255, alpha: 1).cgColor,
            UIColor(red: 224 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        gradientLayer.contentsScale = UIScreen.main.scale
        layer.insertSublayer(gradientLayer, at: 0)
    }

    private func configureLabel(title: String, revealsCharacters: Bool) {
        configureCopyLabel(sizingLabel)
        configureCopyLabel(titleLabel)
        sizingLabel.text = title
        sizingLabel.alpha = 0
        titleLabel.text = revealsCharacters ? "" : title
        addSubview(sizingLabel)
        addSubview(titleLabel)
        sizingLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sizingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            sizingLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            sizingLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            sizingLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15),

            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15)
        ])
        if revealsCharacters {
            beginCharacterReveal(title)
        }
    }

    private func configureCopyLabel(_ label: UILabel) {
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.06, green: 0.07, blue: 0.06, alpha: 1)
        label.font = AppFont.source(20, weight: .regular)
    }

    private func beginCharacterReveal(_ title: String) {
        revealTimer?.invalidate()
        revealCharacters = Array(title)
        revealIndex = 0
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { [weak self] timer in
            guard let self else {
                timer.invalidate()
                return
            }
            guard revealIndex < revealCharacters.count else {
                timer.invalidate()
                self.revealTimer = nil
                return
            }
            revealIndex += 1
            titleLabel.text = String(revealCharacters.prefix(revealIndex))
        }
    }
}
