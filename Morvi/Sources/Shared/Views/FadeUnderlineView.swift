import UIKit

final class FadeUnderlineView: UIView {
    private let gradientLayer = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradientLayer.colors = [
            UIColor(red: 184 / 255, green: 240 / 255, blue: 79 / 255, alpha: 1).cgColor,
            UIColor(red: 184 / 255, green: 240 / 255, blue: 79 / 255, alpha: 0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        layer.addSublayer(gradientLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }
}
