import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Groups", systemImage: "rectangle.3.group") {
                NavigationStack {
                    GroupsListScreen()
                }
            }
            Tab("Settings", systemImage: "gearshape") {
                NavigationStack {
                    SettingsScreen()
                }
            }
        }
    }
}

#Preview {
    MainTabView()
}
