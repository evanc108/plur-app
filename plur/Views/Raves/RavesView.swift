import SwiftUI

struct RavesView: View {
    @State private var viewModel = RavesViewModel()

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading && viewModel.events.isEmpty {
                    ProgressView("Loading events…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = viewModel.errorMessage, viewModel.events.isEmpty {
                    ContentUnavailableView {
                        Label("Unable to Load", systemImage: "exclamationmark.triangle")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Retry") {
                            Task { await viewModel.loadEvents() }
                        }
                    }
                } else {
                    eventList
                }
            }
            .navigationTitle("Raves")
            .task {
                if viewModel.events.isEmpty {
                    await viewModel.loadEvents()
                }
            }
            .refreshable {
                await viewModel.loadEvents()
            }
        }
    }

    private var eventList: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
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
                        .padding()
                }
            }
            .padding(.horizontal)
        }
    }

    private func sectionHeader(for dateString: String) -> some View {
        HStack {
            Text(Self.formatSectionDate(dateString))
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.top, 16)
        .padding(.bottom, 4)
    }

    private var groupedEvents: [EventGroup] {
        Dictionary(grouping: viewModel.events, by: \.date)
            .map { EventGroup(date: $0.key, events: $0.value) }
            .sorted { $0.date < $1.date }
    }

    private static let displayFormatter: DateFormatter = {
        let f = DateFormatter()
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(event.displayName)
                    .font(.headline)
                    .lineLimit(2)

                Spacer()

                if event.isFestival {
                    Text("Festival")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.purple.opacity(0.2))
                        .foregroundStyle(.purple)
                        .clipShape(Capsule())
                }
            }

            if event.name != nil, let artists = event.artistList, !artists.isEmpty {
                Text(artists.map(\.name).joined(separator: " · "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if let venue = event.venue {
                HStack(spacing: 4) {
                    Image(systemName: "mappin.circle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(venue.name)
                        .font(.subheadline)
                    if let location = venue.location {
                        Text("· \(location)")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let ages = event.ages, !ages.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "person.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(ages)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
