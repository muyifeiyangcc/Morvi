import UIKit

final class DialogueFlowCell: UITableViewCell {
    static let reuseIdentifier = "DialogueFlowCell"
    private let revealFeedbackGenerator = UISelectionFeedbackGenerator()
    private var revealTimer: Timer?
    private var revealCharacters: [Character] = []
    private var revealIndex = 0

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        revealTimer?.invalidate()
        revealTimer = nil
        contentView.subviews.forEach { $0.removeFromSuperview() }
    }

    func configure(with entry: DialogueFlowEntry) {
        revealTimer?.invalidate()
        revealTimer = nil
        contentView.subviews.forEach { $0.removeFromSuperview() }
        switch entry {
        case .moment(let title):
            configureMoment(title)
        case .wideAsset(let name, let title, let revealsCharacters, _):
            configureWideAsset(name: name, title: title, revealsCharacters: revealsCharacters)
        case .phrase(let text, let side, let showsAvatar):
            configurePhrase(text: text, side: side, showsAvatar: showsAvatar)
        case .roundedPhrase(let text, let side, let showsAvatar, let revealsCharacters, _):
            configureRoundedPhrase(text: text, side: side, showsAvatar: showsAvatar, revealsCharacters: revealsCharacters)
        case .audioClip(let durationText, let side, let showsAvatar):
            configureAudioClip(durationText: durationText, side: side, showsAvatar: showsAvatar)
        case .portraitAsset(let name, let side, let showsAvatar):
            configurePortraitAsset(name: name, side: side, showsAvatar: showsAvatar)
        }
    }

    private func configureMoment(_ title: String) {
        let label = UILabel()
        label.text = title
        label.textColor = UIColor.black.withAlphaComponent(0.36)
        label.font = AppFont.source(12)
        label.textAlignment = .center
        contentView.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            label.heightAnchor.constraint(equalToConstant: 18),
            label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -22)
        ])
    }

    private func configureWideAsset(name: String, title: String?, revealsCharacters: Bool) {
        let image = UIImage(named: name)
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 18
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        var constraints: [NSLayoutConstraint] = []
        if let title {
            let titlePanel = IntroCopyPanelView(title: title, revealsCharacters: revealsCharacters)
            contentView.addSubview(titlePanel)
            titlePanel.translatesAutoresizingMaskIntoConstraints = false
            constraints.append(contentsOf: [
                titlePanel.leadingAnchor.constraint(equalTo: imageView.leadingAnchor, constant: 16),
                titlePanel.trailingAnchor.constraint(equalTo: imageView.trailingAnchor, constant: -16),
                titlePanel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -16)
            ])
        }

        let ratio = (image?.size.height ?? 265) / max(image?.size.width ?? 335, 1)
        constraints.append(contentsOf: [
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: ratio),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ])
        NSLayoutConstraint.activate(constraints)
    }

    private func configurePhrase(text: String, side: DialogueFlowSide, showsAvatar: Bool) {
        let bubble = ArrowBubbleView(
            text: text,
            pointerSide: side == .local ? .right : .left,
            fillColor: side == .local
                ? UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1)
                : UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1),
            strokeColor: side == .local
                ? UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1)
                : UIColor.systemBlue.withAlphaComponent(0.4)
        )
        contentView.addSubview(bubble)
        bubble.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 206),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ]

        if side == .local {
            constraints.append(bubble.trailingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 288))
            addAvatarIfNeeded(showsAvatar, side: side, topAnchor: bubble.topAnchor)
        } else {
            constraints.append(bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 86))
            addAvatarIfNeeded(showsAvatar, side: side, topAnchor: bubble.topAnchor)
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func configureRoundedPhrase(
        text: String,
        side: DialogueFlowSide,
        showsAvatar: Bool,
        revealsCharacters: Bool
    ) {
        let bubble = UIView()
        bubble.backgroundColor = side == .local
            ? UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1)
            : UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1)
        bubble.layer.cornerRadius = 15
        bubble.layer.borderWidth = 1
        bubble.layer.borderColor = (side == .local
            ? UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1)
            : UIColor.systemBlue.withAlphaComponent(0.4)).cgColor
        bubble.layer.maskedCorners = side == .local
            ? [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMinXMaxYCorner]
            : [.layerMinXMinYCorner, .layerMaxXMinYCorner, .layerMaxXMaxYCorner]
        bubble.layer.masksToBounds = true
        contentView.addSubview(bubble)
        bubble.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = revealsCharacters ? "" : text
        label.numberOfLines = 0
        label.textColor = UIColor(red: 0.17, green: 0.22, blue: 0.18, alpha: 1)
        label.font = AppFont.source(16)
        bubble.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false

        let sizingLabel = UILabel()
        sizingLabel.text = text
        sizingLabel.numberOfLines = 0
        sizingLabel.textColor = label.textColor
        sizingLabel.font = label.font
        sizingLabel.alpha = 0
        bubble.addSubview(sizingLabel)
        sizingLabel.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubble.widthAnchor.constraint(lessThanOrEqualToConstant: 267),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18),
            label.leadingAnchor.constraint(equalTo: bubble.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: bubble.trailingAnchor, constant: -14),
            label.topAnchor.constraint(equalTo: bubble.topAnchor, constant: 10),
            label.bottomAnchor.constraint(equalTo: bubble.bottomAnchor, constant: -10),
            sizingLabel.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            sizingLabel.trailingAnchor.constraint(equalTo: label.trailingAnchor),
            sizingLabel.topAnchor.constraint(equalTo: label.topAnchor),
            sizingLabel.bottomAnchor.constraint(equalTo: label.bottomAnchor)
        ]

        if side == .local {
            constraints.append(bubble.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: showsAvatar ? -87 : -20
            ))
        } else {
            constraints.append(bubble.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: showsAvatar ? 86 : 20
            ))
        }

        NSLayoutConstraint.activate(constraints)
        addAvatarIfNeeded(showsAvatar, side: side, topAnchor: bubble.topAnchor)
        if revealsCharacters {
            beginCharacterReveal(text: text, label: label)
        }
    }

    private func beginCharacterReveal(text: String, label: UILabel) {
        revealTimer?.invalidate()
        revealCharacters = Array(text)
        revealIndex = 0
        label.text = ""
        revealFeedbackGenerator.prepare()
        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.045, repeats: true) { [weak self, weak label] timer in
            guard let self, let label else {
                timer.invalidate()
                return
            }
            if self.revealIndex >= self.revealCharacters.count {
                timer.invalidate()
                self.revealTimer = nil
                return
            }
            self.revealIndex += 1
            label.text = String(self.revealCharacters.prefix(self.revealIndex))
            self.revealFeedbackGenerator.selectionChanged()
            self.revealFeedbackGenerator.prepare()
        }
    }

    private func configureAudioClip(durationText: String, side: DialogueFlowSide, showsAvatar: Bool) {
        let bubble = AudioClipBubbleView(
            durationText: durationText,
            pointerSide: side == .local ? .right : .left,
            fillColor: side == .local
                ? UIColor(red: 0.92, green: 1, blue: 0.78, alpha: 1)
                : UIColor(red: 0.96, green: 0.99, blue: 1, alpha: 1),
            strokeColor: side == .local
                ? UIColor(red: 0.56, green: 0.78, blue: 0.22, alpha: 1)
                : UIColor.systemBlue.withAlphaComponent(0.4)
        )
        contentView.addSubview(bubble)
        bubble.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            bubble.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            bubble.widthAnchor.constraint(equalToConstant: 71),
            bubble.heightAnchor.constraint(equalToConstant: 36),
            bubble.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ]

        if side == .local {
            constraints.append(bubble.trailingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 288))
        } else {
            constraints.append(bubble.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 86))
        }

        NSLayoutConstraint.activate(constraints)
        addAvatarIfNeeded(showsAvatar, side: side, topAnchor: bubble.topAnchor)
    }

    private func configurePortraitAsset(name: String, side: DialogueFlowSide, showsAvatar: Bool) {
        let image = UIImage(named: name)
        let width: CGFloat = 160
        let ratio = (image?.size.height ?? width) / max(image?.size.width ?? width, 1)

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        contentView.addSubview(imageView)
        imageView.translatesAutoresizingMaskIntoConstraints = false

        var constraints = [
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 0),
            imageView.widthAnchor.constraint(equalToConstant: width),
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor, multiplier: ratio),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -18)
        ]

        if side == .local {
            constraints.append(imageView.trailingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 288))
            addAvatarIfNeeded(showsAvatar, side: side, topAnchor: imageView.topAnchor)
        } else {
            constraints.append(imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 86))
            addAvatarIfNeeded(showsAvatar, side: side, topAnchor: imageView.topAnchor)
        }

        NSLayoutConstraint.activate(constraints)
    }

    private func addAvatarIfNeeded(_ isVisible: Bool, side: DialogueFlowSide, topAnchor: NSLayoutYAxisAnchor) {
        guard isVisible else { return }
        let avatarView = UIImageView(image: UIImage(named: "profile_avatar"))
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22
        contentView.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        let leading = side == .local
            ? avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 306)
            : avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 26)

        NSLayoutConstraint.activate([
            leading,
            avatarView.topAnchor.constraint(equalTo: topAnchor, constant: -2),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44)
        ])
    }
}
