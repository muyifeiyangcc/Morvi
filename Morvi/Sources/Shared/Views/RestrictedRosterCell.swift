import UIKit

final class RestrictedRosterCell: UICollectionViewCell {
    static let reuseIdentifier = "RestrictedRosterCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let actionIconView = UIImageView(image: UIImage(named: "restricted_restore_icon"))

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureCell()
        configureAvatar()
        configureNameLabel()
        configureActionIcon()
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        avatarView.image = nil
        nameLabel.text = nil
    }

    func configure(name: String, avatarAsset: String) {
        nameLabel.text = name
        avatarView.image = UIImage(named: avatarAsset)
    }

    private func configureCell() {
        backgroundColor = .clear
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.08
        layer.shadowRadius = 14
        layer.shadowOffset = CGSize(width: 0, height: 8)

        contentView.backgroundColor = .white
        contentView.layer.cornerRadius = 12
        contentView.layer.borderWidth = 0.5
        contentView.layer.borderColor = UIColor(white: 0, alpha: 0.04).cgColor
        contentView.layer.masksToBounds = true
    }

    private func configureAvatar() {
        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 32
        contentView.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 27),
            avatarView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            avatarView.widthAnchor.constraint(equalToConstant: 64),
            avatarView.heightAnchor.constraint(equalToConstant: 64)
        ])
    }

    private func configureNameLabel() {
        nameLabel.font = AppFont.source(17, weight: .regular)
        nameLabel.textColor = .black
        nameLabel.textAlignment = .center
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            nameLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 101),
            nameLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
            nameLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12)
        ])
    }

    private func configureActionIcon() {
        actionIconView.contentMode = .scaleAspectFit
        contentView.addSubview(actionIconView)
        actionIconView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            actionIconView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            actionIconView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 140),
            actionIconView.widthAnchor.constraint(equalToConstant: 60),
            actionIconView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }
}
