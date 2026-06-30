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
    private let primaryGlowLayer = RadialGlowLayer()
    private let secondaryGlowLayer = RadialGlowLayer()
    private let brandTextLogoView = UIImageView(image: UIImage(named: "Morvi"))

    init(palette: Palette = .topLeftGlow, showsBrandTextLogo: Bool = false) {
        self.palette = palette
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = palette.baseColor
        isOpaque = true
        configureGlowLayers()
        configureBrandTextLogo(isVisible: showsBrandTextLogo)
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        primaryGlowLayer.frame = bounds
        secondaryGlowLayer.frame = bounds
    }

    private func configureGlowLayers() {
        primaryGlowLayer.glowColor = palette.glowColor
        primaryGlowLayer.centerUnitPoint = CGPoint(x: 0.1, y: 0)
        primaryGlowLayer.radiusWidthMultiplier = 0.8

        secondaryGlowLayer.glowColor = palette.secondaryGlowColor
        secondaryGlowLayer.centerUnitPoint = CGPoint(x: 0.9, y: 0)
        secondaryGlowLayer.radiusWidthMultiplier = 0.6

        layer.addSublayer(primaryGlowLayer)
        layer.addSublayer(secondaryGlowLayer)
    }

    private func configureBrandTextLogo(isVisible: Bool) {
        brandTextLogoView.isHidden = !isVisible
        brandTextLogoView.contentMode = .scaleAspectFit
        addSubview(brandTextLogoView)
        brandTextLogoView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            brandTextLogoView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -10),
            brandTextLogoView.topAnchor.constraint(equalTo: topAnchor, constant: 20),
            brandTextLogoView.widthAnchor.constraint(equalToConstant: 297),
            brandTextLogoView.heightAnchor.constraint(equalToConstant: 128)
        ])
    }
}
