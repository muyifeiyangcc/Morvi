import Foundation

final class LocalDataStack {
    static let shared = LocalDataStack()

    private let migrator = LocalDataMigrator()
    private let seeder = LocalSeedLoader()
    private var didPrepare = false

    private init() {}

    func prepareIfNeeded() {
        guard !didPrepare else { return }
        do {
            try migrator.run()
            try seeder.seedIfNeeded()
            didPrepare = true
        } catch {
            assertionFailure(error.localizedDescription)
        }
    }
}
