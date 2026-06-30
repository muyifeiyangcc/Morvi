import UIKit

final class DecorativeGradientView: UIView {
    enum Palette {
        case topLeftGlow

        var baseColor: UIColor {
            switch self {
            case .topLeftGlow:
                return .white
            }
        }

        var glowColor: UIColor {
            switch self {
            case .topLeftGlow:
                return UIColor(red: 226 / 255, green: 255 / 255, blue: 120 / 255, alpha: 1)
            }
        }
    }

    private let palette: Palette

    init(palette: Palette = .topLeftGlow) {
        self.palette = palette
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        isOpaque = true
        contentMode = .redraw
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(_ rect: CGRect) {
        palette.baseColor.setFill()
        UIRectFill(rect)

        guard
            let context = UIGraphicsGetCurrentContext(),
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    palette.glowColor.cgColor,
                    palette.glowColor.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
        else { return }

        let radius = bounds.width / 3
        context.drawRadialGradient(
            gradient,
            startCenter: .zero,
            startRadius: 0,
            endCenter: .zero,
            endRadius: radius,
            options: []
        )
    }
}
