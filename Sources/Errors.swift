import Foundation

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

extension Errors: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .badURL:
                return NSLocalizedString("Improperly formatted URL", comment: "error description")
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .badURL(url):
                let format = NSLocalizedString("The URL “%@” could not be parsed as a URL.", comment: "failure reason")
                return String(format: format, url)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .badURL:
                return NSLocalizedString("Verify that the RSS feed is returning correct magnetic URLs.", comment: "recovery suggestion")
        }
    }
}

extension RealDebridErrors: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .badRepsonse:
                return NSLocalizedString("Unexpected response from Real-Debrid API", comment: "error description")
            case .badResponseStatus:
                return NSLocalizedString("Non-success response from Real-Debrid API", comment: "error description")
            case .torrentDownloadFailed:
                return NSLocalizedString("Real-Debrid couldn’t download torrent.", comment: "error description")
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .badRepsonse(response):
                let format = NSLocalizedString("The response from “%@” was not an HTTP response.", comment: "failure reason")
                let url = response.url?.absoluteString ?? "<unknown URL>"
                return String(format: format, url)
                
            case let .badResponseStatus(response, body):
                switch response.statusCode {
                    case 401:
                        return NSLocalizedString("Bad Real-Debrid API key.", comment: "failure reason")
                    case 403:
                        return NSLocalizedString("Real-Debrid account is not authorized.", comment: "failure reason")
                    default:
                        return realDebridError(body: body) ?? defaultRealDebridError(response: response)
                }
                
            case let .torrentDownloadFailed(id, status):
                let format = switch status {
                case .dead:
                    NSLocalizedString("Couldn’t download torrent “%@”: Torrent is dead.", comment: "failure reason")
                case .error:
                    NSLocalizedString("Couldn’t download torrent “%@”: An unknown error occurred.", comment: "failure reason")
                case .magnetError:
                    NSLocalizedString("Couldn’t download torrent “%@”: Failed to get magnet data.", comment: "failure reason")
                case .virus:
                    NSLocalizedString("Couldn’t download torrent “%@”: Torrent contains a virus.", comment: "failure reason")
                default:
                    preconditionFailure("Not an error status")
                }
                return String(format: format, id)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .badRepsonse:
                return NSLocalizedString("Verify that the server is accessible from your computer.", comment: "recovery suggestion")
                
            case let .badResponseStatus(response, _):
                switch response.statusCode {
                    case 401:
                        return NSLocalizedString("Double-check the value passed to the -r option.", comment: "recovery suggestion")
                    case 403:
                        return NSLocalizedString("Make sure you are a premium Real-Debrid subscriber, and your account is in good standing.", comment: "recovery suggestion")
                    default:
                        return NSLocalizedString("Consult the Real-Debrid API documentation for more information.", comment: "recovery suggestion")
                }
                
            case let .torrentDownloadFailed(_, status):
                switch status {
                    case .dead:
                        return NSLocalizedString("Try the download again later.", comment: "recovery suggestion")
                    default:
                        return NSLocalizedString("Try a different torrent or magnet URL.", comment: "recovery suggestion")

                }
        }
    }
    
    private func realDebridError(body: Data) -> String? {
        guard let body = try? JSONDecoder().decode(RealDebridError.self, from: body) else { return nil }
        let format = NSLocalizedString("Real-Debrid API returned error %d (%@): %@", comment: "failure reason")
        return String(format: format, body.errorCode, body.error, body.errorDetails)
    }
    
    private func defaultRealDebridError(response: HTTPURLResponse) -> String {
        let format = NSLocalizedString("The response from “%@” had status code %d.", comment: "failure reason")
        let url = response.url?.absoluteString ?? "<unknown URL>"
        return String(format: format, url, response.statusCode)
    }
}

extension RSSErrors: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .badRepsonse:
                return NSLocalizedString("Unexpected response from RSS provider", comment: "error description")
            case .badResponseStatus:
                return NSLocalizedString("Non-success response from RSS provider", comment: "error description")
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .badRepsonse(response):
                let format = NSLocalizedString("The response from “%@” was not an HTTP response.", comment: "failure reason")
                let url = response.url?.absoluteString ?? "<unknown URL>"
                return String(format: format, url)
                
            case let .badResponseStatus(response, _):
                let format = NSLocalizedString("The response from “%@” had status code %d.", comment: "failure reason")
                let url = response.url?.absoluteString ?? "<unknown URL>"
                return String(format: format, url, response.statusCode)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case .badRepsonse:
                return NSLocalizedString("Verify that the server is accessible from your computer.", comment: "recovery suggestion")
            case .badResponseStatus:
                return NSLocalizedString("Verify the RSS URL passed to rss-debrider.", comment: "recovery suggestion")
        }
    }
}

