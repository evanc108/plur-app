import Foundation

enum Config {
    static let supabaseURL: String = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String ?? ""
    static let supabaseAnonKey: String = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String ?? ""
    static let edmTrainAPIKey: String = Bundle.main.infoDictionary?["EDMTRAIN_API_KEY"] as? String ?? ""
}
