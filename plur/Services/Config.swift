import Foundation

enum Config: Sendable {
    static let supabaseURL = Secrets.supabaseURL
    static let supabaseAnonKey = Secrets.supabaseAnonKey
    static let edmTrainAPIKey = Secrets.edmTrainAPIKey
}
