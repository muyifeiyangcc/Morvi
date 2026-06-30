import UIKit

final class CustomTopLayerView: UIView {
    let backArea = UIButton(type: .custom)
    let trailingArea = UIButton(type: .custom)
    private let backIconView = UIImageView(image: UIImage(named: "navigation_back_circle"))

    var showsBackIcon = false {
        didSet {
            backIconView.isHidden = !showsBackIcon
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        backIconView.contentMode = .scaleAspectFit
        backIconView.isHidden = true
        backIconView.isUserInteractionEnabled = false
        addSubview(backIconView)
        addSubview(backArea)
        addSubview(trailingArea)
        backIconView.translatesAutoresizingMaskIntoConstraints = false
        backArea.translatesAutoresizingMaskIntoConstraints = false
        trailingArea.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            backIconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            backIconView.topAnchor.constraint(equalTo: topAnchor, constant: 58),
            backIconView.widthAnchor.constraint(equalToConstant: 58),
            backIconView.heightAnchor.constraint(equalToConstant: 58),

            backArea.leadingAnchor.constraint(equalTo: leadingAnchor),
            backArea.topAnchor.constraint(equalTo: topAnchor),
            backArea.widthAnchor.constraint(equalToConstant: 88),
            backArea.heightAnchor.constraint(equalToConstant: 132),

            trailingArea.trailingAnchor.constraint(equalTo: trailingAnchor),
            trailingArea.topAnchor.constraint(equalTo: topAnchor),
            trailingArea.widthAnchor.constraint(equalToConstant: 92),
            trailingArea.heightAnchor.constraint(equalToConstant: 132)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }
}
