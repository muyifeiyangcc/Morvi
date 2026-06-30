import UIKit

final class DecorativeGradientView: UIView {
    enum Palette {
        case white

        var backgroundColor: UIColor {
            switch self {
            case .white:
                return .white
            }
        }
    }

    private let palette: Palette

    init(palette: Palette = .white) {
        self.palette = palette
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        backgroundColor = palette.backgroundColor
    }

    required init?(coder: NSCoder) {
        nil
    }
}
