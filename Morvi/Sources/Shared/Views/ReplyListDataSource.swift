import UIKit

final class ReplyListDataSource: NSObject, UITableViewDataSource, UITableViewDelegate {
    private var items: [ReplyListItem] = []

    func apply(_ items: [ReplyListItem], to tableView: UITableView) {
        self.items = items
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
        replyCell.configure(with: items[indexPath.row], showsDivider: !isLastItem)
        return replyCell
    }
}
