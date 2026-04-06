import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            Tab("Raves", systemImage: "music.note.list") {
                RavesView()
            }

            Tab("Inbox", systemImage: "bubble.left.and.bubble.right") {
                InboxView()
            }

            Tab("Kandi", systemImage: "heart.circle") {
                KandiView()
            }

            Tab("Profile", systemImage: "person.crop.circle") {
                ProfileView()
            }
        }
    }
}
