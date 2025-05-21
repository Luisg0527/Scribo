import Foundation
import os.log

enum Logger {
    private static let logger = OSLog(subsystem: Bundle.main.bundleIdentifier ?? "com.scribo", category: "App")
    
    static func debug(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        #if DEBUG
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"
        os_log(.debug, log: logger, "%{public}@", logMessage)
        #endif
    }
    
    static func info(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"
        os_log(.info, log: logger, "%{public}@", logMessage)
    }
    
    static func error(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"
        os_log(.error, log: logger, "%{public}@", logMessage)
    }
    
    static func fault(_ message: String, function: String = #function, file: String = #file, line: Int = #line) {
        let filename = (file as NSString).lastPathComponent
        let logMessage = "[\(filename):\(line)] \(function): \(message)"
        os_log(.fault, log: logger, "%{public}@", logMessage)
    }
} 