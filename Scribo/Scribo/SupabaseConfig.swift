import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let client: SupabaseClient
    
    private init() {
        // Get configuration from environment variables
        let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://smyhydlufyrvnytwcwcy.supabase.co")!
        let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "sb_publishable_SSzH-3IsV8niOjhBFE5zsg_wMVLIYp6"
        
        // Initialize with default options
        let options = SupabaseClientOptions()
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: options
        )
    }
} 
