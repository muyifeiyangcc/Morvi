import UIKit

final class EmptyStateView: UIView {
    private let illustrationView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
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
        addSubview(illustrationView)
        illustrationView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            illustrationView.centerXAnchor.constraint(equalTo: centerXAnchor),
            illustrationView.centerYAnchor.constraint(equalTo: centerYAnchor),
            illustrationView.widthAnchor.constraint(lessThanOrEqualTo: widthAnchor, multiplier: 0.56),
            illustrationView.widthAnchor.constraint(lessThanOrEqualToConstant: 210),
            illustrationView.heightAnchor.constraint(equalTo: illustrationView.widthAnchor, multiplier: 1.18)
        ])
    }
}
