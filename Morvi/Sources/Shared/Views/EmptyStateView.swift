import UIKit

final class EmptyStateView: UIView {
    private let illustrationView = UIImageView()
    private let copyLabel = UILabel()
    private let copy: String

    init(copy: String) {
        self.copy = copy
        super.init(frame: .zero)
        configureView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureView() {
        backgroundColor = .clear
        isUserInteractionEnabled = false

        illustrationView.image = UIImage(named: "empty_list_illustration")
        illustrationView.contentMode = .scaleAspectFit
        copyLabel.text = copy
        copyLabel.font = AppFont.source(16, weight: .medium)
        copyLabel.textColor = UIColor(white: 0.45, alpha: 1)
        copyLabel.textAlignment = .center

        let contentStack = UIStackView(arrangedSubviews: [illustrationView, copyLabel])
        contentStack.axis = .vertical
        contentStack.alignment = .center
        contentStack.spacing = 6
        addSubview(contentStack)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        illustrationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentStack.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor),
            contentStack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            illustrationView.widthAnchor.constraint(equalToConstant: 105),
            illustrationView.heightAnchor.constraint(equalToConstant: 197)
        ])
    }
}
