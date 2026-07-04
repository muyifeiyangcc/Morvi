import UIKit

extension UIViewController {
    func installHitAreas(_ areas: [HitArea]) {
        areas.forEach { area in
            let rightInset: CGFloat = 20
            let fillsReferenceWidth = area.frame.minX <= rightInset && area.frame.width >= 300
            let resolvedWidth = fillsReferenceWidth
                ? max(0, view.bounds.width - area.frame.minX - rightInset)
                : area.frame.width
            let resolvedFrame = CGRect(
                x: area.frame.minX,
                y: area.frame.minY,
                width: resolvedWidth,
                height: area.frame.height
            )
            view.addSubview(ClearTapButton(frame: resolvedFrame, action: area.action))
        }
    }
}
