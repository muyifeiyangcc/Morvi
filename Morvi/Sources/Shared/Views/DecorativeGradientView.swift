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

        var secondaryGlowColor: UIColor {
            switch self {
            case .topLeftGlow:
                return UIColor(red: 222 / 255, green: 251 / 255, blue: 255 / 255, alpha: 1)
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

        guard let context = UIGraphicsGetCurrentContext() else { return }
        drawGlow(
            in: context,
            center: .zero,
            radius: bounds.width * 0.9,
            color: palette.glowColor
        )
        drawGlow(
            in: context,
            center: CGPoint(x: bounds.maxX, y: 0),
            radius: bounds.width * 0.4,
            color: palette.secondaryGlowColor
        )
    }

    private func drawGlow(in context: CGContext, center: CGPoint, radius: CGFloat, color: UIColor) {
        guard
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    color.cgColor,
                    color.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
        else { return }

        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: radius,
            options: []
        )
    }
}
