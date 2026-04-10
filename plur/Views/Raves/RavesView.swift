import SwiftUI

struct RavesView: View {
    @State private var viewModel = RavesViewModel()

    var body: some View {
        NavigationStack {
            ZStack {
                Color.plurVoid.ignoresSafeArea()

                Group {
                    if viewModel.isLoading && viewModel.events.isEmpty {
                        ProgressView("Loading events…")
                            .tint(Color.plurViolet)
                            .foregroundStyle(Color.plurMuted)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if let error = viewModel.errorMessage, viewModel.events.isEmpty {
                        VStack(spacing: Spacing.lg) {
                            Spacer()
                            Image(systemName: "exclamationmark.triangle")
                                .font(.system(size: 44))
                                .foregroundStyle(Color.plurFaint)
                            Text("Unable to Load")
                                .font(.plurH2())
                                .foregroundStyle(Color.plurGhost)
                            Text(error)
                                .font(.plurBody())
                                .foregroundStyle(Color.plurMuted)
                                .multilineTextAlignment(.center)
                            Button("Retry") {
                                Task { await viewModel.loadEvents() }
                            }
                            .buttonStyle(PLURButtonStyle())
                            .padding(.horizontal, Spacing.xxxl)
                            Spacer()
                        }
                        .padding(.horizontal, Spacing.xl)
                    } else {
                        eventList
                    }
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("RAVES")
                        .font(.plurHeading(24))
                        .foregroundStyle(Color.plurGhost)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .task {
                if viewModel.events.isEmpty {
                    await viewModel.loadEvents()
                }
            }
            .refreshable {
                await viewModel.loadEvents()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(groupedEvents, id: \.date) { group in
                    Section {
                        ForEach(group.events) { event in
                            EventCard(event: event)
                                .onAppear {
                                    Task { await viewModel.loadMoreIfNeeded(currentEvent: event) }
                                }
                        }
                    } header: {
                        sectionHeader(for: group.date)
                    }
                }

                if viewModel.isLoadingMore {
                    ProgressView()
                        .tint(Color.plurViolet)
                        .padding()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
    }

    private func sectionHeader(for dateString: String) -> some View {
        HStack {
            Text(Self.formatSectionDate(dateString))
                .font(.plurMicro())
                .foregroundStyle(Color.plurMuted)
                .tracking(1.5)
            Spacer()
        }
        .padding(.top, Spacing.md)
        .padding(.bottom, Spacing.xxs)
    }

    private var groupedEvents: [EventGroup] {
        Dictionary(grouping: viewModel.events, by: \.date)
            .map { EventGroup(date: $0.key, events: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE, MMM d"
        return f
    }()

    private static func formatSectionDate(_ dateString: String) -> String {
        guard let date = EDMTrainDateFormatter.date(from: dateString) else { return dateString }
        return displayFormatter.string(from: date)
    }
}

// MARK: - Supporting Types

private struct EventGroup {
    let date: String
    let events: [EDMTrainEvent]
}

// MARK: - Event Card

private struct EventCard: View {
    let event: EDMTrainEvent

    var body: some View {
        GlassCard(tint: event.isFestival ? Color.plurViolet : nil) {
            VStack(alignment: .leading, spacing: Spacing.xs) {
                HStack(alignment: .top) {
                    Text(event.displayName)
                        .font(.plurH3())
                        .foregroundStyle(Color.plurGhost)
                        .lineLimit(2)

                    Spacer()

                    if event.isFestival {
                        Text("Festival")
                            .font(.plurMicro())
                            .padding(.horizontal, Spacing.xs)
                            .padding(.vertical, Spacing.xxs)
                            .background(Color.plurViolet.opacity(0.2))
                            .foregroundStyle(Color.plurViolet)
                            .clipShape(Capsule())
                    }
                }

                if event.name != nil, let artists = event.artistList, !artists.isEmpty {
                    Text(artists.map(\.name).joined(separator: " · "))
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                        .lineLimit(2)
                }

                if let venue = event.venue {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(Color.plurRose)
                            .font(.plurCaption())
                        Text(venue.name)
                            .font(.plurCaption())
                            .foregroundStyle(Color.plurGhost)
                        if let location = venue.location {
                            Text("· \(location)")
                                .font(.plurCaption())
                                .foregroundStyle(Color.plurMuted)
                        }
                    }
                }

                if let ages = event.ages, !ages.isEmpty {
                    HStack(spacing: Spacing.xxs) {
                        Image(systemName: "person.fill")
                            .font(.plurMicro())
                            .foregroundStyle(Color.plurFaint)
                        Text(ages)
                            .font(.plurMicro())
                            .foregroundStyle(Color.plurFaint)
                    }
                }
            }
        }
    }
}
