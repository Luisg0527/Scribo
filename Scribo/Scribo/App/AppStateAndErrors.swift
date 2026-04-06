import SwiftUI

// MARK: - Note Display State
class NoteDisplayState: ObservableObject {
    @Published var isShowingNote: Bool = false
    @Published var currentNote: Note?
    @Published var currentTopic: Topic?
    @Published var currentSubtopic: Subtopic?
    /// Note opened via share link (`get_note_by_share_token`): no topic/subtopic; editing and cloud images may be unavailable.
    @Published var isReadOnlySharePresentation: Bool = false
    /// If user opens a share link before signing in, consume this after `isAuthenticated` becomes true.
    @Published var pendingShareToken: UUID?
    /// Same, for whole-notebook (`/b/…`) links.
    @Published var pendingNotebookShareToken: UUID?
    /// Topic to open after QR scan / deep link: `ContentView` switches to Notebook tab; `NotebookView` presents it.
    @Published var pendingNotebookTopicToPresent: Topic?
    /// Read-only notebook from `get_notebook_by_share_token` (full-screen, not in `DataManager`).
    @Published var sharedReadOnlyNotebook: Topic?
}

// MARK: - App Error
enum AppError: LocalizedError {
    case networkError(String)
    case authenticationError(String)
    case dataError(String)
    case cameraError(String)
    case unknownError(String)
    
    var errorDescription: String? {
        switch self {
        case .networkError(let message):
            return "Network Error: \(message)"
        case .authenticationError(let message):
            return "Authentication Error: \(message)"
        case .dataError(let message):
            return "Data Error: \(message)"
        case .cameraError(let message):
            return "Camera Error: \(message)"
        case .unknownError(let message):
            return "Error: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .networkError:
            return "Please check your internet connection and try again."
        case .authenticationError:
            return "Please try logging in again."
        case .dataError:
            return "Please try refreshing the data."
        case .cameraError:
            return "Please check camera permissions in Settings."
        case .unknownError:
            return "Please try again later."
        }
    }
}

// MARK: - Alert Manager
class AlertManager: ObservableObject {
    @Published var showAlert = false
    @Published var alertTitle = ""
    @Published var alertMessage = ""
    @Published var alertRecoverySuggestion = ""
    
    func showError(_ error: Error) {
        if let appError = error as? AppError {
            alertTitle = "Error"
            alertMessage = appError.errorDescription ?? "An error occurred"
            alertRecoverySuggestion = appError.recoverySuggestion ?? "Please try again later."
        } else {
            alertTitle = "Error"
            alertMessage = error.localizedDescription
            alertRecoverySuggestion = "Please try again later."
        }
        showAlert = true
    }
}
