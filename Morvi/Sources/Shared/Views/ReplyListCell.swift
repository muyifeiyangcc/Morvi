import UIKit

final class ReplyListCell: UITableViewCell {
    static let reuseIdentifier = "ReplyListCell"

    private let avatarView = UIImageView()
    private let nameLabel = UILabel()
    private let moreIconView = UIImageView()
    private let bodyLabel = UILabel()
    private let dividerView = UIView()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        configureView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with item: ReplyListItem, showsDivider: Bool) {
        avatarView.image = UIImage(named: "profile_avatar")
        nameLabel.text = item.name
        bodyLabel.text = item.text
        dividerView.isHidden = !showsDivider
    }

    private func configureView() {
        selectionStyle = .none
        backgroundColor = .clear
        contentView.backgroundColor = .clear

        avatarView.contentMode = .scaleAspectFill
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 19
        contentView.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        nameLabel.font = AppFont.source(16, weight: .medium)
        nameLabel.textColor = .black
        contentView.addSubview(nameLabel)
        nameLabel.translatesAutoresizingMaskIntoConstraints = false

        moreIconView.image = UIImage(named: "feed_more_icon")
        moreIconView.contentMode = .scaleAspectFit
        contentView.addSubview(moreIconView)
        moreIconView.translatesAutoresizingMaskIntoConstraints = false

        bodyLabel.font = AppFont.source(16)
        bodyLabel.textColor = .darkGray
        bodyLabel.numberOfLines = 0
        contentView.addSubview(bodyLabel)
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false

        dividerView.backgroundColor = UIColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.5)
        contentView.addSubview(dividerView)
        dividerView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            avatarView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            avatarView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            avatarView.widthAnchor.constraint(equalToConstant: 38),
            avatarView.heightAnchor.constraint(equalToConstant: 38),

            nameLabel.leadingAnchor.constraint(equalTo: avatarView.trailingAnchor, constant: 10),
            nameLabel.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),

            moreIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            moreIconView.centerYAnchor.constraint(equalTo: avatarView.centerYAnchor),
            moreIconView.widthAnchor.constraint(equalToConstant: 24),
            moreIconView.heightAnchor.constraint(equalToConstant: 24),

            bodyLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            bodyLabel.topAnchor.constraint(equalTo: avatarView.bottomAnchor, constant: 14),

            dividerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            dividerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            dividerView.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 14),
            dividerView.heightAnchor.constraint(equalToConstant: 1),
            dividerView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }
}
