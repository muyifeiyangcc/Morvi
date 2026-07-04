import UIKit

final class CancelFriendlyScrollView: UIScrollView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        canCancelContentTouches = true
        delaysContentTouches = false
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
}
