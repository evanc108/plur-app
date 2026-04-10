import SwiftUI

enum PartyTab: String, CaseIterable {
    case schedule = "Schedule"
    case chat = "Chat"
    case board = "Board"
    case photos = "Album"

    var icon: String {
        switch self {
        case .schedule: "calendar.badge.clock"
        case .chat: "bubble.left.and.bubble.right"
        case .board: "list.clipboard"
        case .photos: "photo.on.rectangle"
        }
    }
}

struct PartyDetailView: View {
    let party: RaveGroup
    @Bindable var partyVM: PartyViewModel
    @Bindable var chatVM: ChatViewModel
    @Bindable var photosVM: PhotosViewModel
    @Bindable var scheduleVM: ScheduleViewModel
    @State private var selectedTab: PartyTab = .schedule

    var body: some View {
        VStack(spacing: 0) {
            innerTabBar
            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.plurVoid)
        .navigationTitle(party.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.plurVoid.opacity(0.9), for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .preferredColorScheme(.dark)
    }

    // MARK: - Inner Tab Bar (Segmented)

    private var innerTabBar: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(PartyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeOut(duration: 0.18)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 15))
                        Text(tab.rawValue)
                            .font(.plurCaption())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Spacing.xs)
                    .background(
                        selectedTab == tab
                            ? Color.plurViolet.opacity(0.25)
                            : Color.clear,
                        in: RoundedRectangle(cornerRadius: Radius.activeTab)
                    )
                    .foregroundStyle(selectedTab == tab ? Color.plurGhost : Color.plurMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Spacing.xxs)
        .background(
            RoundedRectangle(cornerRadius: Radius.tab)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .fill(Color.plurGlass)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Radius.tab)
                        .stroke(Color.plurBorder, lineWidth: 1)
                )
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.xs)
        .background(Color.plurVoid)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .board:
            BoardView(party: party, partyVM: partyVM, chatVM: chatVM)
        case .chat:
            ChatView(party: party, partyVM: partyVM, chatVM: chatVM)
        case .schedule:
            ScheduleView(party: party, partyVM: partyVM, scheduleVM: scheduleVM)
        case .photos:
            PhotosView(party: party, partyVM: partyVM, photosVM: photosVM)
        }
    }
}
