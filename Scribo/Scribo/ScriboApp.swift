//
//  ScriboApp.swift
//  Scribo
//
//  Created by Luis Garza on 22/09/24.
//

import SwiftUI

@main
struct ScriboApp: App { 
    @StateObject private var noteDisplayState = NoteDisplayState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(noteDisplayState)
        }
    }
}
