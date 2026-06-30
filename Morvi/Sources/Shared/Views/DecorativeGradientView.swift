import UIKit

final class DecorativeGradientView: UIView {
    enum Palette {
        case blue

        var backgroundColor: UIColor {
            switch self {
            case .blue:
                return UIColor(red: 0.42, green: 0.67, blue: 1.00, alpha: 1)
            }
        }
    }

    private let palette: Palette

    init(palette: Palette = .blue) {
        self.palette = palette
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = palette.backgroundColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}
