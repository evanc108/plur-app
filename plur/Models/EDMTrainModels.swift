import Foundation

// MARK: - API Responses

struct EDMTrainResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: T
    let success: Bool
    let message: String?
}

// MARK: - Event

struct EDMTrainEvent: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String?
    let date: String
    let startTime: String?
    let endTime: String?
    let ages: String?
    let venue: EDMTrainVenue?
    let artistList: [EDMTrainArtist]?
    let festivalInd: Bool?
    let livestreamInd: Bool?
    let electronicGenreInd: Bool?
    let otherGenreInd: Bool?
    let link: String?
    let createdDate: String?

    var displayName: String {
        name ?? artistList?.map(\.name).joined(separator: ", ") ?? "Unknown Event"
    }

    var parsedDate: Date? {
        EDMTrainDateFormatter.date(from: date)
    }

    var isFestival: Bool {
        festivalInd ?? false
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    static func == (lhs: EDMTrainEvent, rhs: EDMTrainEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Venue

struct EDMTrainVenue: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let location: String?
    let address: String?
    let state: String?
    let country: String?
    let latitude: Double?
    let longitude: Double?
}

// MARK: - Artist

struct EDMTrainArtist: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let name: String
    let link: String?
    let b2bInd: Bool?
}

// MARK: - Location

struct EDMTrainLocation: Codable, Identifiable, Hashable, Sendable {
    let id: Int
    let city: String
    let state: String
    let stateCode: String
    let country: String
    let countryCode: String
    let latitude: Double
    let longitude: Double
    let link: String?

    var displayName: String {
        "\(city), \(stateCode)"
    }
}

// MARK: - Shared Date Formatter

enum EDMTrainDateFormatter {
    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static func date(from string: String) -> Date? {
        formatter.date(from: string)
    }

    static func string(from date: Date) -> String {
        formatter.string(from: date)
    }
}
