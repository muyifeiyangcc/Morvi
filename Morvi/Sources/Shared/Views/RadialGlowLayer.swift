import UIKit

final class RadialGlowLayer: CALayer {
    var glowColor: UIColor = .clear {
        didSet { setNeedsDisplay() }
    }

    var centerUnitPoint: CGPoint = .zero {
        didSet { setNeedsDisplay() }
    }

    var radiusWidthMultiplier: CGFloat = 1 {
        didSet { setNeedsDisplay() }
    }

    override init() {
        super.init()
        contentsScale = UIScreen.main.scale
        needsDisplayOnBoundsChange = true
        isOpaque = false
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let layer = layer as? RadialGlowLayer {
            glowColor = layer.glowColor
            centerUnitPoint = layer.centerUnitPoint
            radiusWidthMultiplier = layer.radiusWidthMultiplier
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func draw(in context: CGContext) {
        guard
            bounds.width > 0,
            let gradient = CGGradient(
                colorsSpace: CGColorSpaceCreateDeviceRGB(),
                colors: [
                    glowColor.cgColor,
                    glowColor.withAlphaComponent(0).cgColor
                ] as CFArray,
                locations: [0, 1]
            )
        else { return }

        let center = CGPoint(
            x: bounds.width * centerUnitPoint.x,
            y: bounds.height * centerUnitPoint.y
        )
        context.drawRadialGradient(
            gradient,
            startCenter: center,
            startRadius: 0,
            endCenter: center,
            endRadius: bounds.width * radiusWidthMultiplier,
            options: []
        )
    }
}
