import UIKit
import ImageIO

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

    func configure(name: String, avatarAsset: String?) {
        nameLabel.text = name
        avatarView.image = resolveAvatarImage(avatarAsset) ?? UIImage(named: "default_avatar")
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
            actionIconView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            actionIconView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -16),
            actionIconView.widthAnchor.constraint(equalToConstant: 60),
            actionIconView.heightAnchor.constraint(equalToConstant: 28)
        ])
    }

    private func resolveAvatarImage(_ asset: String?) -> UIImage? {
        guard let asset, asset.isEmpty == false else { return nil }
        guard asset.hasPrefix("local-avatar/") else {
            return UIImage(named: asset)
        }
        let fileName = String(asset.dropFirst("local-avatar/".count))
        guard fileName.isEmpty == false,
              let baseDirectory = try? FileManager.default.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
              ) else {
            return nil
        }
        let fileURL = baseDirectory
            .appendingPathComponent("Morvi", isDirectory: true)
            .appendingPathComponent("Avatars", isDirectory: true)
            .appendingPathComponent(fileName)
        guard let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 480
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
