import Foundation

// MARK: - Request

struct EventRequest: Equatable, Sendable {
    var locationIds: [Int] = []
    var artistIds: [Int] = []
    var venueIds: [Int] = []
    var eventIds: [Int] = []
    var eventName: String?
    var startDate: Date?
    var endDate: Date?
    var limit: Int = 100
    var offset: Int = 0
    var festivalOnly: Bool = false
    var livestreamOnly: Bool = false
    var includeElectronic: Bool = true
    var includeOtherGenres: Bool = false

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

        if !eventIds.isEmpty {
            items.append(URLQueryItem(name: "eventIds", value: eventIds.csv))
        }
        if !locationIds.isEmpty {
            items.append(URLQueryItem(name: "locationIds", value: locationIds.csv))
        }
        if !artistIds.isEmpty {
            items.append(URLQueryItem(name: "artistIds", value: artistIds.csv))
        }
        if !venueIds.isEmpty {
            items.append(URLQueryItem(name: "venueIds", value: venueIds.csv))
        }
        if let eventName, !eventName.isEmpty {
            items.append(URLQueryItem(name: "eventName", value: eventName))
        }
        if let startDate {
            items.append(URLQueryItem(name: "startDate", value: EDMTrainDateFormatter.string(from: startDate)))
        }
        if let endDate {
            items.append(URLQueryItem(name: "endDate", value: EDMTrainDateFormatter.string(from: endDate)))
        }
        if festivalOnly {
            items.append(URLQueryItem(name: "festivalInd", value: "true"))
        }
        if livestreamOnly {
            items.append(URLQueryItem(name: "livestreamInd", value: "true"))
        }
        if !includeElectronic {
            items.append(URLQueryItem(name: "includeElectronicGenreInd", value: "false"))
        }
        if includeOtherGenres {
            items.append(URLQueryItem(name: "includeOtherGenreInd", value: "true"))
        }

        return items
    }
}

struct LocationRequest: Sendable {
    var state: String?
    var city: String?

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []
        if let state { items.append(URLQueryItem(name: "state", value: state)) }
        if let city { items.append(URLQueryItem(name: "city", value: city)) }
        return items
    }
}

// MARK: - Client Protocol

protocol EDMTrainClientProtocol: Sendable {
    func fetchEvents(_ request: EventRequest) async throws -> [EDMTrainEvent]
    func fetchLocations(_ request: LocationRequest) async throws -> [EDMTrainLocation]
}

// MARK: - Shared Client

enum EDMTrainClient {
    static let shared: EDMTrainClientProtocol = EDMTrainSupabaseClient()
}

// MARK: - Helpers

private extension Array where Element == Int {
    var csv: String { map(String.init).joined(separator: ",") }
}
