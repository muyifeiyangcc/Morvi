import UIKit

final class UploadThemeFlowView: UIView {
    private var values = ["Travel", "Food", "Family", "Friends", "Lifestyle"]
    private var selectedValues: Set<String> = ["Travel"]
    private var optionButtons: [UIButton] = []
    private let addButton = UIButton(type: .custom)
    private var borderLayers: [UIButton: CAShapeLayer] = [:]
    var didRequestEntry: (() -> Void)?

    var selectedTitles: [String] {
        values.filter { selectedValues.contains($0) }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureOptions()
        configureAddButton()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutItems()
    }

    func appendTheme(_ rawValue: String) {
        let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.isEmpty == false else { return }

        if let existingValue = values.first(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            selectedValues.insert(existingValue)
            optionButtons.forEach { button in
                guard let text = button.currentTitle else { return }
                applyAppearance(to: button, isSelected: selectedValues.contains(text))
            }
            return
        }

        values.append(value)
        selectedValues.insert(value)
        addOptionButton(title: value, index: values.count - 1)
        setNeedsLayout()
    }

    private func layoutItems() {
        let horizontalSpacing: CGFloat = 8
        let verticalSpacing: CGFloat = 8
        var origin = CGPoint.zero
        var rowHeight: CGFloat = 0

        for item in optionButtons + [addButton] {
            let itemSize = size(for: item)
            if origin.x > 0, origin.x + itemSize.width > bounds.width {
                origin.x = 0
                origin.y += rowHeight + verticalSpacing
                rowHeight = 0
            }

            item.frame = CGRect(origin: origin, size: itemSize)
            borderLayers[item]?.frame = item.bounds
            borderLayers[item]?.path = UIBezierPath(
                roundedRect: item.bounds.insetBy(dx: 0.5, dy: 0.5),
                cornerRadius: 10
            ).cgPath
            origin.x += itemSize.width + horizontalSpacing
            rowHeight = max(rowHeight, itemSize.height)
        }
    }

    private func configureOptions() {
        values.enumerated().forEach { index, value in
            addOptionButton(title: value, index: index)
        }
    }

    private func addOptionButton(title: String, index: Int) {
        let button = UIButton(type: .custom)
        button.tag = index
        button.setTitle(title, for: .normal)
        button.setTitleColor(.darkGray, for: .normal)
        button.titleLabel?.font = AppFont.source(14)
        button.layer.cornerRadius = 10
        button.layer.masksToBounds = true
        button.addTarget(self, action: #selector(toggleOption(_:)), for: .touchUpInside)
        addSubview(button)
        optionButtons.append(button)

        let borderLayer = makeBorderLayer()
        button.layer.addSublayer(borderLayer)
        borderLayers[button] = borderLayer
        applyAppearance(to: button, isSelected: selectedValues.contains(title))
    }

    private func configureAddButton() {
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(UIColor(white: 0.45, alpha: 1), for: .normal)
        addButton.titleLabel?.font = AppFont.source(34)
        addButton.backgroundColor = UIColor(red: 212 / 255, green: 1, blue: 59 / 255, alpha: 0.3)
        addButton.layer.cornerRadius = 10
        addButton.layer.masksToBounds = true
        addButton.addTarget(self, action: #selector(handleAddTheme), for: .touchUpInside)
        addSubview(addButton)

        let borderLayer = makeBorderLayer()
        borderLayer.strokeColor = UIColor(red: 165 / 255, green: 214 / 255, blue: 63 / 255, alpha: 1).cgColor
        addButton.layer.addSublayer(borderLayer)
        borderLayers[addButton] = borderLayer
    }

    private func makeBorderLayer() -> CAShapeLayer {
        let borderLayer = CAShapeLayer()
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 1
        borderLayer.lineDashPattern = [3, 2]
        return borderLayer
    }

    private func size(for button: UIButton) -> CGSize {
        if button === addButton {
            return CGSize(width: 96, height: 60)
        }

        let textWidth = ceil(
            ((button.currentTitle ?? "") as NSString).size(
                withAttributes: [.font: AppFont.source(14)]
            ).width
        )
        return CGSize(width: textWidth + 32, height: 45)
    }

    @objc private func toggleOption(_ button: UIButton) {
        let value = values[button.tag]
        if selectedValues.contains(value) {
            selectedValues.remove(value)
        } else {
            selectedValues.insert(value)
        }
        applyAppearance(to: button, isSelected: selectedValues.contains(value))
    }

    @objc private func handleAddTheme() {
        didRequestEntry?()
    }

    private func applyAppearance(to button: UIButton, isSelected: Bool) {
        button.backgroundColor = isSelected
            ? UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
            : UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        borderLayers[button]?.strokeColor = isSelected
            ? UIColor(red: 165 / 255, green: 214 / 255, blue: 63 / 255, alpha: 1).cgColor
            : UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1).cgColor
    }
}
