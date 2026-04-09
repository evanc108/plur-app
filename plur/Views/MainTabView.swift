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
    let scheduleCacheStore: ScheduleCacheStore

    @State private var selected: PLURTab = .home
    @State private var keyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch selected {
                case .home: PartiesView(scheduleCacheStore: scheduleCacheStore)
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
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { notification in
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                keyboardVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { notification in
            let duration = notification.userInfo?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double ?? 0.25
            withAnimation(.easeOut(duration: duration)) {
                keyboardVisible = false
            }
        }
    }

    private var tabBar: some View {
        HStack {
            ForEach(PLURTab.allCases) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: Spacing.xxs) {
                        Circle()
                            .fill(Color.plurViolet)
                            .frame(width: 4, height: 4)
                            .opacity(selected == tab ? 1 : 0)
                            .animation(.easeOut(duration: 0.15), value: selected)
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
        .padding(.top, Spacing.xs)
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
