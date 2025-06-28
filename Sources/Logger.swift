import Foundation
import Logging

/// The global rss-debrid logger. Logger level will depend on launch arguments.
@MainActor var logger = Logger(label: "codes.tim.rss-debrider")

func logError(_ object: Sendable?) {
    guard let object else { return }
    Task { @MainActor in logger.error("\(object)") }
}

func withErrorHandling(task: () async throws -> Void) async throws {
    do {
        try await task()
    } catch let error as LocalizedError {
        Task { @MainActor in
            logger.critical("Error: \(error.localizedDescription)", metadata: [
                "failureReason": .string(error.failureReason ?? ""),
                "recoverySuggestion": .string(error.recoverySuggestion ?? "")
            ])
        }
        throw error
    } catch {
        Task { @MainActor in logger.critical("Error: \(error.localizedDescription)") }
        throw error
    }
}
