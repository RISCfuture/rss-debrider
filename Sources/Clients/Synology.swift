import Foundation

/// Container module for code related to the Synology API.
enum Synology {
    
    /**
     A client that interfaces with the Synology API. This client must be
     initialized with the hostname of the Synology NAS, as well as the username
     and password to an account with the appropriate permissions for the APIs
     being used.
     
     Before using this client, call the ``getAPIs()`` method to download the
     current endpoints for the Synology API. You will also need to call
     ``login()`` before making any authenticated API requests.
     
     - SeeAlso: [Synology DownloadStation API](https://global.download.synology.com/download/Document/Software/DeveloperGuide/Package/DownloadStation/All/enu/Synology_Download_Station_Web_API.pdf)
     - SeeAlso: ``SynologyErrors``
     - SeeAlso: ``Response``
     */
    actor Client {
        private typealias Parameters = Dictionary<String, String>
        
        private static let apiInfoPath = "/webapi/entry.cgi"
        private static let sessionName = "rss-debrider"
        
        /// The hostname of the Synology NAS.
        let hostname: String
        
        /// The port of the Synology NAS HTTP API (typically 5000).
        let port: Int
        
        /// The username of an account on the Synology NAS.
        let username: String
        
        /// The password of an account on the Synology NAS.
        let password: String
        
        /// An authenticated token for the current session. `nil` if the client
        /// is not logged in.
        var sessionID: String? = nil
        
        private var APIs: Dictionary<String, API>? = nil
        
        /**
         Creates a new client.
         
         - Parameter hostname: The hostname of the Synology NAS.
         - Parameter port: The port of the Synology NAS HTTP API (typically 5000).
         - Parameter username: The username of an account on the Synology NAS.
         - Parameter password: The password of an account on the Synology NAS.
         */
        init(hostname: String, port: Int = 5000, username: String, password: String) {
            self.hostname = hostname
            self.username = username
            self.password = password
            self.port = port
        }
        
        /**
         Downloads the current endpoints for the Synology API. This method
         must be called before using any other API methods.
            
         - Returns: A dictionary mapping API names to their endpoints.
           (This data is also stored in the client, and can be ignored.)
         - Throws: Throws a ``SynologyErrors`` error if an API error occurs.
         */
        @discardableResult
        func getAPIs() async throws -> Dictionary<String, API> {
            let components = makeAPIInfoURLComponents()
            let request = try makeRequest(components: components)
            
            let data = try await executeRequest(request, decoder: Dictionary<String, API>.self)
            APIs = data
            return data
        }
        
        /**
         Logs into the Synology NAS. This method must be called before using
         any authenticated API methods.
         
         - Parameter OTP: The two-factor code for the account, if needed.
         - Returns: The session data from the login request. (This data is also
           stored in the client, and can be ignored.)
         - Throws: Throws a ``SynologyErrors`` error if an API error occurs.
         */
        @discardableResult
        func login(OTP: String? = nil) async throws -> Login {
            var queryParameters = [
                "account": username,
                "passwd": password,
                "session": Self.sessionName,
                "format": "sid",
            ]
            if let OTP { queryParameters["otp_code"] = OTP }
            
            let components = try makeURLComponents(api: "SYNO.API.Auth", method: "login", version: 6, authenticated: false, queryParameters: queryParameters)
            let request = try makeRequest(components: components)
            
            let data = try await executeRequest(request, decoder: Login.self)
            sessionID = data.sessionID
            
            return data
        }
        
        /**
         Invalidates the current session.
         
         - Throws: Throws a ``SynologyErrors`` error if an API error occurs.
         */
        func logout() async throws {
            let components = try makeURLComponents(api: "SYNO.API.Auth", method: "logout", version: 6, queryParameters: [
                "session": Self.sessionName
            ])
            let request = try makeRequest(components: components)
            try await executeRequest(request, decoder: Empty.self)
        }
        
        
        /**
         Creates a Download Center task for the given URLs. The URLs will be
         downloaded immediately.
         
         - Parameter urls: The URLs to download.
         - Throws: Throws a ``SynologyErrors`` error if an API error occurs.
         */
        func createTask(urls: Array<URL>) async throws {
            let components = try makeURLComponents(api: "SYNO.DownloadStation.Task", method: "create", version: 3, queryParameters: [
                "uri": urls.map(\.absoluteString).joined(separator: ",")
            ])
            let request = try makeRequest(components: components)
            try await executeRequest(request, decoder: Empty.self)
        }
        
        /// - SeeAlso: ``createTask(urls:)``
        func createTask(url urls: URL...) async throws {
            try await createTask(urls: urls)
        }
        
        private func makeAPIInfoURLComponents() -> URLComponents {
            var components = URLComponents()
            components.scheme = "http"
            components.host = hostname
            components.port = port
            components.path = Self.apiInfoPath
            components.queryItems = [
                URLQueryItem(name: "api", value: "SYNO.API.Info"),
                URLQueryItem(name: "method", value: "query"),
                URLQueryItem(name: "version", value: "1"),
            ]
            
            return components
        }
        
        private func makeURLComponents(api: String, method: String, version: UInt, authenticated: Bool = true, queryParameters: Parameters? = nil) throws -> URLComponents {
            guard let APIs = APIs else { throw SynologyErrors.APIInfoNotDownloaded }
            guard let apiInfo = APIs[api] else { throw SynologyErrors.unknownAPI(api) }
            guard apiInfo.minVersion <= version && version <= apiInfo.maxVersion else {
                throw SynologyErrors.unsupportedVersion(api: api, version: version)
            }
            
            guard !authenticated || sessionID != nil else { throw SynologyErrors.noSession }
            
            var queryItems = [
                URLQueryItem(name: "api", value: api),
                URLQueryItem(name: "version", value: String(version)),
                URLQueryItem(name: "method", value: method),
            ]
            if let sessionID = sessionID {
                queryItems.append(URLQueryItem(name: "_sid", value: sessionID))
            }
            if let queryParameters = queryParameters {
                for (key, value) in queryParameters {
                    queryItems.append(URLQueryItem(name: key, value: value))
                }
            }
            
            var components = URLComponents()
            components.scheme = "http"
            components.host = hostname
            components.port = port
            components.path = "/webapi/\(apiInfo.path)"
            components.queryItems = queryItems
            
            return components
        }
        
        private func makeRequest(components: URLComponents) throws -> URLRequest {
            guard let url = components.url else { throw Errors.badURL(components.description) }
            
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            
            return request
        }
        
        @discardableResult
        private func executeRequest<T: Decodable>(_ request: URLRequest, decoder: T.Type) async throws -> T {
            let (data, _) = try await URLSession.shared.data(for: request)
            await logger.debug("Response from Synology", metadata: [
                "url": .stringConvertible(request.url!),
                "body": .string(.init(data: data, encoding: .utf8) ?? "<invalid utf8>")
            ])
            
            let decodedData = try JSONDecoder().decode(Response<T>.self, from: data)
            switch decodedData {
                case let .success(data):
                    return data
                case let .failure(error):
                    throw error
            }
        }
    }
    
