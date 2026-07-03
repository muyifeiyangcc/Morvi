import UIKit

final class WeeklyFeelingHeaderView: UIView {
    private let days = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]
    private let iconNames = [
        "weekly_mood_happy",
        "weekly_mood_panic",
        "weekly_mood_sad",
        "weekly_mood_crying",
        "weekly_mood_strained",
        "weekly_mood_calm",
        "weekly_mood_cool"
    ]
    private let fillHeights: [CGFloat] = [200, 148, 118, 82, 104, 156, 198]

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear

        let titleLabel = UILabel()
        titleLabel.text = "This week's feelings"
        titleLabel.textColor = .black
        titleLabel.font = AppFont.source(24, weight: .bold)
        addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 20),
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 60)
        ])

        let barTop = 60 + ceil(AppFont.source(24, weight: .bold).lineHeight) + 26
        for index in days.indices {
            addBar(
                day: days[index],
                iconName: iconNames[index],
                fillHeight: fillHeights[index],
                top: barTop,
                left: CGFloat(20 + index * 49)
            )
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func addBar(day: String, iconName: String, fillHeight: CGFloat, top: CGFloat, left: CGFloat) {
        let trackView = UIView()
        trackView.backgroundColor = UIColor(red: 1, green: 0.94, blue: 0.62, alpha: 1)
        trackView.layer.cornerRadius = 19
        addSubview(trackView)
        trackView.translatesAutoresizingMaskIntoConstraints = false

        let fillView = UIView()
        fillView.backgroundColor = UIColor(red: 1, green: 0.83, blue: 0.08, alpha: 1)
        fillView.layer.cornerRadius = 19
        addSubview(fillView)
        fillView.translatesAutoresizingMaskIntoConstraints = false

        let iconView = UIImageView(image: UIImage(named: iconName))
        iconView.contentMode = .scaleAspectFit
        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let dayLabel = UILabel()
        dayLabel.text = day
        dayLabel.textColor = .darkGray
        dayLabel.font = AppFont.source(16)
        addSubview(dayLabel)
        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            trackView.topAnchor.constraint(equalTo: topAnchor, constant: top),
            trackView.widthAnchor.constraint(equalToConstant: 40),
            trackView.heightAnchor.constraint(equalToConstant: 220),

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillView.heightAnchor.constraint(equalToConstant: fillHeight),

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left - 10),
            iconView.topAnchor.constraint(equalTo: topAnchor, constant: top + 220 - fillHeight - 55),
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            dayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left + 3),
            dayLabel.topAnchor.constraint(equalTo: topAnchor, constant: top + 233)
        ])
    }
}
