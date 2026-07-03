import UIKit

final class DiscoverStoryStripView: UIView {
    fileprivate struct StripEntry {
        let title: String
        let imageName: String
        let clipsToCircle: Bool
    }

    private let entries: [StripEntry] = [
        StripEntry(title: "My works", imageName: "story_my_works_icon", clipsToCircle: false),
        StripEntry(title: "Victoria", imageName: "profile_avatar", clipsToCircle: true),
        StripEntry(title: "Rowan", imageName: "profile_avatar", clipsToCircle: true),
        StripEntry(title: "Sophia", imageName: "profile_avatar", clipsToCircle: true),
        StripEntry(title: "Jasper", imageName: "profile_avatar", clipsToCircle: true)
    ]

    var didSelectEntry: ((Int) -> Void)?

    private let collectionView: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .horizontal
        layout.minimumLineSpacing = 0
        layout.minimumInteritemSpacing = 0
        layout.itemSize = CGSize(width: 76, height: 78)
        collectionView = CancelFriendlyCollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        configureCollectionView()
    }

    required init?(coder: NSCoder) {
        nil
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
        titleLabel.adjustsFontSizeToFitWidth = true
        titleLabel.minimumScaleFactor = 0.75

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
            titleLabel.widthAnchor.constraint(equalToConstant: 72),
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 6),
            titleLabel.heightAnchor.constraint(equalToConstant: 18)
        ])
    }
}
