import UIKit

struct WeeklyFeelingEntry {
    enum Style {
        case lime
        case aqua

        var tintColor: UIColor {
            switch self {
            case .lime:
                return UIColor(red: 235 / 255, green: 254 / 255, blue: 175 / 255, alpha: 1)
            case .aqua:
                return UIColor(red: 224 / 255, green: 251 / 255, blue: 252 / 255, alpha: 1)
            }
        }
    }

    let moodTitle: String
    let bodyText: String
    let moodAsset: String
    let dateText: String
    let style: Style
}

final class WeeklyFeelingCell: UITableViewCell {
    static let reuseIdentifier = "WeeklyFeelingCell"

    private let cardView = UIView()
    private let gradientLayer = CAGradientLayer()
    private let moodLabel = UILabel()
    private let noteView = UIView()
    private let noteLabel = UILabel()
    private let avatarView = UIImageView()
    private let dateLabel = UILabel()
    private var bottomConstraint: NSLayoutConstraint?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        backgroundColor = .clear
        contentView.backgroundColor = .clear
        selectionStyle = .none

        cardView.layer.cornerRadius = 20
        cardView.layer.masksToBounds = true
        cardView.layer.insertSublayer(gradientLayer, at: 0)
        contentView.addSubview(cardView)
        cardView.translatesAutoresizingMaskIntoConstraints = false

        moodLabel.textColor = .darkGray
        moodLabel.font = AppFont.source(30, weight: .medium)
        cardView.addSubview(moodLabel)
        moodLabel.translatesAutoresizingMaskIntoConstraints = false

        noteView.backgroundColor = UIColor.white.withAlphaComponent(0.72)
        noteView.layer.cornerRadius = 12
        cardView.addSubview(noteView)
        noteView.translatesAutoresizingMaskIntoConstraints = false

        noteLabel.numberOfLines = 0
        noteLabel.textColor = .darkGray
        noteLabel.font = AppFont.source(15)
        noteView.addSubview(noteLabel)
        noteLabel.translatesAutoresizingMaskIntoConstraints = false

        avatarView.contentMode = .scaleAspectFit
        avatarView.clipsToBounds = true
        avatarView.layer.cornerRadius = 20
        cardView.addSubview(avatarView)
        avatarView.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.numberOfLines = 0
        dateLabel.textAlignment = .right
        dateLabel.textColor = .darkGray
        dateLabel.font = AppFont.source(12)
        cardView.addSubview(dateLabel)
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        bottomConstraint = cardView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -24)
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 20),
            cardView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -20),
            cardView.topAnchor.constraint(equalTo: contentView.topAnchor),
            bottomConstraint!,

            moodLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            moodLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 16),

            noteView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            noteView.topAnchor.constraint(equalTo: moodLabel.bottomAnchor, constant: 8),
            noteView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -16),
            noteView.trailingAnchor.constraint(lessThanOrEqualTo: cardView.trailingAnchor, constant: -20),

            noteLabel.leadingAnchor.constraint(equalTo: noteView.leadingAnchor, constant: 16),
            noteLabel.trailingAnchor.constraint(equalTo: noteView.trailingAnchor, constant: -16),
            noteLabel.topAnchor.constraint(equalTo: noteView.topAnchor, constant: 12),
            noteLabel.bottomAnchor.constraint(equalTo: noteView.bottomAnchor, constant: -12),

            avatarView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -24),
            avatarView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 26),
            avatarView.widthAnchor.constraint(equalToConstant: 40),
            avatarView.heightAnchor.constraint(equalToConstant: 40),

            dateLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            dateLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 74),
            dateLabel.widthAnchor.constraint(equalToConstant: 94)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = cardView.bounds
    }

    func configure(with entry: WeeklyFeelingEntry, isLast: Bool) {
        moodLabel.text = entry.moodTitle
        noteLabel.text = entry.bodyText
        avatarView.image = UIImage(named: entry.moodAsset)
        dateLabel.text = entry.dateText
        gradientLayer.colors = [
            entry.style.tintColor.cgColor,
            entry.style.tintColor.withAlphaComponent(0).cgColor
        ]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        bottomConstraint?.constant = isLast ? -10 : -24
        setNeedsLayout()
    }
}
