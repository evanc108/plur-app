import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService
    let scheduleCacheStore: ScheduleCacheStore

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView(scheduleCacheStore: scheduleCacheStore)
            } else {
                LoginView()
            }
        }
        .task {
            await authService.checkSession()
        }
    }
}
