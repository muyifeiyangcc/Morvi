import UIKit

final class RestrictedRosterListView: UIView {
    struct Entry {
        let accountKey: String
        let name: String
        let avatarAsset: String?
    }

    private let entries: [Entry]
    private let accessoryImageName: String?
    var didSelectEntry: ((Entry) -> Void)?
    var didTapAction: ((Entry) -> Void)?

    private let collectionView: UICollectionView

    init(entries: [Entry], accessoryImageName: String? = nil) {
        self.entries = entries
        self.accessoryImageName = accessoryImageName
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 12
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 28, right: 20)
        collectionView = CancelFriendlyCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        configureCollectionView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    private func configureCollectionView() {
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.contentInsetAdjustmentBehavior = .never
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = false
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(RestrictedRosterCell.self, forCellWithReuseIdentifier: RestrictedRosterCell.reuseIdentifier)
        addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.leadingAnchor.constraint(equalTo: leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: trailingAnchor),
            collectionView.topAnchor.constraint(equalTo: topAnchor),
            collectionView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}

extension RestrictedRosterListView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: RestrictedRosterCell.reuseIdentifier,
            for: indexPath
        ) as? RestrictedRosterCell else {
            return UICollectionViewCell()
        }
        let entry = entries[indexPath.item]
        cell.configure(
            name: entry.name,
            avatarAsset: entry.avatarAsset,
            accessoryImageName: accessoryImageName,
            isAccessoryActionEnabled: didTapAction != nil
        )
        cell.didTapAction = { [weak self] in
            self?.didTapAction?(entry)
        }
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
        let sideInsets: CGFloat = 40
        let spacing: CGFloat = 8
        let itemWidth = floor((collectionView.bounds.width - sideInsets - spacing) / 2)
        return CGSize(width: itemWidth, height: 186)
    }
}
