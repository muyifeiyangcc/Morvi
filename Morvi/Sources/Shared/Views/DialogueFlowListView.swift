import UIKit

final class DialogueFlowListView: UIView {
    private let tableView = CancelFriendlyTableView(frame: .zero, style: .plain)
    private var entries: [DialogueFlowEntry] = []
    private var consumedRevealIdentifiers: Set<String> = []

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
        DispatchQueue.main.async { [weak self] in
            self?.scrollToEnd(animated: false)
        }
    }

    func scrollToEnd(animated: Bool) {
        guard entries.isEmpty == false else { return }
        tableView.layoutIfNeeded()
        tableView.scrollToRow(
            at: IndexPath(row: entries.count - 1, section: 0),
            at: .bottom,
            animated: animated
        )
    }
}

extension DialogueFlowListView: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        entries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: DialogueFlowCell.reuseIdentifier, for: indexPath)
        (cell as? DialogueFlowCell)?.configure(with: preparedEntry(at: indexPath.row))
        return cell
    }

    private func preparedEntry(at index: Int) -> DialogueFlowEntry {
        let entry = entries[index]
        switch entry {
        case .wideAsset(let name, let title, let revealsCharacters, let revealIdentifier):
            let shouldReveal = consumeRevealIdentifier(revealIdentifier, requested: revealsCharacters)
            return .wideAsset(
                name: name,
                title: title,
                revealsCharacters: shouldReveal,
                revealIdentifier: revealIdentifier
            )
        case .roundedPhrase(let text, let side, let showsAvatar, let revealsCharacters, let revealIdentifier):
            let shouldReveal = consumeRevealIdentifier(revealIdentifier, requested: revealsCharacters)
            return .roundedPhrase(
                text: text,
                side: side,
                showsAvatar: showsAvatar,
                revealsCharacters: shouldReveal,
                revealIdentifier: revealIdentifier
            )
        default:
            return entry
        }
    }

    private func consumeRevealIdentifier(_ identifier: String?, requested: Bool) -> Bool {
        guard requested else { return false }
        guard let identifier else { return true }
        guard consumedRevealIdentifiers.contains(identifier) == false else { return false }
        consumedRevealIdentifiers.insert(identifier)
        return true
    }
}
