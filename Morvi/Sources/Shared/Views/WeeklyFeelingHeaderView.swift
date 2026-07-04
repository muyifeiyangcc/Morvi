import UIKit

struct WeeklyFeelingDaySummary {
    let moodAsset: String?
    let entryCount: Int
}

final class WeeklyFeelingHeaderView: UIView {
    private struct AnimatedBar {
        let fillHeightConstraint: NSLayoutConstraint
        let iconTopConstraint: NSLayoutConstraint
        let targetFillHeight: CGFloat
        let targetIconTop: CGFloat
    }

    private let days = ["Sun", "Mon", "Tue", "Wed", "Thr", "Fri", "Sat"]
    private var animatedBars: [AnimatedBar] = []
    private var hasAnimated = false

    init(frame: CGRect, summaries: [WeeklyFeelingDaySummary]) {
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
        let sideInset: CGFloat = 20
        let trackWidth: CGFloat = 40
        let availableWidth = max(frame.width, min(UIScreen.main.bounds.width, UIScreen.main.bounds.height))
        let itemGap = max(
            0,
            (availableWidth - sideInset * 2 - trackWidth * CGFloat(days.count))
                / CGFloat(days.count - 1)
        )
        let highestCount = max(summaries.map(\.entryCount).max() ?? 0, 1)
        for index in days.indices {
            let summary = index < summaries.count
                ? summaries[index]
                : WeeklyFeelingDaySummary(moodAsset: nil, entryCount: 0)
            let fillHeight = summary.entryCount == 0
                ? 0
                : 200 * CGFloat(summary.entryCount) / CGFloat(highestCount)
            addBar(
                day: days[index],
                iconName: summary.moodAsset,
                fillHeight: fillHeight,
                top: barTop,
                left: sideInset + CGFloat(index) * (trackWidth + itemGap)
            )
        }
    }

    required init?(coder: NSCoder) {
        nil
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, hasAnimated == false else { return }
        hasAnimated = true
        layoutIfNeeded()
        animatedBars.forEach {
            $0.fillHeightConstraint.constant = $0.targetFillHeight
            $0.iconTopConstraint.constant = $0.targetIconTop
        }
        UIView.animate(
            withDuration: 0.7,
            delay: 0.08,
            options: [.curveEaseOut, .allowUserInteraction],
            animations: { self.layoutIfNeeded() }
        )
    }

    private func addBar(day: String, iconName: String?, fillHeight: CGFloat, top: CGFloat, left: CGFloat) {
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

        let iconView = UIImageView(image: iconName.flatMap(UIImage.init(named:)))
        iconView.contentMode = .scaleAspectFit
        iconView.isHidden = iconName == nil
        addSubview(iconView)
        iconView.translatesAutoresizingMaskIntoConstraints = false

        let dayLabel = UILabel()
        dayLabel.text = day
        dayLabel.textColor = .darkGray
        dayLabel.font = AppFont.source(16)
        addSubview(dayLabel)
        dayLabel.translatesAutoresizingMaskIntoConstraints = false

        let initialIconTop = top + 220 - 55
        let targetIconTop = top + 220 - fillHeight - 55
        let fillHeightConstraint = fillView.heightAnchor.constraint(equalToConstant: 0)
        let iconTopConstraint = iconView.topAnchor.constraint(
            equalTo: topAnchor,
            constant: initialIconTop
        )
        animatedBars.append(
            AnimatedBar(
                fillHeightConstraint: fillHeightConstraint,
                iconTopConstraint: iconTopConstraint,
                targetFillHeight: fillHeight,
                targetIconTop: targetIconTop
            )
        )

        NSLayoutConstraint.activate([
            trackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left),
            trackView.topAnchor.constraint(equalTo: topAnchor, constant: top),
            trackView.widthAnchor.constraint(equalToConstant: 40),
            trackView.heightAnchor.constraint(equalToConstant: 220),

            fillView.leadingAnchor.constraint(equalTo: trackView.leadingAnchor),
            fillView.trailingAnchor.constraint(equalTo: trackView.trailingAnchor),
            fillView.bottomAnchor.constraint(equalTo: trackView.bottomAnchor),
            fillHeightConstraint,

            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left - 10),
            iconTopConstraint,
            iconView.widthAnchor.constraint(equalToConstant: 60),
            iconView.heightAnchor.constraint(equalToConstant: 60),

            dayLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: left + 3),
            dayLabel.topAnchor.constraint(equalTo: topAnchor, constant: top + 233)
        ])
    }
}
