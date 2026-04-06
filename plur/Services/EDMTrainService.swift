import Foundation

struct EDMTrainResponse: Codable {
    let data: [EDMTrainEvent]
    let total: Int?
}

struct EDMTrainEvent: Codable, Identifiable {
    let id: Int
    let name: String?
    let date: String
    let venue: EDMTrainVenue?
    let artistList: [EDMTrainArtist]?
    let festivalInd: Bool?
    let electronicGenreInd: Bool?
    let link: String?

    var displayName: String {
        name ?? artistList?.first?.name ?? "Unknown Event"
    }
}

struct EDMTrainVenue: Codable {
    let id: Int
    let name: String
    let location: String?
    let address: String?
    let state: String?
    let latitude: Double?
    let longitude: Double?
}

struct EDMTrainArtist: Codable, Identifiable {
    let id: Int
    let name: String
}

enum EDMTrainService {
    private static let baseURL = "https://edmtrain.com/api/events"

    static func fetchEvents(location: String? = nil, festivalOnly: Bool = false) async throws -> [EDMTrainEvent] {
        var components = URLComponents(string: baseURL)!
        var queryItems = [URLQueryItem(name: "client", value: Config.edmTrainAPIKey)]

        if let location {
            queryItems.append(URLQueryItem(name: "locationIds", value: location))
        }
        if festivalOnly {
            queryItems.append(URLQueryItem(name: "festivalInd", value: "true"))
        }

        components.queryItems = queryItems

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(EDMTrainResponse.self, from: data)
        return response.data
    }

    static func fetchEventsByArtist(artistId: Int) async throws -> [EDMTrainEvent] {
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "client", value: Config.edmTrainAPIKey),
            URLQueryItem(name: "artistIds", value: String(artistId))
        ]

        let (data, _) = try await URLSession.shared.data(from: components.url!)
        let response = try JSONDecoder().decode(EDMTrainResponse.self, from: data)
        return response.data
    }
}
