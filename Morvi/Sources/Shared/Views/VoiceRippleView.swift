import UIKit

final class VoiceRippleView: UIView {
    private let rippleSize: CGFloat = 40
    private let maxScale: CGFloat = 4
    private let duration: CFTimeInterval = 2.4
    private let ringViews: [GradientRingView]

    init(colors: [UIColor]) {
        ringViews = (0..<3).map { _ in
            GradientRingView(colors: colors, ringWidth: 1)
        }
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        clipsToBounds = false
        alpha = 0
        ringViews.forEach {
            addSubview($0)
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let origin = CGPoint(
            x: (bounds.width - rippleSize) / 2,
            y: (bounds.height - rippleSize) / 2
        )
        ringViews.forEach {
            $0.frame = CGRect(origin: origin, size: CGSize(width: rippleSize, height: rippleSize))
        }
    }

    func startAnimating() {
        alpha = 1
        let beginTime = CACurrentMediaTime()
        for (index, ringView) in ringViews.enumerated() {
            ringView.layer.removeAllAnimations()
            ringView.layer.opacity = 0
            ringView.layer.transform = CATransform3DIdentity

            let scale = CABasicAnimation(keyPath: "transform.scale")
            scale.fromValue = 1
            scale.toValue = maxScale

            let opacity = CABasicAnimation(keyPath: "opacity")
            opacity.fromValue = 0.9
            opacity.toValue = 0

            let group = CAAnimationGroup()
            group.animations = [scale, opacity]
            group.duration = duration
            group.beginTime = beginTime + (duration / Double(ringViews.count)) * Double(index)
            group.repeatCount = .infinity
            group.isRemovedOnCompletion = false
            group.timingFunction = CAMediaTimingFunction(name: .easeOut)
            ringView.layer.add(group, forKey: "voiceRipple")
        }
    }

    func stopAnimating() {
        ringViews.forEach {
            $0.layer.removeAnimation(forKey: "voiceRipple")
            $0.layer.opacity = 0
            $0.layer.transform = CATransform3DIdentity
        }
        UIView.animate(withDuration: 0.18) {
            self.alpha = 0
        }
    }
}
