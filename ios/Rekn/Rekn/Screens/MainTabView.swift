import SwiftUI

struct MainTabView: View {
    @State private var groupsPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $groupsPath) {
            GroupsListScreen(path: $groupsPath)
        }
    }
}

#Preview {
    MainTabView()
}
