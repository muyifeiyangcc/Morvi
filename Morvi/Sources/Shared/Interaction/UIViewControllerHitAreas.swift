import UIKit
import ObjectiveC

extension UIViewController {
    func installHitAreas(_ areas: [HitArea]) {
        guard let hostView = view else { return }
        if let existingGesture = objc_getAssociatedObject(hostView, &hitAreaTapGestureKey) as? UIGestureRecognizer {
            hostView.removeGestureRecognizer(existingGesture)
        }
        guard areas.isEmpty == false else { return }
        let resolvedAreas = areas.map { area -> HitArea in
            let rightInset: CGFloat = 20
            let referenceWidth: CGFloat = 375
            let fillsReferenceWidth = area.frame.minX <= rightInset && area.frame.width >= 300
            let isReferenceCentered = abs(area.frame.midX - referenceWidth / 2) < 1
            let resolvedWidth = fillsReferenceWidth
                ? max(0, hostView.bounds.width - area.frame.minX - rightInset)
                : area.frame.width
            let resolvedX = isReferenceCentered
                ? (hostView.bounds.width - resolvedWidth) / 2
                : area.frame.minX
            let resolvedFrame = CGRect(
                x: resolvedX,
                y: area.frame.minY,
                width: resolvedWidth,
                height: area.frame.height
            )
            return HitArea(frame: resolvedFrame, action: area.action)
        }
        let proxy = HitAreaTapProxy(areas: resolvedAreas, hostView: hostView)
        let gesture = UITapGestureRecognizer(target: proxy, action: #selector(HitAreaTapProxy.handleTap(_:)))
        gesture.cancelsTouchesInView = false
        hostView.addGestureRecognizer(gesture)
        objc_setAssociatedObject(hostView, &hitAreaTapProxyKey, proxy, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        objc_setAssociatedObject(hostView, &hitAreaTapGestureKey, gesture, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}

private var hitAreaTapProxyKey: UInt8 = 0
private var hitAreaTapGestureKey: UInt8 = 0

private final class HitAreaTapProxy: NSObject {
    private let areas: [HitArea]
    private weak var hostView: UIView?

    init(areas: [HitArea], hostView: UIView) {
        self.areas = areas
        self.hostView = hostView
    }

    @objc func handleTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended, let hostView else { return }
        let location = gesture.location(in: hostView)
        guard let area = area(at: location, in: hostView, gesture: gesture) else { return }
        area.action()
    }

    private func area(at location: CGPoint, in hostView: UIView, gesture: UITapGestureRecognizer) -> HitArea? {
        for scrollView in scrollViews(in: hostView) {
            let scrollLocation = gesture.location(in: scrollView)
            guard scrollView.bounds.contains(scrollLocation) else { continue }
            let contentLocation = CGPoint(
                x: scrollLocation.x + scrollView.contentOffset.x,
                y: scrollLocation.y + scrollView.contentOffset.y
            )
            if let area = areas.first(where: { $0.frame.contains(contentLocation) }) {
                return area
            }
        }
        return areas.first(where: { $0.frame.contains(location) })
    }

    private func scrollViews(in view: UIView) -> [UIScrollView] {
        var result: [UIScrollView] = []
        for subview in view.subviews {
            if let scrollView = subview as? UIScrollView {
                result.append(scrollView)
            }
            result.append(contentsOf: scrollViews(in: subview))
        }
        return result
    }
}
