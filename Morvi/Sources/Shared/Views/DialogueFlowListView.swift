import UIKit

final class DialogueFlowListView: UIView {
    private let tableView = UITableView(frame: .zero, style: .plain)
    private var entries: [DialogueFlowEntry] = []

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
        tableView.backgroundColor = .clear
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = false
        tableView.alwaysBounceVertical = true
        tableView.keyboardDismissMode = .interactive
        tableView.dataSource = self
        tableView.delegate = self
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 90
        tableView.register(DialogueFlowCell.self, forCellReuseIdentifier: DialogueFlowCell.reuseIdentifier)
        addSubview(tableView)
        tableView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: trailingAnchor),
            tableView.topAnchor.constraint(equalTo: topAnchor),
            tableView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(entries: [DialogueFlowEntry]) {
        self.entries = entries
        tableView.reloadData()
    }
}

extension DialogueFlowListView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DialogueFlowCell.reuseIdentifier, for: indexPath)
        (cell as? DialogueFlowCell)?.configure(with: entries[indexPath.row])
        return cell
    }
}
