import UIKit

final class DialogueFlowCell: UITableViewCell {
    static let reuseIdentifier = "DialogueFlowCell"

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
        contentView.subviews.forEach { $0.removeFromSuperview() }
    }

    func configure(with entry: DialogueFlowEntry) {
        contentView.subviews.forEach { $0.removeFromSuperview() }
        switch entry {
        case .moment(let title):
            configureMoment(title)
        case .phrase(let text, let side, let showsAvatar):
            configurePhrase(text: text, side: side, showsAvatar: showsAvatar)
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
