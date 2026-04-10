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
            activeFilterTask?.cancel()
            activeFilterTask = Task { await loadEvents() }
        }
    }

    // MARK: - Pagination Config

    private let pageWindowDays = 14
    private var currentPage = 0
    private var activeFilterTask: Task<Void, Never>?

    // MARK: - Dependencies

    private let client: EDMTrainClientProtocol

    init(client: EDMTrainClientProtocol = EDMTrainClient.shared) {
        self.client = client
    }

    // MARK: - Loading

    @MainActor
    func loadEvents() async {
        isLoading = true
        errorMessage = nil
        currentPage = 0
        hasMorePages = true

        do {
            let request = buildRequest(forPage: 0)
            let fetched = try await client.fetchEvents(request)
            guard !Task.isCancelled else { return }
            events = fetched
            currentPage = 1
            hasMorePages = !fetched.isEmpty
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func loadMoreIfNeeded(currentEvent: EDMTrainEvent) async {
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

    private func buildRequest(forPage page: Int) -> EventRequest {
        let today = Calendar.current.startOfDay(for: Date())
        let windowStart = Calendar.current.date(byAdding: .day, value: page * pageWindowDays, to: today)!
        let windowEnd = Calendar.current.date(byAdding: .day, value: (page + 1) * pageWindowDays - 1, to: today)!

        var request = filters

        if request.startDate == nil {
            request.startDate = windowStart
        }
        if request.endDate == nil {
            request.endDate = windowEnd
        }

        return request
    }
}
