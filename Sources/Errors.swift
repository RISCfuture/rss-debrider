import Foundation

/// Errors related to configuration.
enum ConfigurationError: Swift.Error {

  /**
   Thrown when a required configuration value is missing.
  
   - Parameter name: The name of the missing configuration value.
   */
  case missingRequired(_ name: String)
}

/// Errors that can be thrown generally.
enum Errors: Swift.Error {

  /**
   Thrown when a URL cannot be parsed.
  
   - Parameter url: The URL that could not be parsed.
   */
  case badURL(_ url: String)
}

/// Errors thrown by ``RSS/Client``.
enum RSSErrors: Swift.Error {

  /**
   Thrown when a non-HTTP response is received.
  
   - Parameter response: The response that was received.
   */
  case badRepsonse(_ response: URLResponse)

  /**
   Thrown when a response has a non-success HTTP status code.
  
   - Parameter response: The response that was received.
   - Parameter body: The body of the response.
   */
  case badResponseStatus(_ response: HTTPURLResponse, body: Data)
}

/// API communication errors thrown by ``RealDebrid/Client``.
enum RealDebridAPIError: Swift.Error {

  /**
   Thrown when a non-HTTP response is received.
  
   - Parameter response: The response that was received.
   */
  case badRepsonse(_ response: URLResponse)

  /**
   Thrown when a response has a non-success HTTP status code.
  
   - Parameter response: The response that was received.
   - Parameter body: The body of the response.
   */
  case badResponseStatus(_ response: HTTPURLResponse, body: Data)
}

/// Errors thrown when Real-Debrid cannot download a torrent.
enum RealDebridTorrentError: Swift.Error {

  /**
   Thrown when `/torrents/info/{id}` returns a failed status.
  
   - Parameter id: The Real-Debrid ID of the torrent.
   - Parameter status: The status returned by the API.
   */
  case downloadFailed(id: String, status: RealDebrid.Response.TorrentInfo.Status)
}

/// Client configuration errors thrown by ``Synology/Client``.
enum SynologyErrors: Swift.Error {

  /// Thrown when an authenticated API request is made without an active
  /// session.
  case noSession

  /// Thrown when an API request is made before ``Synology/Client/getAPIs()``
  /// is called.
  case APIInfoNotDownloaded

  /**
   Thrown when an API name is provided that was not returned by
   ``Synology/Client/getAPIs()``.
  
   - Parameter api: The name of the API that was requested.
   */
  case unknownAPI(_ api: String)

  /**
   Thrown when a version was given that is outside the supported range for the
   API.
  
   - Parameter api: The name of the API that was requested.
   - Parameter version: The version that was given.
   */
  case unsupportedVersion(api: String, version: UInt)
}

extension ConfigurationError: LocalizedError {
  var errorDescription: String? {
    String(localized: "Couldn’t load configuration.")
  }

  var failureReason: String? {
    switch self {
      case .missingRequired(let name):
        return String(localized: "The required value “\(name)” was not provided.")
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .missingRequired(let name):
        return String(
          localized: "Provide “\(name)” via a command-line option or environment variable."
        )
    }
  }
}

extension Errors: LocalizedError {
  var errorDescription: String? {
    String(localized: "Couldn’t parse URL.")
  }

  var failureReason: String? {
    switch self {
      case .badURL(let url):
        return String(localized: "“\(url)” is not a valid URL.")
    }
  }

  var recoverySuggestion: String? {
    nil
  }
}

extension RealDebridAPIError: LocalizedError {
  var errorDescription: String? {
    String(localized: "Couldn’t connect to Real-Debrid.")
  }

  var failureReason: String? {
    switch self {
      case .badRepsonse(let response):
        let url = response.url?.absoluteString ?? "unknown"
        return String(localized: "The response from \(url) was not an HTTP response.")

      case let .badResponseStatus(response, body):
        if let errorMessage = realDebridError(body: body) {
          return errorMessage
        }
        switch response.statusCode {
          case 401:
            return String(localized: "Invalid API key.")
          case 403:
            return String(localized: "Account is not authorized.")
          default:
            return String(localized: "The server returned HTTP status \(response.statusCode).")
        }
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .badRepsonse:
        return nil

      case .badResponseStatus(let response, _):
        switch response.statusCode {
          case 401:
            return String(localized: "Check the Real-Debrid API key passed to the -r option.")
          case 403:
            return String(localized: "Verify your Real-Debrid subscription is active.")
          default:
            return nil
        }
    }
  }

  private func realDebridError(body: Data) -> String? {
    guard let body = try? JSONDecoder().decode(RealDebridError.self, from: body) else { return nil }
    return String(localized: "API error \(body.errorCode): \(body.error) — \(body.errorDetails)")
  }
}

extension RealDebridTorrentError: LocalizedError {
  var errorDescription: String? {
    String(localized: "Real-Debrid couldn’t download torrent.")
  }

  var failureReason: String? {
    switch self {
      case let .downloadFailed(id, status):
        return switch status {
          case .dead:
            String(localized: "Torrent \(id) has no available seeders.")
          case .error:
            String(localized: "Torrent \(id) encountered an unknown error.")
          case .magnetError:
            String(localized: "Torrent \(id) has invalid magnet data.")
          case .virus:
            String(localized: "Torrent \(id) contains a virus.")
          default:
            preconditionFailure("Not an error status")
        }
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case let .downloadFailed(_, status):
        switch status {
          case .dead:
            return String(localized: "Try again later when seeders may be available.")
          default:
            return nil
        }
    }
  }
}

extension RSSErrors: LocalizedError {
  var errorDescription: String? {
    String(localized: "Couldn’t fetch RSS feed.")
  }

  var failureReason: String? {
    switch self {
      case .badRepsonse(let response):
        let url = response.url?.absoluteString ?? "unknown"
        return String(localized: "The response from \(url) was not an HTTP response.")
      case .badResponseStatus(let response, _):
        return String(localized: "The server returned HTTP status \(response.statusCode).")
    }
  }

  var recoverySuggestion: String? {
    String(localized: "Verify the RSS feed URL is correct and the server is accessible.")
  }
}

extension SynologyErrors: LocalizedError {
  var errorDescription: String? {
    String(localized: "Synology client not configured correctly.")
  }

  var failureReason: String? {
    switch self {
      case .noSession:
        return String(localized: "No active session. Call login() before making API requests.")
      case .APIInfoNotDownloaded:
        return String(localized: "Call getAPIs() before making API requests.")
      case .unknownAPI(let api):
        return String(localized: "API “\(api)” was not found in the API info response.")
      case let .unsupportedVersion(api, version):
        return String(localized: "Version \(version) is not supported for API “\(api)\".")
    }
  }

  var recoverySuggestion: String? {
    nil
  }
}

private struct RealDebridError: Codable {
  var error: String
  var errorDetails: String
  var errorCode: Int

  enum CodingKeys: String, CodingKey {
    case error
    case errorDetails = "error_details"
    case errorCode = "error_code"
  }
}
