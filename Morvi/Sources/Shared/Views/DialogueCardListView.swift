import UIKit

final class DialogueCardListView: UIView {
    var didSelectEntry: ((DialogueCardEntry) -> Void)?
    private enum LayoutMetric {
        static let horizontalInset: CGFloat = 20
        static let itemSpacing: CGFloat = 11
        static let itemHeight: CGFloat = 198
    }

    private var entries: [DialogueCardEntry]
    private let collectionView: UICollectionView

    init(entries: [DialogueCardEntry]) {
        self.entries = entries
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = LayoutMetric.itemSpacing
        layout.minimumLineSpacing = LayoutMetric.itemSpacing
        layout.sectionInset = UIEdgeInsets(
            top: 0,
            left: LayoutMetric.horizontalInset,
            bottom: 10,
            right: LayoutMetric.horizontalInset
        )
        collectionView = CancelFriendlyCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)

        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset.bottom = 104
        collectionView.verticalScrollIndicatorInsets.bottom = 104
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.backgroundView = entries.isEmpty ? EmptyStateView(copy: "No chats yet") : nil
        collectionView.register(
            DialogueCardCell.self,
            forCellWithReuseIdentifier: DialogueCardCell.reuseIdentifier
        )
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(entries: [DialogueCardEntry]) {
        self.entries = entries
        collectionView.backgroundView = entries.isEmpty ? EmptyStateView(copy: "No chats yet") : nil
        collectionView.reloadData()
    }
}

extension DialogueCardListView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: DialogueCardCell.reuseIdentifier,
            for: indexPath
        ) as? DialogueCardCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: entries[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectEntry?(entries[indexPath.item])
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let availableWidth = collectionView.bounds.width
            - LayoutMetric.horizontalInset * 2
            - LayoutMetric.itemSpacing
        let itemWidth = floor(availableWidth / 2)
        return CGSize(width: itemWidth, height: LayoutMetric.itemHeight)
    }
}
