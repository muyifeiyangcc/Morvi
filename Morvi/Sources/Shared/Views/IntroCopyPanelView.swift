import UIKit

final class IntroCopyPanelView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let titleLabel = UILabel()

    init(title: String) {
        super.init(frame: .zero)
        backgroundColor = .clear
        layer.cornerRadius = 12
        layer.cornerCurve = .continuous
        layer.masksToBounds = true
        configureGradient()
        configureLabel(title: title)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
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

    private func configureLabel(title: String) {
        titleLabel.text = title
        titleLabel.numberOfLines = 0
        titleLabel.textColor = UIColor(red: 0.06, green: 0.07, blue: 0.06, alpha: 1)
        titleLabel.font = AppFont.source(20, weight: .regular)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 15),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -15)
        ])
    }
}
