import UIKit

extension UIViewController {
    func installHitAreas(_ areas: [HitArea]) {
        let baseWidth: CGFloat = 375
        let baseHeight: CGFloat = 812
        let scale = min(view.bounds.width / baseWidth, view.bounds.height / baseHeight)
        let originX = (view.bounds.width - baseWidth * scale) / 2
        let originY = (view.bounds.height - baseHeight * scale) / 2
        areas.forEach { area in
            let scaled = CGRect(
                x: originX + area.frame.minX * scale,
                y: originY + area.frame.minY * scale,
                width: area.frame.width * scale,
                height: area.frame.height * scale
            )
            view.addSubview(ClearTapButton(frame: scaled, action: area.action))
        }
    }
}
