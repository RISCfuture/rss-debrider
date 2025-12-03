import Foundation
import Logging

/// The global rss-debrid logger. Logger level will depend on launch arguments.
@MainActor var logger = Logger(label: "codes.tim.rss-debrider")

/**
 Logs an error message if the object is not nil.

 - Parameter object: The object to log. If `nil`, no logging occurs.
 */
func logError(_ object: Sendable?) {
  guard let object else { return }
  Task { @MainActor in logger.error("\(object)") }
}

/**
 Executes an async task with error handling and logging.

 If the task throws an error, it is logged at the critical level with
 appropriate metadata (failure reason and recovery suggestion for
 `LocalizedError` types).

 - Parameter task: The async task to execute.
 - Throws: Rethrows any error thrown by the task after logging it.
 */
func withErrorHandling(task: () async throws -> Void) async throws {
  do {
    try await task()
  } catch let error as LocalizedError {
    Task { @MainActor in
      logger.critical(
        "Error: \(error.localizedDescription)",
        metadata: [
          "failureReason": .string(error.failureReason ?? ""),
          "recoverySuggestion": .string(error.recoverySuggestion ?? "")
        ]
      )
    }
    throw error
  } catch {
    Task { @MainActor in logger.critical("Error: \(error.localizedDescription)") }
    throw error
  }
}
