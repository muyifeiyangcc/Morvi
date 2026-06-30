import UIKit

final class ClearTapButton: UIButton {
    private let actionBlock: () -> Void

    init(frame: CGRect, action: @escaping () -> Void) {
        self.actionBlock = action
        super.init(frame: frame)
        backgroundColor = .clear
        addTarget(self, action: #selector(runAction), for: .touchUpInside)
    }

    required init?(coder: NSCoder) {
        nil
    }

    @objc private func runAction() {
        actionBlock()
    }
}
