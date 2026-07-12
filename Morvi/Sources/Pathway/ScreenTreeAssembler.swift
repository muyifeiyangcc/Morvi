import SwiftUI

struct ScreenTreeAssembler {
    func makeRootView() -> some View {
        MorviApplicationRoot(
            accessStore: AccessSessionStore(),
            experienceStore: ExperienceContainer()
        )
    }
}
