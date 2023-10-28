import Foundation
import Logging

/// The global rss-debrid logger. Logger level will depend on launch arguments.
var logger = Logger(label: "codes.tim.rss-debrider")

func logError(_ object: Any?) {
    guard let object = object else { return }
    logger.error("\(object)")
}

func withErrorHandling(task: () async throws -> Void) async throws {
    do {
        try await task()
    } catch let error as LocalizedError {
        logger.critical("Error: \(error.localizedDescription)", metadata: [
            "failureReason": .string(error.failureReason ?? ""),
            "recoverySuggestion": .string(error.recoverySuggestion ?? "")
        ])
        throw error
    } catch let error {
        logger.critical("Error: \(error.localizedDescription)")
        throw error
    }
}