    /// A response from a Synology API call.
    enum Response<T: Decodable>: Decodable {
        
        /**
         A successful response.
         
         - Parameter data: The data returned by the API call.
         */
        case success(data: T)
        
        /**
         An unsuccessful response.
         
         - Parameter error: The error returned by the API call.
         */
        case failure(error: Error)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let success = try container.decode(Bool.self, forKey: .success)
            
            if success {
                if T.self == Empty.self {
                    self = .success(data: Empty() as! T)
                    return
                }
                let data = try container.decode(T.self, forKey: .data)
                self = .success(data: data)
            } else {
                let error = try container.decode(Error.self, forKey: .error)
                self = .failure(error: error)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case success, error, data
        }
        
    }
    
    /**
     A response to an `SYNO.API.Auth` request. See the Synology Web API
     documentation for information about the fields.
     */
    struct Login: Decodable {
        var sessionID: String
        var deviceID: String
        var isPortalPort: Bool
        
        private enum CodingKeys: String, CodingKey {
            case sessionID = "sid"
            case deviceID = "did"
            case isPortalPort = "is_portal_port"
        }
    }
    
    /**
     A response to a `SYNO.API.Info` request. See the Synology Web API
     documentation for information about the fields.
     */
    struct API: Decodable {
        var minVersion: UInt
        var maxVersion: UInt
        var path: String
        var requestFormat: RequestFormat?
        
        enum RequestFormat: String, Decodable {
            case JSON
        }
    }
    
    private struct Empty: Decodable {}
    
    /**
     An error returned by a Synology API call. See the Synology Web API for
     information about the specific errors.
     */
    enum Error: Swift.Error, Decodable {
        
        /// Represents error code 101.
        case invalidParameter
        
        /// Represents error code 102.
        case noSuchAPI
        
        /// Represents error code 103.
        case noSuchMethod
        
        /// Represents error code 104.
        case notSupportedInVersion
        
        /// Represents error code 105.
        case unauthorized
        
        /// Represents error code 106.
        case sessionTimeout
        
        /// Represents error code 107.
        case sessionInterrupted
        
        /**
         Represents an error code not otherwise in this list.
         
         - Parameter code: The error code.
         */
        case unknown(code: Int)
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let code = try container.decode(Int.self, forKey: .code)
            switch code {
                case 101: self = .invalidParameter
                case 102: self = .noSuchAPI
                case 103: self = .noSuchMethod
                case 104: self = .notSupportedInVersion
                case 105: self = .unauthorized
                case 106: self = .sessionTimeout
                case 107: self = .sessionInterrupted
                default: self = .unknown(code: code)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case code
        }
    }
}
