import SwiftUI

@main
struct ReknApp: App {
    @State private var authManager = AuthManager()
    @State private var groupStore = GroupStore()
    @State private var inviteStore = InviteStore()
    #if DEBUG
    @State private var devStore = DevUserStore()
    #endif
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if authManager.isAuthenticated {
                        MainTabView()
                    } else {
                        PhoneEntryScreen()
                    }
                }
                #if DEBUG
                DevUserSwitcherPill(devStore: devStore)
                    .padding(.leading, 12)
                    .padding(.bottom, 8)
                #endif
            }
            .environment(authManager)
            .environment(groupStore)
            .environment(inviteStore)
            .task {
                await authManager.checkExistingSession()
                #if DEBUG
                print("[ReknApp] probing /dev/test-users")
                await devStore.probe()
                print("[ReknApp] dev availability=\(devStore.availability) users=\(devStore.users.count)")
                #endif
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active, authManager.isAuthenticated, !(authManager.currentUser?.isGuest ?? true) {
                    Task { await inviteStore.loadPending(forceReload: true) }
                }
            }
        }
    }
}
