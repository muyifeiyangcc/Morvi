import UIKit

final class NotchedPanelView: UIView {
    var fillColor: UIColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1) {
        didSet {
            shapeLayer.fillColor = fillColor.cgColor
        }
    }

    private let shapeLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        layer.insertSublayer(shapeLayer, at: 0)
        shapeLayer.fillColor = fillColor.cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 14
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        let panelPath = makePanelPath(in: bounds)
        shapeLayer.path = panelPath.cgPath
        layer.shadowPath = panelPath.cgPath
    }

    private func makePanelPath(in rect: CGRect) -> UIBezierPath {
        let width = rect.width
        let height = rect.height
        let leftRadius: CGFloat = min(16, height / 2)
        let rightRadius: CGFloat = min(14, height / 2)
        let notchDrop = min(22, height * 0.24)
        let notchStart = width * 0.53
        let notchEnd = width * 0.66

        let path = UIBezierPath()
        path.move(to: CGPoint(x: rect.minX + leftRadius, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + notchStart, y: rect.minY))
        path.addCurve(
            to: CGPoint(x: rect.minX + notchEnd, y: rect.minY + notchDrop),
            controlPoint1: CGPoint(x: rect.minX + notchStart + 13, y: rect.minY),
            controlPoint2: CGPoint(x: rect.minX + notchStart + 23, y: rect.minY + notchDrop)
        )
        path.addLine(to: CGPoint(x: rect.maxX - rightRadius, y: rect.minY + notchDrop))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + notchDrop + rightRadius),
            controlPoint: CGPoint(x: rect.maxX, y: rect.minY + notchDrop)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - rightRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - rightRadius, y: rect.maxY),
            controlPoint: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX + leftRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - leftRadius),
            controlPoint: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + leftRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + leftRadius, y: rect.minY),
            controlPoint: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.close()
        return path
    }
}
