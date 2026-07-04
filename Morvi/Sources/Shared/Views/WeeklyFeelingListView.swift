import UIKit

final class WeeklyFeelingListView: UIView {
    private let tableView = CancelFriendlyTableView(frame: .zero, style: .plain)
    private let entries: [WeeklyFeelingEntry]

    init(records: [MoodEntryRecord]) {
        entries = records.enumerated().map { index, record in
            WeeklyFeelingEntry(
                moodTitle: record.moodTitle,
                bodyText: record.bodyText,
                moodAsset: record.moodAsset,
                dateText: Self.dateText(from: record.recordedAt),
                style: index.isMultiple(of: 2) ? .lime : .aqua
            )
        }
        super.init(frame: .zero)
        configureView(records: records)
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureView(records: [MoodEntryRecord]) {
        backgroundColor = .clear

        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.contentInsetAdjustmentBehavior = .never
        tableView.contentInset.bottom = 104
        tableView.verticalScrollIndicatorInsets.bottom = 104
        tableView.estimatedRowHeight = 150
        tableView.rowHeight = UITableView.automaticDimension
        tableView.dataSource = self
        tableView.delegate = self
        tableView.register(WeeklyFeelingCell.self, forCellReuseIdentifier: WeeklyFeelingCell.reuseIdentifier)
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        if entries.isEmpty {
            tableView.tableHeaderView = nil
            tableView.backgroundView = EmptyStateView(copy: "No feelings yet")
        } else {
            let screenBounds = UIScreen.main.bounds
            let headerWidth = min(screenBounds.width, screenBounds.height)
            tableView.tableHeaderView = WeeklyFeelingHeaderView(
                frame: CGRect(x: 0, y: 0, width: headerWidth, height: 401),
                summaries: Self.daySummaries(from: records)
            )
        }
    }

    private static func daySummaries(from records: [MoodEntryRecord]) -> [WeeklyFeelingDaySummary] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 1
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: Date())?.start
            ?? calendar.startOfDay(for: Date())

        return (0..<7).map { dayOffset in
            guard let dayStart = calendar.date(
                byAdding: .day,
                value: dayOffset,
                to: startOfWeek
            ),
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                return WeeklyFeelingDaySummary(moodAsset: nil, entryCount: 0)
            }
            let dayRecords = records.filter {
                guard let date = LocalDateText.date(from: $0.recordedAt) else { return false }
                return date >= dayStart && date < dayEnd
            }
            let grouped = Dictionary(grouping: dayRecords, by: \.moodCode)
            let dominantGroup = grouped.values.max { first, second in
                if first.count == second.count {
                    let firstDate = first.compactMap { LocalDateText.date(from: $0.recordedAt) }.max() ?? .distantPast
                    let secondDate = second.compactMap { LocalDateText.date(from: $0.recordedAt) }.max() ?? .distantPast
                    return firstDate < secondDate
                }
                return first.count < second.count
            }
            return WeeklyFeelingDaySummary(
                moodAsset: dominantGroup?.first?.moodAsset,
                entryCount: dominantGroup?.count ?? 0
            )
        }
    }

    private static func dateText(from storedText: String) -> String {
        guard let date = LocalDateText.date(from: storedText) else { return storedText }
        return displayDateFormatter.string(from: date)
    }

    private static let displayDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "d MMMM yyyy\nh : mma"
        return formatter
    }()
}

extension WeeklyFeelingListView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(
            withIdentifier: WeeklyFeelingCell.reuseIdentifier,
            for: indexPath
        ) as? WeeklyFeelingCell else {
            return UITableViewCell()
        }
        cell.configure(with: entries[indexPath.row], isLast: indexPath.row == entries.count - 1)
        return cell
    }
}
