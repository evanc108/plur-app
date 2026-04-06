import Foundation

// MARK: - Request

struct EventRequest: Equatable {
    var locationIds: [Int] = []
    var artistIds: [Int] = []
    var venueIds: [Int] = []
    var eventName: String?
    var startDate: Date?
    var endDate: Date?
    var festivalOnly: Bool = false
    var livestreamOnly: Bool = false
    var includeElectronic: Bool = true
    var includeOtherGenres: Bool = false

    func toQueryItems() -> [URLQueryItem] {
        var items: [URLQueryItem] = []

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

struct LocationRequest {
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

// MARK: - Live Client

actor EDMTrainClient: EDMTrainClientProtocol {
    private let apiKey: String
    private let session: URLSession
    private let decoder = JSONDecoder()

    private enum Endpoint: String {
        case events = "https://edmtrain.com/api/events"
        case locations = "https://edmtrain.com/api/locations"
    }

    init(apiKey: String = Config.edmTrainAPIKey, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func fetchEvents(_ request: EventRequest = EventRequest()) async throws -> [EDMTrainEvent] {
        try await fetch(.events, queryItems: request.toQueryItems())
    }

    func fetchLocations(_ request: LocationRequest = LocationRequest()) async throws -> [EDMTrainLocation] {
        try await fetch(.locations, queryItems: request.toQueryItems())
    }

    // MARK: - Private

    private func fetch<T: Codable>(_ endpoint: Endpoint, queryItems: [URLQueryItem]) async throws -> T {
        var components = URLComponents(string: endpoint.rawValue)!
        components.queryItems = [URLQueryItem(name: "client", value: apiKey)] + queryItems

        guard let url = components.url else {
            throw EDMTrainError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw EDMTrainError.httpError(http.statusCode)
        }

        let decoded = try decoder.decode(EDMTrainResponse<T>.self, from: data)

        guard decoded.success else {
            throw EDMTrainError.apiError(decoded.message ?? "Unknown API error")
        }

        return decoded.data
    }
}

// MARK: - Errors

enum EDMTrainError: LocalizedError {
    case invalidURL
    case httpError(Int)
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid request URL"
        case .httpError(let code): return "Server error (\(code))"
        case .apiError(let message): return message
        }
    }
}

// MARK: - Helpers

private extension Array where Element == Int {
    var csv: String { map(String.init).joined(separator: ",") }
}
