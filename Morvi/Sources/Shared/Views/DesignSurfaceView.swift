import UIKit

final class DesignSurfaceView: UIView {
    static let baseSize = CGSize(width: 375, height: 812)

    let contentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .white
        addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            contentView.widthAnchor.constraint(equalToConstant: Self.baseSize.width),
            contentView.heightAnchor.constraint(equalToConstant: Self.baseSize.height),
            contentView.centerXAnchor.constraint(equalTo: centerXAnchor),
            contentView.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = min(bounds.width / Self.baseSize.width, bounds.height / Self.baseSize.height)
        contentView.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
