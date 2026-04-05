import SwiftUI

@main
struct ReknApp: App {
    @State private var authManager = AuthManager()
    @State private var groupStore = GroupStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    MainTabView()
                } else {
                    PhoneEntryScreen()
                }
            }
            .environment(authManager)
            .environment(groupStore)
            .task {
                await authManager.checkExistingSession()
            }
        }
    }
}
