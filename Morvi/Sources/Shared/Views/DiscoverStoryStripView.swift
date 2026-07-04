import UIKit

final class DiscoverStoryStripView: UIView {
    struct StripEntry {
        let accountKey: String?
        let title: String
        let imageName: String
        let clipsToCircle: Bool
    }

    private let entries: [StripEntry]

    var didSelectEntry: ((Int) -> Void)?

    private let collectionView: UICollectionView

    init(entries: [StripEntry] = DiscoverStoryStripView.defaultEntries()) {
        self.entries = entries
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 30
        layout.minimumInteritemSpacing = 30
        layout.sectionInset = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        collectionView = CancelFriendlyCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: .zero)
        configureCollectionView()
    }

    required init?(coder: NSCoder) {
        nil
    }

    static func defaultEntries() -> [StripEntry] {
        [
            StripEntry(accountKey: nil, title: "My works", imageName: "story_my_works_icon", clipsToCircle: false),
            StripEntry(accountKey: "acct-local-victoria", title: "Victoria", imageName: "builtin_avatar_victoria", clipsToCircle: true),
            StripEntry(accountKey: "acct-local-rowan", title: "Rowan", imageName: "builtin_avatar_rowan", clipsToCircle: true),
            StripEntry(accountKey: "acct-local-sophia", title: "Sophia", imageName: "builtin_avatar_sophia", clipsToCircle: true),
            StripEntry(accountKey: "acct-local-jasper", title: "Jasper", imageName: "builtin_avatar_jasper", clipsToCircle: true),
            StripEntry(accountKey: "acct-local-chloe", title: "Chloe", imageName: "builtin_avatar_chloe", clipsToCircle: true)
        ]
    }

    private func configureCollectionView() {
        backgroundColor = .clear
        collectionView.backgroundColor = .clear
        collectionView.showsHorizontalScrollIndicator = false
        collectionView.alwaysBounceHorizontal = true
        collectionView.contentInset = .zero
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.register(StoryStripCell.self, forCellWithReuseIdentifier: StoryStripCell.reuseIdentifier)
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

extension DiscoverStoryStripView: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        entries.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: StoryStripCell.reuseIdentifier,
            for: indexPath
        ) as? StoryStripCell else {
            return UICollectionViewCell()
        }
        cell.configure(with: entries[indexPath.item])
        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        didSelectEntry?(indexPath.item)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        let title = entries[indexPath.item].title
        let titleWidth = ceil((title as NSString).size(
            withAttributes: [.font: AppFont.source(12, weight: .regular)]
        ).width)
        return CGSize(width: max(48, titleWidth), height: 78)
    }
}

private final class StoryStripCell: UICollectionViewCell {
    static let reuseIdentifier = "StoryStripCell"

    private let imageView = UIImageView()
    private let titleLabel = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureSubviews()
    }

    required init?(coder: NSCoder) {
        nil
    }

    func configure(with entry: DiscoverStoryStripView.StripEntry) {
        imageView.image = UIImage(named: entry.imageName)
        imageView.layer.cornerRadius = entry.clipsToCircle ? 24 : 0
        imageView.layer.masksToBounds = entry.clipsToCircle
        imageView.contentMode = entry.clipsToCircle ? .scaleAspectFill : .scaleAspectFit
        titleLabel.text = entry.title
    }

    private func configureSubviews() {
        contentView.backgroundColor = .clear
        imageView.backgroundColor = .clear
        titleLabel.textAlignment = .center
        titleLabel.textColor = .black
        titleLabel.font = AppFont.source(12, weight: .regular)

        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            imageView.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.widthAnchor.constraint(equalToConstant: 48),
            imageView.heightAnchor.constraint(equalToConstant: 48),

            titleLabel.centerXAnchor.constraint(equalTo: imageView.centerXAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            titleLabel.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
}
