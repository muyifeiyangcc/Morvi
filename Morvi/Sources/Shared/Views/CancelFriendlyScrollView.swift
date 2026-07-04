import UIKit

final class CancelFriendlyScrollView: UIScrollView {
    var topClipInset: CGFloat = 0 {
        didSet {
            setNeedsLayout()
        }
    }

    private let contentMaskLayer = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        canCancelContentTouches = true
        delaysContentTouches = false
        layer.mask = contentMaskLayer
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func touchesShouldCancel(in view: UIView) -> Bool {
        if view is UIControl {
            return true
        }
        return super.touchesShouldCancel(in: view)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let visibleBounds = CGRect(
            x: 0,
            y: topClipInset,
            width: bounds.width,
            height: max(0, bounds.height - topClipInset)
        )
        contentMaskLayer.frame = bounds
        contentMaskLayer.path = UIBezierPath(rect: visibleBounds).cgPath
    }
}
