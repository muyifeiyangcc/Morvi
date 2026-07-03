import UIKit

final class GradientRingView: UIView {
    private let gradientLayer = CAGradientLayer()
    private let ringMaskLayer = CAShapeLayer()
    private let ringWidth: CGFloat

    init(colors: [UIColor], ringWidth: CGFloat = 1) {
        self.ringWidth = ringWidth
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        gradientLayer.colors = colors.map(\.cgColor)
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        gradientLayer.contentsScale = UIScreen.main.scale
        ringMaskLayer.contentsScale = UIScreen.main.scale
        layer.addSublayer(gradientLayer)
        gradientLayer.mask = ringMaskLayer
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        ringMaskLayer.frame = bounds
        ringMaskLayer.fillColor = UIColor.clear.cgColor
        ringMaskLayer.strokeColor = UIColor.black.cgColor
        ringMaskLayer.lineWidth = ringWidth
        ringMaskLayer.path = UIBezierPath(
            ovalIn: bounds.insetBy(dx: ringWidth / 2, dy: ringWidth / 2)
        ).cgPath
    }
}
