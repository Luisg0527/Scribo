import Foundation
import UserNotifications
import AVFoundation
import SwiftUI

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    private var audioPlayer: AVAudioPlayer?
    
    @Published var isAuthorized = false
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("soundEffectsEnabled") var soundEffectsEnabled = true
    
    private override init() {
        super.init()
        requestAuthorization()
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                self.isAuthorized = granted
                if let error = error {
                    print("❌ Notification authorization error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // MARK: - Notifications
    
    func scheduleNotification(title: String, body: String, timeInterval: TimeInterval = 5) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: timeInterval, repeats: false)
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleReminder(for note: Note, in topic: Topic, subtopic: Subtopic) {
        guard notificationsEnabled else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "Note Reminder"
        content.body = "Don't forget to review your note '\(note.title)' in \(topic.title) > \(subtopic.title)"
        content.sound = .default
        
        // Schedule for 24 hours from now
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: "note-\(note.id)", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("❌ Error scheduling reminder: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - Sound Effects
    
    func playSound(_ sound: NotificationSound) {
        guard soundEffectsEnabled else { return }
        
        guard let soundURL = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") else {
            print("❌ Sound file not found: \(sound.rawValue)")
            return
        }
        
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
        } catch {
            print("❌ Error playing sound: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Settings
    
    func toggleNotifications() {
        notificationsEnabled.toggle()
        if !notificationsEnabled {
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        }
    }
    
    func toggleSoundEffects() {
        soundEffectsEnabled.toggle()
    }
}

// MARK: - Supporting Types

enum NotificationSound: String {
    case success = "success"
    case error = "error"
    case tap = "tap"
    case delete = "delete"
    case save = "save"
} 