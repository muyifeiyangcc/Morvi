import UIKit

final class AudioClipBubbleView: UIView {
    private let shapeLayer = CAShapeLayer()
    private let waveformView = UIView()
    private let durationLabel = UILabel()
    private let pointerSide: ArrowBubbleView.PointerSide

    init(
        durationText: String,
        pointerSide: ArrowBubbleView.PointerSide,
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

        addSubview(waveformView)
        waveformView.translatesAutoresizingMaskIntoConstraints = false
        configureWaveform()

        durationLabel.text = durationText
        durationLabel.textColor = UIColor(red: 0.22, green: 0.24, blue: 0.22, alpha: 1)
        durationLabel.font = AppFont.source(15)
        addSubview(durationLabel)
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        let leadingInset: CGFloat = pointerSide == .left ? 17 : 10
        let trailingInset: CGFloat = pointerSide == .right ? 16 : 9
        NSLayoutConstraint.activate([
            waveformView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: leadingInset),
            waveformView.centerYAnchor.constraint(equalTo: centerYAnchor),
            waveformView.widthAnchor.constraint(equalToConstant: 14),
            waveformView.heightAnchor.constraint(equalToConstant: 16),

            durationLabel.leadingAnchor.constraint(equalTo: waveformView.trailingAnchor, constant: 8),
            durationLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -trailingInset),
            durationLabel.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shapeLayer.frame = bounds
        shapeLayer.path = bubblePath(in: bounds).cgPath
    }

    private func configureWaveform() {
        let barColor = UIColor(red: 0.58, green: 0.79, blue: 0.18, alpha: 1)
        let barHeights: [CGFloat] = [8, 13, 6, 10]
        var previousBar: UIView?
        for height in barHeights {
            let barView = UIView()
            barView.backgroundColor = barColor
            barView.layer.cornerRadius = 1
            waveformView.addSubview(barView)
            barView.translatesAutoresizingMaskIntoConstraints = false

            var constraints = [
                barView.centerYAnchor.constraint(equalTo: waveformView.centerYAnchor),
                barView.widthAnchor.constraint(equalToConstant: 2),
                barView.heightAnchor.constraint(equalToConstant: height)
            ]
            if let previousBar {
                constraints.append(barView.leadingAnchor.constraint(equalTo: previousBar.trailingAnchor, constant: 2))
            } else {
                constraints.append(barView.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor))
            }
            NSLayoutConstraint.activate(constraints)
            previousBar = barView
        }
        previousBar?.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor).isActive = true
    }

    private func bubblePath(in bounds: CGRect) -> UIBezierPath {
        let pointerWidth: CGFloat = pointerSide == .none ? 0 : 7
        let pointerHeight: CGFloat = 10
        let cornerRadius: CGFloat = 6
        let body = bounds.insetBy(dx: 0.5, dy: 0.5)
        let minBodyX = body.minX + (pointerSide == .left ? pointerWidth : 0)
        let maxBodyX = body.maxX - (pointerSide == .right ? pointerWidth : 0)
        let pointerCenterY = body.midY

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
