import Foundation
import Observation

@MainActor
@Observable
final class LocationStore {
    static let shared = LocationStore()

    private(set) var allLocations: [EDMTrainLocation] = []
    private(set) var isLoading = false

    var selectedLocation: EDMTrainLocation? {
        didSet { persistSelection() }
    }

    private let client: EDMTrainClientProtocol
    private let defaults = UserDefaults.standard
    private static let storageKey = "selectedEDMTrainLocation"

    init(client: EDMTrainClientProtocol = EDMTrainClient.shared) {
        self.client = client
        if let data = defaults.data(forKey: Self.storageKey),
           let location = try? JSONDecoder().decode(EDMTrainLocation.self, from: data) {
            self.selectedLocation = location
        }
    }

    func loadLocations() async {
        guard allLocations.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        // Single query — the Supabase client returns all US locations at once
        allLocations = (try? await client.fetchLocations(LocationRequest())) ?? []
    }

    func setLocation(_ location: EDMTrainLocation) {
        selectedLocation = location
    }

    func clearLocation() {
        selectedLocation = nil
        defaults.removeObject(forKey: Self.storageKey)
    }

    private func persistSelection() {
        guard let location = selectedLocation,
              let data = try? JSONEncoder().encode(location) else {
            defaults.removeObject(forKey: Self.storageKey)
            return
        }
        defaults.set(data, forKey: Self.storageKey)
    }
}
