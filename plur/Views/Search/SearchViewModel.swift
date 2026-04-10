import Foundation
import Observation

enum SearchSegment: String, CaseIterable, Identifiable {
    case events = "Events"
    case people = "People"

    var id: String { rawValue }
}

@MainActor
@Observable
final class SearchViewModel {

    // MARK: - Input

    var query = ""
    var activeSegment: SearchSegment = .events
    var festivalOnly = false
    private(set) var filterVersion = 0

    // MARK: - Output

    private(set) var userResults: [AppUser] = []
    private(set) var eventResults: [EDMTrainEvent] = []
    private(set) var isSearchingUsers = false
    private(set) var isSearchingEvents = false
    private(set) var userError: String?
    private(set) var eventError: String?

    // Idle state
    private(set) var upcomingEvents: [EDMTrainEvent] = []
    private(set) var isLoadingUpcoming = false

    // MARK: - Dependencies

    private let profileService = ProfileService()
    private let edmClient: EDMTrainClientProtocol
    let locationStore: LocationStore

    init(
        edmClient: EDMTrainClientProtocol = EDMTrainClient.shared,
        locationStore: LocationStore = .shared
    ) {
        self.edmClient = edmClient
        self.locationStore = locationStore
    }

    // MARK: - Search

    func performSearch() async {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !q.isEmpty else {
            userResults = []
            eventResults = []
            userError = nil
            eventError = nil
            return
        }

        // Debounce
        try? await Task.sleep(for: .milliseconds(300))
        guard !Task.isCancelled else { return }

        // Fire both searches in parallel regardless of active segment
        isSearchingUsers = true
        isSearchingEvents = true
        userError = nil
        eventError = nil

        let userTask = Task { [q] () -> [AppUser] in
            guard q.count >= 1 else { return [] }
            let userId = try await profileService.currentUserId()
            return try await profileService.searchUsers(query: q, excludingUserId: userId)
        }

        let eventTask = Task { [q] () -> [EDMTrainEvent] in
            guard q.count >= 2 else { return [] }
            var request = self.buildEventRequest()
            request.eventName = q
            return try await edmClient.fetchEvents(request)
        }

        // Await users (typically faster)
        do {
            userResults = try await userTask.value
        } catch is CancellationError {
            return
        } catch {
            userError = Self.friendlyError(error)
        }
        isSearchingUsers = false

        // Await events
        do {
            let results = try await eventTask.value
            eventResults = sortedEvents(results)
        } catch is CancellationError {
            return
        } catch {
            eventError = Self.friendlyError(error)
        }
        isSearchingEvents = false
    }

    // MARK: - Idle / Upcoming Events

    func loadUpcomingEvents() async {
        guard upcomingEvents.isEmpty, !isLoadingUpcoming else { return }
        isLoadingUpcoming = true
        defer { isLoadingUpcoming = false }

        let today = Calendar.current.startOfDay(for: Date())
        let twoWeeks = Calendar.current.date(byAdding: .day, value: 14, to: today)!

        var request = buildEventRequest()
        request.startDate = today
        request.endDate = twoWeeks

        do {
            let fetched = try await edmClient.fetchEvents(request)
            guard !Task.isCancelled else { return }
            upcomingEvents = fetched
        } catch {
            // Silently fail for idle state
        }
    }

    func refreshUpcoming() async {
        upcomingEvents = []
        await loadUpcomingEvents()
    }

    // MARK: - Filters

    func updateFilters() {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            // Bump filterVersion so .task(id:) re-triggers performSearch
            filterVersion += 1
        } else {
            // Refresh upcoming with new location
            Task {
                upcomingEvents = []
                await loadUpcomingEvents()
            }
        }
    }

    // MARK: - Private

    private func buildEventRequest() -> EventRequest {
        var request = EventRequest()
        if let loc = locationStore.selectedLocation {
            request.locationIds = [loc.id]
        }
        if festivalOnly {
            request.festivalOnly = true
        }
        return request
    }

    private static func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                return "No internet connection. Check your network and try again."
            case .timedOut:
                return "Request timed out. Please try again."
            default:
                return "Something went wrong. Please try again."
            }
        }
        return "Something went wrong. Please try again."
    }

    private func sortedEvents(_ events: [EDMTrainEvent]) -> [EDMTrainEvent] {
        let selectedState = locationStore.selectedLocation?.stateCode
        return events.sorted { a, b in
            // Local events first if location is set
            if let state = selectedState {
                let aLocal = a.venue?.state == state
                let bLocal = b.venue?.state == state
                if aLocal != bLocal { return aLocal }
            }
            return a.date < b.date
        }
    }
}
