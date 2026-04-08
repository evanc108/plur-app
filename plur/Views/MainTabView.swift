import SwiftUI

enum PLURTab: String, CaseIterable, Identifiable {
    case home = "Home"
    case search = "Search"
    case inbox = "Inbox"
    case profile = "Profile"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .home: "house.fill"
        case .search: "magnifyingglass"
        case .inbox: "tray.fill"
        case .profile: "person.fill"
        }
    }
}

struct MainTabView: View {
    @State private var selected: PLURTab = .home
    @State private var keyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selected {
                case .home: PartiesView()
                case .search: RavesView()
                case .inbox: InboxView()
                case .profile: ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !keyboardVisible {
                tabBar
            }
        }
        .plurBackground()
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            keyboardVisible = true
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardVisible = false
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(PLURTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: Spacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        Text(tab.rawValue)
                            .font(.plurMicro())
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selected == tab ? Color.plurGhost : Color.plurFaint)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.xs)
        .background(
            Rectangle()
                .fill(Color.plurVoid)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color.plurBorder)
                        .frame(height: 1)
                }
                .ignoresSafeArea(.container, edges: .bottom)
        )
    }
}
