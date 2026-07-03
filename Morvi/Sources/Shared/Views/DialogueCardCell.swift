import UIKit

struct DialogueCardEntry {
    let name: String
    let preview: String
    let usesDarkStyle: Bool
}

final class DialogueCardCell: UICollectionViewCell {
    static let reuseIdentifier = "DialogueCardCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let previewLabel = UILabel()
    private let actionView = UIImageView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 12
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 9

        avatarView.image = UIImage(named: "profile_avatar")
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 22

        nameLabel.font = AppFont.source(17)
        nameLabel.numberOfLines = 1
        nameLabel.lineBreakMode = .byTruncatingTail

        previewLabel.font = AppFont.source(15)
        previewLabel.numberOfLines = 3
        previewLabel.lineBreakMode = .byTruncatingTail

        actionView.contentMode = .scaleAspectFit

        [avatarView, nameLabel, previewLabel, actionView].forEach {
            contentView.addSubview($0)
            $0.translatesAutoresizingMaskIntoConstraints = false
        }

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 18),
            avatarView.widthAnchor.constraint(equalToConstant: 44),
            avatarView.heightAnchor.constraint(equalToConstant: 44),

            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 64),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
            nameLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            previewLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            previewLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            previewLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 12),
            previewLabel.bottomAnchor.constraint(lessThanOrEqualTo: actionView.topAnchor, constant: -12),

            actionView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            actionView.widthAnchor.constraint(equalToConstant: 60),
            actionView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with entry: DialogueCardEntry) {
        contentView.backgroundColor = entry.usesDarkStyle
            ? UIColor(red: 0.04, green: 0.05, blue: 0.04, alpha: 1)
            : .white
        contentView.layer.cornerRadius = 12
        contentView.layer.masksToBounds = true
        nameLabel.text = entry.name
        nameLabel.textColor = entry.usesDarkStyle ? .white : .black
        previewLabel.text = entry.preview
        previewLabel.textColor = entry.usesDarkStyle ? .white : .darkGray
        actionView.image = UIImage(
            named: entry.usesDarkStyle ? "dialogue_card_action_light" : "dialogue_card_action_dark"
        )
    }
}
