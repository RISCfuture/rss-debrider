import Foundation

/// Configuration for retry behavior with exponential backoff.
struct RetryConfiguration: Sendable {

  /// Default configuration for Real-Debrid API rate limiting.
  static let `default` = Self()

  /// Maximum number of retry attempts (default: 8).
  var maxRetries: Int = 8

  /// Initial delay before first retry in seconds (default: 2.0).
  var initialDelay: TimeInterval = 2.0

  /// Multiplier applied to delay after each retry (default: 2.0).
  var backoffMultiplier: Double = 2.0

  /// Maximum delay between retries in seconds (default: 60.0).
  var maxDelay: TimeInterval = 60.0

  /// Jitter factor to randomize delays (0.0 to 1.0). A value of 0.25 means
  /// delays vary by ±25% (default: 0.25).
  var jitterFactor: Double = 0.25
}

/**
 Executes an async operation with retry logic and exponential backoff.

 - Parameters:
   - configuration: Retry behavior configuration.
   - shouldRetry: Closure that determines if an error is retryable.
   - operation: The async operation to execute.
 - Returns: The result of the operation.
 - Throws: The last error encountered if all retries are exhausted.
 */
func withRetry<T>(
  configuration: RetryConfiguration = .default,
  shouldRetry: @Sendable (Error) -> Bool,
  operation: () async throws -> T
) async throws -> T {
  var currentDelay = configuration.initialDelay

  for attempt in 0..<configuration.maxRetries {
    do {
      return try await operation()
    } catch {
      guard shouldRetry(error) && attempt < configuration.maxRetries - 1 else {
        throw error
      }

      // Apply jitter to prevent retry storms
      let jitteredDelay = applyJitter(to: currentDelay, factor: configuration.jitterFactor)

      await logger.warning(
        "Retrying after error",
        metadata: [
          "attempt": .stringConvertible(attempt + 1),
          "maxRetries": .stringConvertible(configuration.maxRetries),
          "delaySeconds": .stringConvertible(jitteredDelay)
        ]
      )

      try await Task.sleep(for: .seconds(jitteredDelay))
      currentDelay = min(currentDelay * configuration.backoffMultiplier, configuration.maxDelay)
    }
  }

  // Final attempt
  return try await operation()
}

/// Applies random jitter to a delay value.
/// - Parameters:
///   - delay: The base delay in seconds.
///   - factor: Jitter factor (0.0 to 1.0). A value of 0.25 means ±25%.
/// - Returns: The delay with jitter applied.
private func applyJitter(to delay: TimeInterval, factor: Double) -> TimeInterval {
  guard factor > 0 else { return delay }
  let jitterRange = delay * factor
  let jitter = Double.random(in: -jitterRange...jitterRange)
  return max(0, delay + jitter)
}
