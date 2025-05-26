import Foundation
import Supabase

class SupabaseConfig {
    static let shared = SupabaseConfig()
    
    let client: SupabaseClient
    
    private init() {
        // Get configuration from environment variables
        let supabaseURL = URL(string: ProcessInfo.processInfo.environment["SUPABASE_URL"] ?? "https://kyklpwptsuubycuaaeoq.supabase.co")!
        let supabaseKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] ?? "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imt5a2xwd3B0c3V1YnljdWFhZW9xIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2Nzc2NTgsImV4cCI6MjA2MzI1MzY1OH0.cN3FibUJMTITKa45kTqGZ1tmoLsgeEQ-H5VpO0rsPMU"
        
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
