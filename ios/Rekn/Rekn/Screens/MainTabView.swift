import SwiftUI

struct MainTabView: View {
    @State private var groupsPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $groupsPath) {
            GroupsListScreen(path: $groupsPath)
                .navigationDestination(for: SettingsDestination.self) { _ in
                    SettingsScreen()
                }
        }
    }
}

/// Lightweight destination marker for navigation to Settings.
struct SettingsDestination: Hashable {}

#Preview {
    MainTabView()
}
