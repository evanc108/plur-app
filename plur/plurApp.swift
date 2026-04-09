import SwiftData
import SwiftUI

@main
struct plurApp: App {
    private let modelContainer: ModelContainer
    private let scheduleCacheStore: ScheduleCacheStore

    @State private var authService = AuthService()

    init() {
        let schema = Schema([
            CachedFestivalSchedulePayload.self,
            CachedSetSelectionsPayload.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: false)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        modelContainer = container
        scheduleCacheStore = ScheduleCacheStore(modelContext: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(scheduleCacheStore: scheduleCacheStore)
                .environment(authService)
                .modelContainer(modelContainer)
        }
    }
}
