import SwiftUI

struct SearchView: View {
    @State private var viewModel = SearchViewModel()
    @State private var showLocationPicker = false
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                segmentPicker
                if viewModel.activeSegment == .events {
                    EventFiltersBar(
                        selectedLocation: viewModel.locationStore.selectedLocation,
                        festivalOnly: $viewModel.festivalOnly,
                        onLocationTap: { showLocationPicker = true },
                        onChanged: { viewModel.updateFilters() }
                    )
                }
                content
            }
            .plurBackground()
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("SEARCH")
                        .font(.plurHeading(24))
                        .foregroundStyle(Color.plurGhost)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .navigationDestination(for: EDMTrainEvent.ID.self) { eventId in
                if let event = findEvent(by: eventId) {
                    EventDetailView(event: event)
                }
            }
            .sheet(isPresented: $showLocationPicker) {
                LocationPickerView(locationStore: .shared) {
                    viewModel.updateFilters()
                }
            }
            .task(id: "\(viewModel.query)|\(viewModel.filterVersion)") {
                await viewModel.performSearch()
            }
            .task {
                await viewModel.loadUpcomingEvents()
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.plurFaint)

            TextField("Search events or people...", text: $viewModel.query)
                .font(.plurBody())
                .foregroundStyle(Color.plurGhost)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .focused($isSearchFocused)

            if !viewModel.query.isEmpty {
                Button {
                    viewModel.query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.plurFaint)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color.plurSurface2, in: RoundedRectangle(cornerRadius: Radius.pill))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.pill)
                .stroke(Color.plurBorder, lineWidth: 1)
        )
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xs)
    }

    // MARK: - Segment Picker

    private var segmentPicker: some View {
        HStack(spacing: Spacing.xs) {
            ForEach(SearchSegment.allCases) { segment in
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        viewModel.activeSegment = segment
                    }
                } label: {
                    Text(segment.rawValue)
                        .font(.plurBodyBold(14))
                        .foregroundStyle(viewModel.activeSegment == segment ? Color.plurGhost : Color.plurMuted)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Spacing.xs)
                        .background(
                            Capsule()
                                .fill(viewModel.activeSegment == segment ? Color.plurViolet.opacity(0.25) : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(viewModel.activeSegment == segment ? Color.plurViolet.opacity(0.4) : Color.clear, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        let q = viewModel.query.trimmingCharacters(in: .whitespacesAndNewlines)

        if q.isEmpty {
            idleContent
        } else {
            searchResults
        }
    }

    // MARK: - Idle Content

    @ViewBuilder
    private var idleContent: some View {
        switch viewModel.activeSegment {
        case .events:
            if viewModel.isLoadingUpcoming {
                Spacer()
                ProgressView("Loading upcoming events...")
                    .tint(Color.plurViolet)
                    .foregroundStyle(Color.plurMuted)
                Spacer()
            } else if LocationStore.shared.selectedLocation == nil {
                setLocationPrompt
            } else if viewModel.upcomingEvents.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("No Upcoming Events")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text("Try selecting a different location")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                upcomingEventsList
            }

        case .people:
            VStack(spacing: Spacing.lg) {
                Spacer()
                Image(systemName: "person.2.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Color.plurViolet.opacity(0.6))
                Text("Find Your Rave Fam")
                    .font(.plurH2())
                    .foregroundStyle(Color.plurGhost)
                Text("Search by username or display name")
                    .font(.plurBody())
                    .foregroundStyle(Color.plurMuted)
                Spacer()
            }
            .padding(.horizontal, Spacing.xl)
        }
    }

    private var setLocationPrompt: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            GlassCard(tint: Color.plurTeal) {
                VStack(spacing: Spacing.md) {
                    Image(systemName: "mappin.and.ellipse")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.plurTeal)
                    Text("Set Your City")
                        .font(.plurH3())
                        .foregroundStyle(Color.plurGhost)
                    Text("Pick your location to see upcoming events near you")
                        .font(.plurCaption())
                        .foregroundStyle(Color.plurMuted)
                        .multilineTextAlignment(.center)
                    Button("Choose Location") {
                        showLocationPicker = true
                    }
                    .buttonStyle(PLURButtonStyle(color: .plurTeal))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, Spacing.lg)
            Spacer()
        }
    }

    private var upcomingEventsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                HStack {
                    Text("UPCOMING NEAR YOU")
                        .font(.plurMicro())
                        .foregroundStyle(Color.plurMuted)
                        .tracking(1.5)
                    Spacer()
                }
                .padding(.top, Spacing.sm)

                ForEach(viewModel.upcomingEvents) { event in
                    NavigationLink(value: event.id) {
                        EventResultCard(event: event)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.bottom, Spacing.lg)
        }
        .refreshable {
            await viewModel.refreshUpcoming()
        }
    }

    // MARK: - Search Results

    @ViewBuilder
    private var searchResults: some View {
        switch viewModel.activeSegment {
        case .events:
            eventSearchResults
        case .people:
            userSearchResults
        }
    }

    private var eventSearchResults: some View {
        Group {
            if viewModel.isSearchingEvents && viewModel.eventResults.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.plurViolet)
                Spacer()
            } else if let error = viewModel.eventError, viewModel.eventResults.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("Search Failed")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text(error)
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else if viewModel.eventResults.isEmpty && !viewModel.isSearchingEvents {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "music.note.list")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("No Events Found")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text("Try a different search or adjust your filters")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(viewModel.eventResults) { event in
                            NavigationLink(value: event.id) {
                                EventResultCard(event: event)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.bottom, Spacing.lg)
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }

    private var userSearchResults: some View {
        Group {
            if viewModel.isSearchingUsers && viewModel.userResults.isEmpty {
                Spacer()
                ProgressView()
                    .tint(Color.plurViolet)
                Spacer()
            } else if let error = viewModel.userError, viewModel.userResults.isEmpty {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("Search Failed")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text(error)
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else if viewModel.userResults.isEmpty && !viewModel.isSearchingUsers {
                VStack(spacing: Spacing.lg) {
                    Spacer()
                    Image(systemName: "person.slash")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.plurFaint)
                    Text("No Users Found")
                        .font(.plurH2())
                        .foregroundStyle(Color.plurGhost)
                    Text("Try a different username or name")
                        .font(.plurBody())
                        .foregroundStyle(Color.plurMuted)
                    Spacer()
                }
                .padding(.horizontal, Spacing.xl)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(viewModel.userResults) { user in
                            UserResultRow(user: user)
                        }
                    }
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, Spacing.lg)
                }
            }
        }
    }

    // MARK: - Helpers

    private func findEvent(by id: Int) -> EDMTrainEvent? {
        viewModel.eventResults.first { $0.id == id }
            ?? viewModel.upcomingEvents.first { $0.id == id }
    }
}
