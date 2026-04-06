import SwiftUI

struct ContentView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        Group {
            if authService.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .task {
            await authService.checkSession()
        }
    }
}
