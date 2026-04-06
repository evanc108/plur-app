import SwiftUI

struct ProfileView: View {
    @Environment(AuthService.self) private var authService

    var body: some View {
        NavigationStack {
            VStack {
                Text("Profile")
            }
            .navigationTitle("Profile")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Sign Out") {
                        Task {
                            try? await authService.signOut()
                        }
                    }
                }
            }
        }
    }
}
