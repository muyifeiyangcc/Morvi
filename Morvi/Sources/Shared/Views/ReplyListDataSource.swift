import UIKit

final class ReplyListDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private var items: [ReplyListItem] = []
    var didTapMore: ((String) -> Void)?

    func apply(_ items: [ReplyListItem], to tableView: UITableView) {
        self.items = items
        tableView.backgroundView = items.isEmpty ? EmptyStateView() : nil
        tableView.reloadData()
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: ReplyListCell.reuseIdentifier, for: indexPath)
        guard let replyCell = cell as? ReplyListCell else {
            return cell
        }
        let isLastItem = indexPath.row == items.count - 1
        let item = items[indexPath.row]
        replyCell.configure(with: item, showsDivider: !isLastItem)
        replyCell.didTapMore = { [weak self] in
            self?.didTapMore?(item.accountKey)
        }
        return replyCell
    }
}
