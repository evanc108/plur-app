import Foundation
import Supabase

enum SupabaseService {
    static let client = SupabaseClient(
        supabaseURL: URL(string: Config.supabaseURL)!,
        supabaseKey: Config.supabaseAnonKey
    )
}
