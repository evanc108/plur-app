import SwiftUI

struct PartiesView: View {
    @State private var partyVM: PartyViewModel
    @State private var chatVM = ChatViewModel()
    @State private var photosVM = PhotosViewModel()
    @State private var scheduleVM: ScheduleViewModel
    @State private var activeSheet: ActiveSheet?

    init(scheduleCacheStore: ScheduleCacheStore) {
        _partyVM = State(initialValue: PartyViewModel())
        _scheduleVM = State(initialValue: ScheduleViewModel(scheduleCache: scheduleCacheStore))
    }

    private enum ActiveSheet: Identifiable {
        case create
        case join

        var id: String {
            switch self {
            case .create: return "create"
            case .join: return "join"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plurVoid.ignoresSafeArea()

                Group {
                    if partyVM.isLoading && partyVM.parties.isEmpty {
                        ProgressView()
                            .tint(Color.plurViolet)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if partyVM.parties.isEmpty {
                        emptyState
                    } else {
                        partyList
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("YOUR PARTIES")
                        .font(.plurHeading(24))
                        .foregroundStyle(Color.plurGhost)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: Spacing.sm) {
                        Button { activeSheet = .join } label: {
                            Image(systemName: "ticket")
                                .font(.system(size: 18))
                                .foregroundStyle(Color.plurGhost)
                        }
                        Button { activeSheet = .create } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(Color.plurGhost)
                        }
                    }
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: UUID.self) { partyID in
                if let party = partyVM.parties.first(where: { $0.id == partyID }) {
                    PartyDetailView(
                        party: party,
                        partyVM: partyVM,
                        chatVM: chatVM,
                        photosVM: photosVM,
                        scheduleVM: scheduleVM
                    )
                }
            }
            .sheet(item: $activeSheet) { sheet in
                switch sheet {
                case .create:
                    CreatePartyView(viewModel: partyVM)
                case .join:
                    JoinPartyView(viewModel: partyVM)
                }
            }
            .refreshable {
                await partyVM.loadParties()
            }
            .task {
                await partyVM.loadParties()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(Color.plurViolet.opacity(0.7))
            Text("No Parties Yet")
                .font(.plurH2())
                .foregroundStyle(Color.plurGhost)
            Text("Create a party or join one with an invite code.")
                .font(.plurBody())
                .foregroundStyle(Color.plurMuted)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    // MARK: - Party List

    private var partyList: some View {
        ScrollView {
            VStack(spacing: Spacing.xl) {
                if !upcomingParties.isEmpty {
                    sectionBlock(title: "UPCOMING", parties: upcomingParties)
                }
                if !pastParties.isEmpty {
                    sectionBlock(title: "PAST", parties: pastParties)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.lg)
        }
    }

    private func sectionBlock(title: String, parties: [RaveGroup]) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(.plurMicro())
                .foregroundStyle(Color.plurMuted)
                .tracking(1.5)

            ForEach(parties) { party in
                NavigationLink(value: party.id) {
                    PartyCard(party: party, memberCount: partyVM.members[party.id]?.count ?? 0)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var upcomingParties: [RaveGroup] {
        partyVM.parties.filter { !$0.isPast }
    }

    private var pastParties: [RaveGroup] {
        partyVM.parties.filter(\.isPast)
    }
}

// MARK: - Party Card

private struct PartyCard: View {
    let party: RaveGroup
    let memberCount: Int

    var body: some View {
        GlassCard(tint: party.isPast ? nil : Color.plurViolet) {
            HStack(spacing: Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: Radius.thumbnail)
                        .fill(party.isPast ? Color.plurSurface2 : Color.plurViolet.opacity(0.15))
                        .frame(width: 56, height: 56)
                    Image(systemName: party.isPast ? "clock.arrow.circlepath" : "sparkles")
                        .font(.system(size: 22))
                        .foregroundStyle(party.isPast ? Color.plurFaint : Color.plurViolet)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(party.name)
                        .font(.plurH3())
                        .foregroundStyle(party.isPast ? Color.plurMuted : Color.plurGhost)
                    Text(party.eventName)
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                    HStack(spacing: Spacing.sm) {
                        Label(party.dateRangeText, systemImage: "calendar")
                        Label("\(memberCount)", systemImage: "person.2")
                    }
                    .font(.plurCaption())
                    .foregroundStyle(Color.plurFaint)
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.plurFaint)
            }
        }
    }
}
