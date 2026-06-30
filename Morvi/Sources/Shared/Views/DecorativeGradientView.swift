import UIKit

final class DecorativeGradientView: UIView {
    enum Palette {
        case blue

        var colors: [CGColor] {
            switch self {
            case .blue:
                return [
                    UIColor(red: 0.78, green: 0.92, blue: 1.00, alpha: 1).cgColor,
                    UIColor(red: 0.42, green: 0.67, blue: 1.00, alpha: 1).cgColor,
                    UIColor(red: 0.12, green: 0.32, blue: 0.82, alpha: 1).cgColor
                ]
            }
        }
    }

    override class var layerClass: AnyClass {
        CAGradientLayer.self
    }

    private let palette: Palette

    init(palette: Palette = .blue) {
        self.palette = palette
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        configureGradient()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureGradient() {
        guard let gradientLayer = layer as? CAGradientLayer else { return }
        gradientLayer.colors = palette.colors
        gradientLayer.locations = [0, 0.52, 1]
        gradientLayer.startPoint = CGPoint(x: 0.12, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.88, y: 1)
    }
}
