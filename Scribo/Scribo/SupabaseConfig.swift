import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let client: SupabaseClient
    
    private init() {
        // Replace these with your actual Supabase project URL and anon key
        let supabaseURL = URL(string: "Placeholder")!
        let supabaseKey = "Placeholder"
        
        // Initialize with default options
        let options = SupabaseClientOptions()
        
        self.client = SupabaseClient(
            supabaseURL: supabaseURL,
            supabaseKey: supabaseKey,
            options: options
        )
        
        // Clear any existing session on startup
        Task {
            try? await client.auth.signOut()
        }
    }
} 
