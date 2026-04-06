import SwiftUI

@main
struct plurApp: App {
    @State private var authService = AuthService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(authService)
        }
    }
}
