import UIKit

final class AdaptiveInputView: UIView {
    private let gradientLayer: CAGradientLayer?
    private let dashedBorderLayer = CAShapeLayer()

    init(backgroundColor: UIColor, gradientColors: [UIColor]? = nil, cornerRadius: CGFloat = 10) {
        if let gradientColors {
            let gradientLayer = CAGradientLayer()
            gradientLayer.colors = gradientColors.map(\.cgColor)
            gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
            gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
            self.gradientLayer = gradientLayer
        } else {
            gradientLayer = nil
        }
        super.init(frame: .zero)
        self.backgroundColor = backgroundColor
        layer.cornerRadius = cornerRadius
        layer.masksToBounds = true
        if let gradientLayer {
            layer.insertSublayer(gradientLayer, at: 0)
        }
        dashedBorderLayer.strokeColor = UIColor(red: 165 / 255, green: 214 / 255, blue: 63 / 255, alpha: 1).cgColor
        dashedBorderLayer.fillColor = UIColor.clear.cgColor
        dashedBorderLayer.lineDashPattern = [3, 2]
        dashedBorderLayer.lineWidth = 1
        layer.addSublayer(dashedBorderLayer)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer?.frame = bounds
        gradientLayer?.cornerRadius = layer.cornerRadius
        dashedBorderLayer.frame = bounds
        dashedBorderLayer.path = UIBezierPath(
            roundedRect: bounds.insetBy(dx: 0.5, dy: 0.5),
            cornerRadius: layer.cornerRadius
        ).cgPath
    }
}
