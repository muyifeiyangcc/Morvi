import UIKit

final class DialogueFlowListView: UIView {
    private let tableView = CancelFriendlyTableView(frame: .zero, style: .plain)
    private var entries: [DialogueFlowEntry] = []
    private var consumedRevealIdentifiers: Set<String> = []
    private var activeAudioIndex: Int?
    private var audioPlaybackTimer: Timer?
    var didRequestImagePreview: ((String) -> Void)?

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

    deinit {
        audioPlaybackTimer?.invalidate()
    }

    func configure(entries: [DialogueFlowEntry]) {
        self.entries = entries
        activeAudioIndex = nil
        audioPlaybackTimer?.invalidate()
        audioPlaybackTimer = nil
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
        (cell as? DialogueFlowCell)?.configure(
            with: preparedEntry(at: indexPath.row),
            isAudioPlaying: activeAudioIndex == indexPath.row
        )
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let entry = entries[indexPath.row]
        switch entry {
        case .audioClip(let durationText, _, _):
            playAudioClip(at: indexPath, durationText: durationText)
        case .portraitAsset(let name, _, _):
            didRequestImagePreview?(name)
        default:
            break
        }
    }

    private func playAudioClip(at indexPath: IndexPath, durationText: String) {
        audioPlaybackTimer?.invalidate()
        var rowsToReload = [indexPath]
        if let activeAudioIndex, activeAudioIndex != indexPath.row {
            rowsToReload.append(IndexPath(row: activeAudioIndex, section: 0))
        }
        activeAudioIndex = indexPath.row
        tableView.reloadRows(at: rowsToReload, with: .none)

        let duration = playbackDuration(from: durationText)
        audioPlaybackTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            guard let self, self.activeAudioIndex == indexPath.row else { return }
            self.activeAudioIndex = nil
            self.tableView.reloadRows(at: [indexPath], with: .none)
        }
    }

    private func playbackDuration(from text: String) -> TimeInterval {
        let digits = text.filter(\.isNumber)
        let seconds = TimeInterval(digits).flatMap { $0 > 0 ? $0 : nil } ?? 1
        return min(max(seconds, 1), 60)
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
