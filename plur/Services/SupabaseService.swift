import Foundation
import Supabase

enum SupabaseService {
    static let client: SupabaseClient = {
        guard let url = URL(string: Config.supabaseURL) else {
            fatalError("Invalid Supabase URL: \(Config.supabaseURL)")
        }
        return SupabaseClient(supabaseURL: url, supabaseKey: Config.supabaseAnonKey)
    }()
}
