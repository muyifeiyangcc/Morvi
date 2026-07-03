import UIKit

final class ArrowBubbleView: UIView {
    enum PointerSide {
        case none
        case left
        case right
    }

    private let shapeLayer = CAShapeLayer()
    private let textLabel = UILabel()
    private let pointerSide: PointerSide

    init(
        text: String,
        pointerSide: PointerSide,
        fillColor: UIColor,
        strokeColor: UIColor
    ) {
        self.pointerSide = pointerSide
        super.init(frame: .zero)
        isOpaque = false

        shapeLayer.fillColor = fillColor.cgColor
        shapeLayer.strokeColor = strokeColor.cgColor
        shapeLayer.lineWidth = 1
        layer.addSublayer(shapeLayer)

        textLabel.text = text
        textLabel.numberOfLines = 0
        textLabel.textColor = UIColor(red: 0.17, green: 0.22, blue: 0.18, alpha: 1)
        textLabel.font = AppFont.source(16)
        addSubview(textLabel)
        textLabel.translatesAutoresizingMaskIntoConstraints = false

        let leadingInset: CGFloat = pointerSide == .left ? 18 : 18
        let trailingInset: CGFloat = pointerSide == .right ? 18 : 12
        NSLayoutConstraint.activate([
            textLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            textLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingInset),
            textLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            textLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let pointerInset: CGFloat = pointerSide == .none ? 24 : 31
        textLabel.preferredMaxLayoutWidth = max(1, bounds.width - pointerInset)
        shapeLayer.frame = bounds
        shapeLayer.path = bubblePath(in: bounds).cgPath
    }

    override var intrinsicContentSize: CGSize {
        let targetSize = CGSize(width: UIView.noIntrinsicMetric, height: UIView.layoutFittingCompressedSize.height)
        let labelSize = textLabel.systemLayoutSizeFitting(targetSize)
        let pointerWidth: CGFloat = pointerSide == .none ? 0 : 7
        return CGSize(width: labelSize.width + 30 + pointerWidth, height: labelSize.height + 20)
    }

    private func bubblePath(in bounds: CGRect) -> UIBezierPath {
        let pointerWidth: CGFloat = pointerSide == .none ? 0 : 7
        let pointerHeight: CGFloat = 10
        let cornerRadius: CGFloat = 5
        let body = bounds.insetBy(dx: 0.5, dy: 0.5).insetBy(dx: 0, dy: 0)
        let minBodyX = body.minX + (pointerSide == .left ? pointerWidth : 0)
        let maxBodyX = body.maxX - (pointerSide == .right ? pointerWidth : 0)
        let pointerCenterY = min(max(22, body.minY + cornerRadius + pointerHeight / 2), body.maxY - cornerRadius - pointerHeight / 2)

        let path = UIBezierPath()
        path.move(to: CGPoint(x: minBodyX + cornerRadius, y: body.minY))
        path.addLine(to: CGPoint(x: maxBodyX - cornerRadius, y: body.minY))
        path.addQuadCurve(
            to: CGPoint(x: maxBodyX, y: body.minY + cornerRadius),
            controlPoint: CGPoint(x: maxBodyX, y: body.minY)
        )

        if pointerSide == .right {
            path.addLine(to: CGPoint(x: maxBodyX, y: pointerCenterY - pointerHeight / 2))
            path.addLine(to: CGPoint(x: body.maxX, y: pointerCenterY))
            path.addLine(to: CGPoint(x: maxBodyX, y: pointerCenterY + pointerHeight / 2))
        }

        path.addLine(to: CGPoint(x: maxBodyX, y: body.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: maxBodyX - cornerRadius, y: body.maxY),
            controlPoint: CGPoint(x: maxBodyX, y: body.maxY)
        )

        path.addLine(to: CGPoint(x: minBodyX + cornerRadius, y: body.maxY))
        path.addQuadCurve(
            to: CGPoint(x: minBodyX, y: body.maxY - cornerRadius),
            controlPoint: CGPoint(x: minBodyX, y: body.maxY)
        )

        if pointerSide == .left {
            path.addLine(to: CGPoint(x: minBodyX, y: pointerCenterY + pointerHeight / 2))
            path.addLine(to: CGPoint(x: body.minX, y: pointerCenterY))
            path.addLine(to: CGPoint(x: minBodyX, y: pointerCenterY - pointerHeight / 2))
        }

        path.addLine(to: CGPoint(x: minBodyX, y: body.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: minBodyX + cornerRadius, y: body.minY),
            controlPoint: CGPoint(x: minBodyX, y: body.minY)
        )
        path.close()
        return path
    }
}
