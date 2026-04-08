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
    @Bindable var viewModel: PartyViewModel
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
        .alert("Schedule Conflict", isPresented: $viewModel.showConflictAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Save Anyway") {
                viewModel.confirmPendingArtist()
            }
        } message: {
            Text(viewModel.conflictMessage)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Inner Tab Bar (Segmented)

    private var innerTabBar: some View {
        HStack(spacing: Spacing.xxs) {
            ForEach(PartyTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 13))
                        Text(tab.rawValue)
                            .font(.plurMicro())
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
            BoardView(party: party, viewModel: viewModel)
        case .chat:
            ChatView(party: party, viewModel: viewModel)
        case .schedule:
            ScheduleView(party: party, viewModel: viewModel)
        case .photos:
            PhotosView(party: party, viewModel: viewModel)
        }
    }
}
