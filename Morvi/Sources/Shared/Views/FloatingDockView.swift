import UIKit

final class FloatingDockView: UIView {
    enum Item: CaseIterable {
        case home
        case discover
        case dialogue
        case persona

        var imageName: String {
            switch self {
            case .home: "tab_home"
            case .discover: "tab_discover"
            case .dialogue: "tab_dialogue"
            case .persona: "tab_persona"
            }
        }
    }

    var selectedItem: Item = .home {
        didSet { refreshSelection() }
    }

    var didSelect: ((Item) -> Void)?

    private let stackView = UIStackView()
    private var itemButtons: [Item: UIButton] = [:]
    private var iconWidthConstraints: [Item: NSLayoutConstraint] = [:]
    private var iconHeightConstraints: [Item: NSLayoutConstraint] = [:]
    private let itemSide: CGFloat = 65
    private let inactiveIconSide: CGFloat = 45

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
        layer.cornerRadius = 37
        layer.masksToBounds = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.20
        layer.shadowOffset = CGSize(width: 0, height: 6)
        layer.shadowRadius = 14
        configureStack()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureStack() {
        addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .horizontal
        stackView.alignment = .center
        stackView.distribution = .equalSpacing
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stackView.topAnchor.constraint(equalTo: topAnchor, constant: 5.5),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5.5)
        ])

        Item.allCases.forEach { item in
            let button = UIButton(type: .custom)
            button.translatesAutoresizingMaskIntoConstraints = false
            button.layer.cornerRadius = itemSide / 2
            button.layer.masksToBounds = true
            button.addAction(UIAction { [weak self] _ in
                self?.selectedItem = item
                self?.didSelect?(item)
            }, for: .touchUpInside)
            let iconView = UIImageView(image: UIImage(named: item.imageName))
            iconView.translatesAutoresizingMaskIntoConstraints = false
            iconView.contentMode = .scaleAspectFill
            iconView.clipsToBounds = true
            iconView.isUserInteractionEnabled = false
            button.addSubview(iconView)
            let iconWidth = iconView.widthAnchor.constraint(equalToConstant: inactiveIconSide)
            let iconHeight = iconView.heightAnchor.constraint(equalToConstant: inactiveIconSide)
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: itemSide),
                button.heightAnchor.constraint(equalToConstant: itemSide),
                iconView.centerXAnchor.constraint(equalTo: button.centerXAnchor),
                iconView.centerYAnchor.constraint(equalTo: button.centerYAnchor),
                iconWidth,
                iconHeight
            ])
            itemButtons[item] = button
            iconWidthConstraints[item] = iconWidth
            iconHeightConstraints[item] = iconHeight
            stackView.addArrangedSubview(button)
        }
        refreshSelection()
    }

    private func refreshSelection() {
        itemButtons.forEach { item, button in
            let isSelected = item == selectedItem
            button.backgroundColor = isSelected ? UIColor(red: 0.78, green: 1, blue: 0.42, alpha: 1) : .clear
            button.alpha = isSelected ? 1 : 0.9
            button.layer.borderWidth = isSelected ? 3 : 0
            button.layer.borderColor = isSelected ? UIColor.black.cgColor : UIColor.clear.cgColor
            let iconSide = isSelected ? itemSide : inactiveIconSide
            iconWidthConstraints[item]?.constant = iconSide
            iconHeightConstraints[item]?.constant = iconSide
        }
    }
}