extension SynologyErrors: LocalizedError {
    var errorDescription: String? {
        switch self {
            case .APIError:
                return NSLocalizedString("The Synology API returned an error", comment: "error description")
            case .badRepsonse:
                return NSLocalizedString("Unexpected response from Synology API", comment: "error description")
            case .noSession:
                return NSLocalizedString("Must be logged in to use that Synology API method", comment: "error description")
            case .APIInfoNotDownloaded:
                return NSLocalizedString("API info not yet downloaded from Synology", comment: "error description")
            case .unknownAPI:
                return NSLocalizedString("Unknown Synology API", comment: "error description")
            case .unsupportedVersion:
                return NSLocalizedString("Given Synology API version is unsupported", comment: "error description")
        }
    }
    
    var failureReason: String? {
        switch self {
            case let .APIError(code):
                switch code {
                    case .invalidParameter:
                        return NSLocalizedString("An invalid parameter was provided to the Synology API.", comment: "failure reason")
                    case .noSuchAPI:
                        return NSLocalizedString("An invalid API name was provided to the Synology API.", comment: "failure reason")
                    case .noSuchMethod:
                        return NSLocalizedString("An invalid method name was provided to the Synology API.", comment: "failure reason")
                    case .notSupportedInVersion:
                        return NSLocalizedString("Synology API is not supported in the provided version.", comment: "failure reason")
                    case .sessionInterrupted:
                        return NSLocalizedString("The current Synology session was interrupted by another login.", comment: "failure reason")
                    case .sessionTimeout:
                        return NSLocalizedString("The Synology session has timed out.", comment: "failure reason")
                    case .unauthorized:
                        return NSLocalizedString("Action is not authorized for the Synology user.", comment: "failure reason")
                    case .unknown:
                        return NSLocalizedString("An unknown Synology API error occurred.", comment: "failure reason")
                }
            case let .badRepsonse(response):
                let format = NSLocalizedString("The response from “%@” was not an HTTP response.", comment: "failure reason")
                let url = response.url?.absoluteString ?? "<unknown URL>"
                return String(format: format, url)
                
            case .noSession:
                return NSLocalizedString("That Synology API requires a logged-in session.", comment: "failure reason")
            case .APIInfoNotDownloaded:
                return NSLocalizedString("Synology API method called before API info was downloaded.", comment: "failure reason")
            case let .unknownAPI(api):
                let format = NSLocalizedString("Synology API “%@” was not found in API info.", comment: "failure reason")
                return String(format: format, api)
            case let .unsupportedVersion(api, version):
                let format = NSLocalizedString("Version %u is not supported for Synology API “%@”.", comment: "failure reason")
                return String(format: format, version, api)
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
            case let .APIError(code):
                switch code {
                    case .invalidParameter, .noSuchAPI, .noSuchMethod, .notSupportedInVersion:
                        return NSLocalizedString("Validate the data you are passing to the Synology API.", comment: "recovery suggestion")
                    case .sessionInterrupted, .sessionTimeout:
                        return NSLocalizedString("Retrieve a new session by making another login request to the Synology API.", comment: "recovery suggestion")
                    case .unknown:
                        return NSLocalizedString("Consult the Synology API documentation for more information.", comment: "recovery suggestion")
                    case .unauthorized:
                        return NSLocalizedString("Verify the permissions granted to the Synology user.", comment: "recovery suggestion")
                }
                
            case .badRepsonse:
                return NSLocalizedString("Verify that the Synology API hostname and path is correct.", comment: "recovery suggestion")
            case .noSession:
                return NSLocalizedString("Make a login request before using that API method.", comment: "recovery suggestion")
            case .APIInfoNotDownloaded:
                return NSLocalizedString("Call getAPIs() before making API calls using the Synology client.", comment: "recovery suggestion")
            case .unknownAPI:
                return NSLocalizedString("Check the output of getAPIs() to verify you are using the correct API name.", comment: "recovery suggestion")
            case .unsupportedVersion:
                return NSLocalizedString("Try using a newer or older API version.", comment: "recovery suggestion")
        }
    }
}

fileprivate struct RealDebridError: Codable {
    var error: String
    var errorDetails: String
    var errorCode: Int
    
    enum CodingKeys: String, CodingKey {
        case error
        case errorDetails = "error_details"
        case errorCode = "error_code"
    }
}
