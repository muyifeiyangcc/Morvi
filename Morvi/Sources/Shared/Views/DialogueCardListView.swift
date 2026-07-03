import UIKit

final class DialogueCardListView: UIView {
    var didSelectEntry: (() -> Void)?

    private let entries: [DialogueCardEntry] = [
        DialogueCardEntry(
            name: "Victoria",
            preview: "Hello! Nice to meet\nyou. Your work is\nwonderful!",
            usesDarkStyle: false
        ),
        DialogueCardEntry(
            name: "Rowan",
            preview: "Hello! Nice to meet\nyou. Your work is\nwonderful!",
            usesDarkStyle: true
        ),
        DialogueCardEntry(
            name: "Jasper",
            preview: "Hello! Nice to meet\nyou. Your work is\nwonderful!",
            usesDarkStyle: true
        ),
        DialogueCardEntry(
            name: "Sophia",
            preview: "Hello! Nice to meet\nyou. Your work is\nwonderful!",
            usesDarkStyle: false
        )
    ]

    private let collectionView: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = CGSize(width: 164, height: 198)
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 10
        layout.sectionInset = UIEdgeInsets(top: 26, left: 20, bottom: 10, right: 19)
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)

        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.contentInset.bottom = 104
        collectionView.verticalScrollIndicatorInsets.bottom = 104
        collectionView.dataSource = self
        collectionView.delegate = self
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
}

extension DialogueCardListView: UICollectionViewDataSource, UICollectionViewDelegate {
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
        didSelectEntry?()
    }
}
