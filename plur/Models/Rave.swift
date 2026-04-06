import Foundation

struct Rave: Codable, Identifiable {
    let id: Int
    var name: String
    var date: Date
    var venue: String?
    var location: String?
    var imageURL: String?
    var artists: [Artist]

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case date
        case venue
        case location
        case imageURL = "image_url"
        case artists
    }
}

struct Artist: Codable, Identifiable {
    let id: Int
    var name: String
    var startTime: Date?
    var endTime: Date?
    var stage: String?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case startTime = "start_time"
        case endTime = "end_time"
        case stage
    }
}
