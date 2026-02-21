import Foundation
#if canImport(OSAKit)
import OSAKit
#endif

/// Sends iMessages via AppleScript through the Messages.app.
///
/// Uses NSAppleScript / OSAScript to tell Messages.app to send messages.
/// Individual sends use buddy identifier, group sends use chat GUID.
///
/// NOTE: The first time this runs, macOS will prompt for Automation permission.
public actor AppleScriptBridge {

    public init() {}

    /// Send a message to an individual by their phone number or email.
    public func sendToIndividual(address: String, text: String, service: String = "iMessage") throws {
        let escapedText = escapeForAppleScript(text)
        let escapedAddress = escapeForAppleScript(address)
        let escapedService = escapeForAppleScript(service)

        let script = """
        tell application "Messages"
            set targetService to 1st service whose service type = \(escapedService == "iMessage" ? "iMessage" : "SMS")
            set targetBuddy to buddy "\(escapedAddress)" of targetService
            send "\(escapedText)" to targetBuddy
        end tell
        """

        try executeAppleScript(script)
    }

    /// Send a message to a group chat by chat GUID (e.g., "chat123456789").
    public func sendToGroup(chatGuid: String, text: String) throws {
        let escapedText = escapeForAppleScript(text)
        let escapedGuid = escapeForAppleScript(chatGuid)

        let script = """
        tell application "Messages"
            set targetChat to chat id "\(escapedGuid)"
            send "\(escapedText)" to targetChat
        end tell
        """

        try executeAppleScript(script)
    }

    // MARK: - Private

    private func escapeForAppleScript(_ input: String) -> String {
        input
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }

    private func executeAppleScript(_ source: String) throws {
        #if canImport(OSAKit)
        let script = OSAScript(source: source, language: OSALanguage(forName: "AppleScript")!)
        var error: NSDictionary?
        script.executeAndReturnError(&error)
        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw AppleScriptError.executionFailed(message)
        }
        #else
        // Fallback: use NSAppleScript
        var error: NSDictionary?
        let script = NSAppleScript(source: source)
        script?.executeAndReturnError(&error)
        if let error = error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            throw AppleScriptError.executionFailed(message)
        }
        #endif
    }
}

public enum AppleScriptError: Error, LocalizedError {
    case executionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .executionFailed(let message):
            return "AppleScript error: \(message)"
        }
    }
}
