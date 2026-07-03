import UIKit

final class WeeklyFeelingListView: UIView {
    private let tableView = CancelFriendlyTableView(frame: .zero, style: .plain)
    private let entries: [WeeklyFeelingEntry] = [
        WeeklyFeelingEntry(style: .lime),
        WeeklyFeelingEntry(style: .aqua)
    ]

    override init(frame: CGRect) {
        super.init(frame: frame)
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

        let headerView = WeeklyFeelingHeaderView(frame: CGRect(x: 0, y: 0, width: 375, height: 401))
        tableView.tableHeaderView = headerView
    }

    required init?(coder: NSCoder) {
        nil
    }
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
