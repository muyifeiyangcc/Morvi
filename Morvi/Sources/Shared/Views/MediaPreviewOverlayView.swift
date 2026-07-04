import UIKit

final class MediaPreviewOverlayView: UIView {
    private let imageView = UIImageView()

    init(image: UIImage?) {
        super.init(frame: .zero)
        backgroundColor = .black
        configureImageView(image)
        configureBackButton()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureImageView(_ image: UIImage?) {
        imageView.image = image
        imageView.contentMode = .scaleAspectFit
        imageView.clipsToBounds = true
        imageView.backgroundColor = .black
        addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: trailingAnchor),
            imageView.topAnchor.constraint(equalTo: topAnchor),
            imageView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    private func configureBackButton() {
        let button = UIButton(type: .custom)
        button.setImage(UIImage(named: "navigation_back_circle"), for: .normal)
        button.imageView?.contentMode = .scaleAspectFit
        button.addTarget(self, action: #selector(closePreview), for: .touchUpInside)
        addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            button.topAnchor.constraint(equalTo: topAnchor, constant: statusBarHeight + 20),
            button.widthAnchor.constraint(equalToConstant: 58),
            button.heightAnchor.constraint(equalToConstant: 58)
        ])
    }

    private var statusBarHeight: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .windowScene?
            .statusBarManager?
            .statusBarFrame
            .height ?? 44
    }

    @objc private func closePreview() {
        removeFromSuperview()
    }
}
