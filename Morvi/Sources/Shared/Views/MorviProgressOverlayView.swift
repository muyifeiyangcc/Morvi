import UIKit

final class MorviProgressOverlayView: UIView {
    private let cardView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialLight))
    private let faceView = UIView()
    private let ringLayer = CAShapeLayer()
    private let smileLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor.white.withAlphaComponent(0.30)
        isUserInteractionEnabled = true
        configureCard()
        configureFace()
        configureRing()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func show(in parent: UIView) {
        guard superview == nil else { return }
        alpha = 0
        parent.addSubview(self)
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: parent.leadingAnchor),
            trailingAnchor.constraint(equalTo: parent.trailingAnchor),
            topAnchor.constraint(equalTo: parent.topAnchor),
            bottomAnchor.constraint(equalTo: parent.bottomAnchor)
        ])
        startAnimating()
        UIView.animate(withDuration: 0.18) {
            self.alpha = 1
        }
    }

    func dismiss() {
        UIView.animate(withDuration: 0.18, animations: {
            self.alpha = 0
        }, completion: { _ in
            self.stopAnimating()
            self.removeFromSuperview()
        })
    }

    private func configureCard() {
        cardView.layer.cornerRadius = 34
        cardView.layer.cornerCurve = .continuous
        cardView.layer.masksToBounds = true
        cardView.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 0.88)
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.18
        cardView.layer.shadowOffset = CGSize(width: 0, height: 10)
        cardView.layer.shadowRadius = 24
        addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            cardView.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardView.centerYAnchor.constraint(equalTo: centerYAnchor),
            cardView.widthAnchor.constraint(equalToConstant: 116),
            cardView.heightAnchor.constraint(equalToConstant: 96)
        ])
    }

    private func configureFace() {
        faceView.backgroundColor = UIColor(red: 0.82, green: 1.0, blue: 0.24, alpha: 1)
        faceView.layer.cornerRadius = 20
        faceView.layer.cornerCurve = .continuous
        cardView.contentView.addSubview(faceView)
        faceView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            faceView.centerXAnchor.constraint(equalTo: cardView.contentView.centerXAnchor),
            faceView.centerYAnchor.constraint(equalTo: cardView.contentView.centerYAnchor),
            faceView.widthAnchor.constraint(equalToConstant: 48),
            faceView.heightAnchor.constraint(equalToConstant: 48)
        ])

        let eye = UIView()
        eye.backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        eye.layer.cornerRadius = 4
        faceView.addSubview(eye)
        eye.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            eye.leadingAnchor.constraint(equalTo: faceView.leadingAnchor, constant: 15),
            eye.topAnchor.constraint(equalTo: faceView.topAnchor, constant: 15),
            eye.widthAnchor.constraint(equalToConstant: 8),
            eye.heightAnchor.constraint(equalToConstant: 14)
        ])

        let wink = UILabel()
        wink.text = "<"
        wink.font = AppFont.source(22, weight: .bold)
        wink.textColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        faceView.addSubview(wink)
        wink.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wink.leadingAnchor.constraint(equalTo: faceView.leadingAnchor, constant: 29),
            wink.topAnchor.constraint(equalTo: faceView.topAnchor, constant: 9)
        ])

        smileLayer.strokeColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1).cgColor
        smileLayer.fillColor = UIColor.clear.cgColor
        smileLayer.lineWidth = 3
        smileLayer.lineCap = .round
        faceView.layer.addSublayer(smileLayer)
    }

    private func configureRing() {
        ringLayer.strokeColor = UIColor(red: 0.82, green: 1.0, blue: 0.24, alpha: 1).cgColor
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.lineWidth = 3
        ringLayer.lineCap = .round
        ringLayer.strokeStart = 0
        ringLayer.strokeEnd = 0.72
        cardView.contentView.layer.addSublayer(ringLayer)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let ringBounds = cardView.contentView.bounds.insetBy(dx: 23, dy: 13)
        ringLayer.path = UIBezierPath(ovalIn: ringBounds).cgPath
        ringLayer.frame = cardView.contentView.bounds

        let smilePath = UIBezierPath()
        smilePath.move(to: CGPoint(x: 17, y: 33))
        smilePath.addQuadCurve(to: CGPoint(x: 34, y: 30), controlPoint: CGPoint(x: 25, y: 39))
        smileLayer.path = smilePath.cgPath
    }

    private func startAnimating() {
        let spin = CABasicAnimation(keyPath: "transform.rotation.z")
        spin.fromValue = 0
        spin.toValue = CGFloat.pi * 2
        spin.duration = 0.95
        spin.repeatCount = .infinity
        spin.timingFunction = CAMediaTimingFunction(name: .linear)
        ringLayer.add(spin, forKey: "morvi.spin")

        UIView.animate(
            withDuration: 0.72,
            delay: 0,
            options: [.autoreverse, .repeat, .allowUserInteraction],
            animations: {
                self.faceView.transform = CGAffineTransform(scaleX: 0.94, y: 0.94)
            }
        )
    }

    private func stopAnimating() {
        ringLayer.removeAllAnimations()
        faceView.layer.removeAllAnimations()
        faceView.transform = .identity
    }
}
