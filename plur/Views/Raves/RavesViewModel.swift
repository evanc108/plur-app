import Foundation
import Observation

@Observable
final class RavesViewModel {

    // MARK: - Public State

    private(set) var events: [EDMTrainEvent] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true
    var errorMessage: String?

    /// The active filters. Changing this reloads from scratch.
    var filters = EventRequest() {
        didSet {
            guard filters != oldValue else { return }
            Task { await loadEvents() }
        }
    }

    // MARK: - Pagination Config

    /// Number of days each page window covers.
    private let pageWindowDays = 14
    private var currentPage = 0

    // MARK: - Dependencies

    private let client: EDMTrainClientProtocol

    init(client: EDMTrainClientProtocol = EDMTrainClient()) {
        self.client = client
    }

    // MARK: - Loading

    /// Full reload — resets pagination and fetches the first page.
    @MainActor
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        hasMorePages = true

        do {
            let request = buildRequest(forPage: 0)
            let fetched = try await client.fetchEvents(request)
            events = fetched
            currentPage = 1
            hasMorePages = !fetched.isEmpty
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    /// Trigger next page when the user scrolls near the bottom.
    @MainActor
    func loadMoreIfNeeded(currentEvent: EDMTrainEvent) async {
        // Only trigger when within the last 3 items
        guard let index = events.firstIndex(where: { $0.id == currentEvent.id }),
              index >= events.count - 3 else { return }
        await loadMore()
    }

    @MainActor
    func loadMore() async {
        guard !isLoadingMore, !isLoading, hasMorePages else { return }
        isLoadingMore = true

        do {
            let request = buildRequest(forPage: currentPage)
            let fetched = try await client.fetchEvents(request)

            let existingIds = Set(events.map(\.id))
            let newEvents = fetched.filter { !existingIds.contains($0.id) }

            events.append(contentsOf: newEvents)
            currentPage += 1
            hasMorePages = !fetched.isEmpty
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoadingMore = false
    }

    // MARK: - Private

    /// Merges the active filters with date-window pagination.
    private func buildRequest(forPage page: Int) -> EventRequest {
        let today = Calendar.current.startOfDay(for: Date())
        let windowStart = Calendar.current.date(byAdding: .day, value: page * pageWindowDays, to: today)!
        let windowEnd = Calendar.current.date(byAdding: .day, value: (page + 1) * pageWindowDays - 1, to: today)!

        var request = filters

        // Only apply date windowing if the user hasn't set explicit dates
        if request.startDate == nil {
            request.startDate = windowStart
        }
        if request.endDate == nil {
            request.endDate = windowEnd
        }

        return request
    }
}
