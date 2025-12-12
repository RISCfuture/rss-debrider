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

/// Errors thrown by ``RealDebrid/Client``.
enum RealDebridErrors: Swift.Error {

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

  /**
   Thrown when `/torrents/info/{id}` returns a failed status.
  
   - Parameter id: The Real-Debrid ID of the torrent.
   - Parameter status: The status returned by the API.
   */
  case torrentDownloadFailed(id: String, status: RealDebrid.Response.TorrentInfo.Status)
}

/// Errors thrown by ``Synology/Client``.
enum SynologyErrors: Swift.Error {

  /**
   Thrown when a non-HTTP response is received.
  
   - Parameter response: The response that was received.
   */
  case badRepsonse(_ response: URLResponse)

  /// Thrown when an authenticated API request is made without an active
  /// session.
  case noSession

  /**
   Thrown when the Synology API returns an error response.
  
   - Parameter error: The error code returned by the API.
   */
  case APIError(error: Synology.Error)

  /// Thrown when an API request is made before ``Synology/Client/getAPIs()``
  /// is called.
  case APIInfoNotDownloaded

  /**
   Thrown when an API name is provided that was given by
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
    switch self {
      case .missingRequired:
        return String(localized: "Missing required configuration", comment: "error description")
    }
  }

  var failureReason: String? {
    switch self {
      case .missingRequired(let name):
        return String(
          localized: "The required configuration value “\(name)” was not provided.",
          comment: "failure reason"
        )
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .missingRequired(let name):
        return String(
          localized:
            "Provide “\(name)” via the command-line option or the corresponding environment variable.",
          comment: "recovery suggestion"
        )
    }
  }
}

extension Errors: LocalizedError {
  var errorDescription: String? {
    switch self {
      case .badURL:
        return String(localized: "Improperly formatted URL", comment: "error description")
    }
  }

  var failureReason: String? {
    switch self {
      case .badURL(let url):
        return String(
          localized: "The URL “\(url)” could not be parsed as a URL.",
          comment: "failure reason"
        )
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .badURL:
        return String(
          localized: "Verify that the RSS feed is returning correct magnetic URLs.",
          comment: "recovery suggestion"
        )
    }
  }
}

extension RealDebridErrors: LocalizedError {
  var errorDescription: String? {
    switch self {
      case .badRepsonse:
        return String(
          localized: "Unexpected response from Real-Debrid API",
          comment: "error description"
        )
      case .badResponseStatus:
        return String(
          localized: "Non-success response from Real-Debrid API",
          comment: "error description"
        )
      case .torrentDownloadFailed:
        return String(
          localized: "Real-Debrid couldn’t download torrent.",
          comment: "error description"
        )
    }
  }

  var failureReason: String? {
    switch self {
      case .badRepsonse(let response):
        let url = response.url?.absoluteString ?? String(localized: "<unknown URL>")
        return String(
          localized: "The response from “\(url)” was not an HTTP response.",
          comment: "failure reason"
        )

      case let .badResponseStatus(response, body):
        switch response.statusCode {
          case 401:
            return String(localized: "Bad Real-Debrid API key.", comment: "failure reason")
          case 403:
            return String(
              localized: "Real-Debrid account is not authorized.",
              comment: "failure reason"
            )
          default:
            return realDebridError(body: body) ?? defaultRealDebridError(response: response)
        }

      case let .torrentDownloadFailed(id, status):
        return switch status {
          case .dead:
            String(
              localized: "Couldn’t download torrent “\(id)”: Torrent is dead.",
              comment: "failure reason"
            )
          case .error:
            String(
              localized: "Couldn’t download torrent “\(id)”: An unknown error occurred.",
              comment: "failure reason"
            )
          case .magnetError:
            String(
              localized: "Couldn’t download torrent “\(id)”: Failed to get magnet data.",
              comment: "failure reason"
            )
          case .virus:
            String(
              localized: "Couldn’t download torrent “\(id)”: Torrent contains a virus.",
              comment: "failure reason"
            )
          default:
            preconditionFailure("Not an error status")
        }
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .badRepsonse:
        return String(
          localized: "Verify that the server is accessible from your computer.",
          comment: "recovery suggestion"
        )

      case .badResponseStatus(let response, _):
        switch response.statusCode {
          case 401:
            return String(
              localized: "Double-check the value passed to the -r option.",
              comment: "recovery suggestion"
            )
          case 403:
            return String(
              localized:
                "Make sure you are a premium Real-Debrid subscriber, and your account is in good standing.",
              comment: "recovery suggestion"
            )
          default:
            return String(
              localized: "Consult the Real-Debrid API documentation for more information.",
              comment: "recovery suggestion"
            )
        }

      case .torrentDownloadFailed(_, let status):
        switch status {
          case .dead:
            return String(
              localized: "Try the download again later.",
              comment: "recovery suggestion"
            )
          default:
            return String(
              localized: "Try a different torrent or magnet URL.",
              comment: "recovery suggestion"
            )
        }
    }
  }

  private func realDebridError(body: Data) -> String? {
    guard let body = try? JSONDecoder().decode(RealDebridError.self, from: body) else { return nil }
    return String(
      localized:
        "Real-Debrid API returned error \(body.errorCode) (\(body.error)): \(body.errorDetails)",
      comment: "failure reason"
    )
  }

  private func defaultRealDebridError(response: HTTPURLResponse) -> String {
    let url = response.url?.absoluteString ?? String(localized: "<unknown URL>")
    return String(
      localized: "The response from “\(url)” had status code \(response.statusCode).",
      comment: "failure reason"
    )
  }
}

extension RSSErrors: LocalizedError {
  var errorDescription: String? {
    switch self {
      case .badRepsonse:
        return String(
          localized: "Unexpected response from RSS provider",
          comment: "error description"
        )
      case .badResponseStatus:
        return String(
          localized: "Non-success response from RSS provider",
          comment: "error description"
        )
    }
  }

  var failureReason: String? {
    switch self {
      case .badRepsonse(let response):
        let url = response.url?.absoluteString ?? String(localized: "<unknown URL>")
        return String(
          localized: "The response from “\(url)” was not an HTTP response.",
          comment: "failure reason"
        )
      case .badResponseStatus(let response, _):
        let url = response.url?.absoluteString ?? String(localized: "<unknown URL>")
        return String(
          localized: "The response from “\(url)” had status code \(response.statusCode).",
          comment: "failure reason"
        )
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .badRepsonse:
        return String(
          localized: "Verify that the server is accessible from your computer.",
          comment: "recovery suggestion"
        )
      case .badResponseStatus:
        return String(
          localized: "Verify the RSS URL passed to rss-debrider.",
          comment: "recovery suggestion"
        )
    }
  }
}

extension SynologyErrors: LocalizedError {
  var errorDescription: String? {
    switch self {
      case .APIError:
        return String(localized: "The Synology API returned an error", comment: "error description")
      case .badRepsonse:
        return String(
          localized: "Unexpected response from Synology API",
          comment: "error description"
        )
      case .noSession:
        return String(
          localized: "Must be logged in to use that Synology API method",
          comment: "error description"
        )
      case .APIInfoNotDownloaded:
        return String(
          localized: "API info not yet downloaded from Synology",
          comment: "error description"
        )
      case .unknownAPI:
        return String(localized: "Unknown Synology API", comment: "error description")
      case .unsupportedVersion:
        return String(
          localized: "Given Synology API version is unsupported",
          comment: "error description"
        )
    }
  }

  var failureReason: String? {
    switch self {
      case .APIError(let code):
        switch code {
          case .invalidParameter:
            return String(
              localized: "An invalid parameter was provided to the Synology API.",
              comment: "failure reason"
            )
          case .noSuchAPI:
            return String(
              localized: "An invalid API name was provided to the Synology API.",
              comment: "failure reason"
            )
          case .noSuchMethod:
            return String(
              localized: "An invalid method name was provided to the Synology API.",
              comment: "failure reason"
            )
          case .notSupportedInVersion:
            return String(
              localized: "Synology API is not supported in the provided version.",
              comment: "failure reason"
            )
          case .sessionInterrupted:
            return String(
              localized: "The current Synology session was interrupted by another login.",
              comment: "failure reason"
            )
          case .sessionTimeout:
            return String(
              localized: "The Synology session has timed out.",
              comment: "failure reason"
            )
          case .unauthorized:
            return String(
              localized: "Action is not authorized for the Synology user.",
              comment: "failure reason"
            )
          case .unknown:
            return String(
              localized: "An unknown Synology API error occurred.",
              comment: "failure reason"
            )
        }
      case .badRepsonse(let response):
        let url = response.url?.absoluteString ?? String(localized: "<unknown URL>")
        return String(
          localized: "The response from “\(url)” was not an HTTP response.",
          comment: "failure reason"
        )

      case .noSession:
        return String(
          localized: "That Synology API requires a logged-in session.",
          comment: "failure reason"
        )
      case .APIInfoNotDownloaded:
        return String(
          localized: "Synology API method called before API info was downloaded.",
          comment: "failure reason"
        )
      case .unknownAPI(let api):
        return String(
          localized: "Synology API “\(api)” was not found in API info.",
          comment: "failure reason"
        )
      case let .unsupportedVersion(api, version):
        return String(
          localized: "Version \(version) is not supported for Synology API “\(api)”.",
          comment: "failure reason"
        )
    }
  }

  var recoverySuggestion: String? {
    switch self {
      case .APIError(let code):
        switch code {
          case .invalidParameter, .noSuchAPI, .noSuchMethod, .notSupportedInVersion:
            return String(
              localized: "Validate the data you are passing to the Synology API.",
              comment: "recovery suggestion"
            )
          case .sessionInterrupted, .sessionTimeout:
            return String(
              localized:
                "Retrieve a new session by making another login request to the Synology API.",
              comment: "recovery suggestion"
            )
          case .unknown:
            return String(
              localized: "Consult the Synology API documentation for more information.",
              comment: "recovery suggestion"
            )
          case .unauthorized:
            return String(
              localized: "Verify the permissions granted to the Synology user.",
              comment: "recovery suggestion"
            )
        }

      case .badRepsonse:
        return String(
          localized: "Verify that the Synology API hostname and path is correct.",
          comment: "recovery suggestion"
        )
      case .noSession:
        return String(
          localized: "Make a login request before using that API method.",
          comment: "recovery suggestion"
        )
      case .APIInfoNotDownloaded:
        return String(
          localized: "Call getAPIs() before making API calls using the Synology client.",
          comment: "recovery suggestion"
        )
      case .unknownAPI:
        return String(
          localized: "Check the output of getAPIs() to verify you are using the correct API name.",
          comment: "recovery suggestion"
        )
      case .unsupportedVersion:
        return String(
          localized: "Try using a newer or older API version.",
          comment: "recovery suggestion"
        )
    }
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
