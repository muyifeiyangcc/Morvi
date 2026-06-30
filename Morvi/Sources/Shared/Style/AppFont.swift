import UIKit

enum AppFont {
    static func source(_ size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont(name: sourceName(for: weight), size: size) ?? .systemFont(ofSize: size, weight: weight)
    }

    static func fredoka(_ size: CGFloat) -> UIFont {
        UIFont(name: "FredokaOne-Regular", size: size) ?? source(size, weight: .regular)
    }

    private static func sourceName(for weight: UIFont.Weight) -> String {
        switch weight.rawValue {
        case ...UIFont.Weight.thin.rawValue:
            return "SourceHanSansSC-ExtraLight"
        case ...UIFont.Weight.light.rawValue:
            return "SourceHanSansSC-Light"
        case ..<UIFont.Weight.regular.rawValue:
            return "SourceHanSansSC-Normal"
        case ...UIFont.Weight.regular.rawValue:
            return "SourceHanSansSC-Regular"
        case ...UIFont.Weight.medium.rawValue:
            return "SourceHanSansSC-Medium"
        case ...UIFont.Weight.bold.rawValue:
            return "SourceHanSansSC-Bold"
        default:
            return "SourceHanSansSC-Heavy"
        }
    }
}
