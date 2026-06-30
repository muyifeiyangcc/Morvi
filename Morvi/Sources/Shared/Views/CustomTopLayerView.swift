import UIKit

final class CustomTopLayerView: UIView {
    let backArea = UIButton(type: .custom)
    let trailingArea = UIButton(type: .custom)

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        addSubview(backArea)
        addSubview(trailingArea)
        backArea.translatesAutoresizingMaskIntoConstraints = false
        trailingArea.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
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
