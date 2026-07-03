import UIKit

final class UploadThemeFlowView: UIView {
    private let values = ["Travel", "Food", "Family", "Friends", "Lifestyle"]
    private var selectedValues: Set<String> = ["Travel"]
    private var optionButtons: [UIButton] = []
    private var borderLayers: [UIButton: CAShapeLayer] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureOptions()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let horizontalSpacing: CGFloat = 8
        let verticalSpacing: CGFloat = 8
        let itemHeight: CGFloat = 45
        var origin = CGPoint.zero

        for button in optionButtons {
            let textWidth = ceil(
                (button.currentTitle! as NSString).size(
                    withAttributes: [.font: AppFont.source(14)]
                ).width
            )
            let itemWidth = textWidth + 32
            if origin.x > 0, origin.x + itemWidth > bounds.width {
                origin.x = 0
                origin.y += itemHeight + verticalSpacing
            }

            button.frame = CGRect(x: origin.x, y: origin.y, width: itemWidth, height: itemHeight)
            borderLayers[button]?.frame = button.bounds
            borderLayers[button]?.path = UIBezierPath(
                roundedRect: button.bounds.insetBy(dx: 0.5, dy: 0.5),
                cornerRadius: 10
            ).cgPath
            origin.x += itemWidth + horizontalSpacing
        }
    }

    private func configureOptions() {
        values.enumerated().forEach { index, value in
            let button = UIButton(type: .custom)
            button.tag = index
            button.setTitle(value, for: .normal)
            button.setTitleColor(.darkGray, for: .normal)
            button.titleLabel?.font = AppFont.source(14)
            button.layer.cornerRadius = 10
            button.layer.masksToBounds = true
            button.addTarget(self, action: #selector(toggleOption(_:)), for: .touchUpInside)
            addSubview(button)
            optionButtons.append(button)

            let borderLayer = CAShapeLayer()
            borderLayer.fillColor = UIColor.clear.cgColor
            borderLayer.lineWidth = 1
            borderLayer.lineDashPattern = [3, 2]
            button.layer.addSublayer(borderLayer)
            borderLayers[button] = borderLayer
            applyAppearance(to: button, isSelected: selectedValues.contains(value))
        }
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

    private func applyAppearance(to button: UIButton, isSelected: Bool) {
        button.backgroundColor = isSelected
            ? UIColor(red: 0.94, green: 1, blue: 0.72, alpha: 1)
            : UIColor(red: 0.9, green: 0.9, blue: 0.9, alpha: 0.5)
        borderLayers[button]?.strokeColor = isSelected
            ? UIColor(red: 165 / 255, green: 214 / 255, blue: 63 / 255, alpha: 1).cgColor
            : UIColor(red: 0.75, green: 0.75, blue: 0.75, alpha: 1).cgColor
    }
}
