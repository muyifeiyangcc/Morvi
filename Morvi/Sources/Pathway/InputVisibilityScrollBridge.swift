import SwiftUI
import UIKit

struct InputVisibilityScrollBridge<Content: View>: UIViewRepresentable {
    let content: Content

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .clear
        scrollView.contentInsetAdjustmentBehavior = .never
        scrollView.showsVerticalScrollIndicator = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive

        let host = UIHostingController(rootView: content)
        host.view.backgroundColor = .clear
        host.view.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            host.view.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            host.view.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        context.coordinator.attach(host: host, to: scrollView)
        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.host?.rootView = content
        context.coordinator.recalculateAfterLayout()
    }

    final class Coordinator {
        fileprivate var host: UIHostingController<Content>?
        private weak var scrollView: UIScrollView?
        private var baseInset: UIEdgeInsets?
        private var baseIndicatorInset: UIEdgeInsets?
        private var baseOffset: CGPoint?
        private var observers: [NSObjectProtocol] = []

        deinit {
            observers.forEach(NotificationCenter.default.removeObserver)
        }

        fileprivate func attach(host: UIHostingController<Content>, to scrollView: UIScrollView) {
            self.host = host
            self.scrollView = scrollView
            let center = NotificationCenter.default
            observers = [
                center.addObserver(forName: UIResponder.keyboardWillChangeFrameNotification, object: nil, queue: .main) { [weak self] notification in
                    self?.adjustForKeyboard(notification)
                },
                center.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main) { [weak self] notification in
                    self?.adjustForKeyboard(notification)
                }
            ]
        }

        fileprivate func recalculateAfterLayout() {
            scrollView?.layoutIfNeeded()
        }

        private func adjustForKeyboard(_ notification: Notification) {
            guard
                let scrollView,
                let container = scrollView.superview,
                let screenFrame = notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else {
                return
            }

            let keyboardFrame = container.convert(screenFrame, from: nil)
            let scrollFrame = scrollView.convert(scrollView.bounds, to: container)
            let isHiding = notification.name == UIResponder.keyboardWillHideNotification
            let overlap = isHiding ? 0 : max(0, scrollFrame.maxY - keyboardFrame.minY)

            guard overlap > 0 else {
                restoreBaseLayout(in: scrollView)
                return
            }

            captureBaseLayout(from: scrollView)
            let originalInset = baseInset ?? .zero
            let originalIndicatorInset = baseIndicatorInset ?? .zero
            scrollView.contentInset.bottom = originalInset.bottom + overlap + 10
            scrollView.verticalScrollIndicatorInsets.bottom = originalIndicatorInset.bottom + overlap + 10

            guard let activeInput = firstResponder(in: scrollView) else { return }
            let targetRect = activeInput.convert(activeInput.bounds.insetBy(dx: 0, dy: -18), to: scrollView)
            let visibleHeight = max(1, keyboardFrame.minY - scrollFrame.minY - 10)
            let initialOffset = baseOffset?.y ?? scrollView.contentOffset.y
            let requestedOffset = max(initialOffset, targetRect.maxY - visibleHeight)
            let minimumOffset = -scrollView.contentInset.top
            let maximumOffset = max(
                minimumOffset,
                scrollView.contentSize.height + scrollView.contentInset.bottom - scrollView.bounds.height
            )
            let clampedOffset = min(max(requestedOffset, minimumOffset), maximumOffset)
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? TimeInterval ?? 0.25

            UIView.animate(withDuration: duration) {
                scrollView.setContentOffset(
                    CGPoint(x: scrollView.contentOffset.x, y: clampedOffset),
                    animated: false
                )
            }
        }

        private func captureBaseLayout(from scrollView: UIScrollView) {
            guard baseInset == nil else { return }
            baseInset = scrollView.contentInset
            baseIndicatorInset = scrollView.verticalScrollIndicatorInsets
            baseOffset = scrollView.contentOffset
        }

        private func restoreBaseLayout(in scrollView: UIScrollView) {
            guard let baseInset else { return }
            scrollView.contentInset = baseInset
            if let baseIndicatorInset {
                scrollView.verticalScrollIndicatorInsets = baseIndicatorInset
            }
            if let baseOffset {
                scrollView.setContentOffset(baseOffset, animated: true)
            }
            self.baseInset = nil
            baseIndicatorInset = nil
            baseOffset = nil
        }

        private func firstResponder(in view: UIView) -> UIView? {
            if view.isFirstResponder {
                return view
            }
            for child in view.subviews {
                if let responder = firstResponder(in: child) {
                    return responder
                }
            }
            return nil
        }
    }
}
