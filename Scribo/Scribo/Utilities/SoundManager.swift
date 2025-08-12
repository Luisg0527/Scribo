import Foundation
import AVFoundation

class SoundManager {
    static let shared = SoundManager()
    
    private var completionSoundPlayer: AVAudioPlayer?
    private var shutterSoundPlayer: AVAudioPlayer?
    
    private init() {
        setupCompletionSound()
        setupShutterSound()
    }
    
    private func setupCompletionSound() {
        guard let soundURL = Bundle.main.url(forResource: "pleasant-done-notification", withExtension: "wav") else {
            print("❌ Could not find pleasant-done-notification.wav")
            return
        }
        
        do {
            completionSoundPlayer = try AVAudioPlayer(contentsOf: soundURL)
            completionSoundPlayer?.prepareToPlay()
        } catch {
            print("❌ Failed to load completion sound: \(error)")
        }
    }
    
    private func setupShutterSound() {
        // Use system camera shutter sound
        // iOS provides a built-in camera shutter sound that we can trigger
    }
    
    func playCompletionSound() {
        if let player = completionSoundPlayer {
            if player.play() {
                print("🔊 Completion sound played")
            }
        }
    }
    
    func playShutterSound() {
        // Play the system camera shutter sound
        AudioServicesPlaySystemSound(1108) // System sound ID for camera shutter
        print("📸 Shutter sound played")
    }
    
    func playSystemSound(_ soundID: SystemSoundID) {
        AudioServicesPlaySystemSound(soundID)
    }
}
