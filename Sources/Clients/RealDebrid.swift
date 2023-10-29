import Foundation

/// Container module for code interfacing with Real-Debrid.
enum RealDebrid {
    
    /**
     Real-Debrid API client. To use this client, initialize with the API key
     for your paid Real-Debrid account. You can retrieve your API key at
     [https://real-debrid.com/apitoken](https://real-debrid.com/apitoken).
     
     To use this client, you should:
     
     1. Submit a magnet link with ``addMagnet(_:)``, which returns a torrent ID.
     2. Pass the torrent ID to ``torrentInfo(id:)`` to get the torrent status.
     3. Once the torrent status is ``Response/TorrentInfo/Status-swift.enum/awaitingFileSelection``,
        pass the IDs of the files within the torrent that you want to download
        to ``selectFiles(torrentID:file:)``.
     4. Keep querying ``torrentInfo(id:)``. Once the status is
        ``Response/TorrentInfo/Status-swift.enum/downloaded``, the torrent info
        will contain the restricted links to the selected files.
     5. Pass the restricted links to ``unrestrictedLink(url:)`` to get
        downloadable links.
     
     - SeeAlso: [Real-Debrid API documentation](https://api.real-debrid.com/)
     - SeeAlso: ``Response``
     - SeeAlso: ``RealDebridErrors``
     */
    class Client {
        private typealias Parameters = Dictionary<String, String>
        
        private static let host = "api.real-debrid.com"
        private static let path = "/rest/1.0"
        
        private let apiKey: String
        
        /**
         Initializes a Real-Debrid API client.
         
         - Parameter apiKey: The API key for your Real-Debrid account.
         */
        init(apiKey: String) {
            self.apiKey = apiKey
        }
        
        /**
         Submits a magnet link to Real-Debrid for downloading.
         
         - Parameter url: The magnet link to submit.
         - Returns: The ID of the torrent that was added. Use this ID with the
           ``torrentInfo(id:)`` method to get the file list.
         - Throws: Throws a ``RealDebridErrors`` error if the request fails.
         */
        func addMagnet(_ url: URL) async throws -> String {
            let request = try makeRequest(method: "POST", path: "/torrents/addMagnet", bodyParameters: [
                "magnet": url.absoluteString
            ])
            let data = try await executeRequest(request)
            
            let responseObject = try JSONDecoder().decode(Response.AddMagnet.self, from: data)
            return responseObject.id
        }
        
        /**
         Retrieves torrent info and status. You can use the returned object to
         get the status of a torrent (downloading, errored, awaiting file
         selection, etc.), to get the list of files within a torrent once its
         metadata has been downloaded, and to get the restricted download links
         for those files once they have been downloaded.
         
         - Parameter id: The Real-Debrid ID for the torrent.
         - Returns: Information about the torrent.
         - Throws: Throws a ``RealDebridErrors`` error if the request fails.
         */
        func torrentInfo(id: String) async throws -> Response.TorrentInfo {
            let request = try makeRequest(method: "GET", path: "/torrents/info/\(id)")
            let data = try await executeRequest(request)
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .custom { decoder in
                let container = try decoder.singleValueContainer()
                let str = try container.decode(String.self)
                
                let dateFormatter = ISO8601DateFormatter()
                dateFormatter.formatOptions = [.withFractionalSeconds]
                
                guard let date = dateFormatter.date(from: str) else {
                    throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid ISO 8601 date")
                }
                return date
            }
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            let responseObject = try decoder.decode(Response.TorrentInfo.self, from: data)
            return responseObject
        }
        
        /**
         Selects the files within a torrent that Real-Debrid should download and
         host. This method should be called only once a torrent has reached the
         ``RealDebrid/Response/TorrentInfo/Status-swift.enum/awaitingFileSelection``
         status. Query ``torrentInfo(id:)`` to determine the status of a torrent.
         
         - Parameter torrentID: The Real-Debrid ID for the torrent.
         - Parameter files: The IDs of the files to download. The file IDs are
           sequential numbers returned by
           ``RealDebrid/Response/TorrentInfo/File/id``.
         */
        func selectFiles(torrentID: String, files: Array<UInt>) async throws {
            let request = try makeRequest(method: "POST", path: "/torrents/selectFiles/\(torrentID)", bodyParameters: [
                "files": files.map(String.init).joined(separator: ",")
            ])
            try await executeRequest(request)
        }
        
        /// - SeeAlso: ``selectFiles(torrentID:files:)``
        func selectFiles(torrentID: String, file files: UInt...) async throws {
            try await selectFiles(torrentID: torrentID, files: files)
        }
        
        /**
         Given a restricted download URL returned by ``torrentInfo(id:)``,
         returns a download URL that can be directly used to download the file.
         
         - Parameter url: A restricted download URL from
           ``RealDebrid/Response/TorrentInfo/links``.
         - Returns: An unrestricted download URL.
         - Throws: Throws a ``RealDebridErrors`` error if the request fails.
         */
        func unrestrictedLink(url: URL) async throws -> URL {
            let request = try makeRequest(method: "POST", path: "/unrestrict/link", bodyParameters: [
                "link": url.absoluteString
            ])
            let data = try await executeRequest(request)
            
            let responseObject = try JSONDecoder().decode(Response.UnrestrictedLink.self, from: data)
            return responseObject.unrestrictedURL
        }
        
        private func makeRequest(method: String, path: String, queryParameters: Parameters? = nil, bodyParameters: Parameters? = nil) throws -> URLRequest {
            var components = URLComponents()
            components.scheme = "https"
            components.host = Self.host
            components.path = Self.path + path
            
            var request = URLRequest(url: components.url!)
            request.httpMethod = method
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            
            if let queryParameters = queryParameters {
                components.queryItems = queryParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
            }
            
            if let bodyParameters = bodyParameters {
                var bodyComponents = URLComponents()
                bodyComponents.queryItems = bodyParameters.map { URLQueryItem(name: $0.key, value: $0.value) }
                request.httpBody = bodyComponents.query?.data(using: .utf8)
            }
            
            return request
        }
        
        @discardableResult
        private func executeRequest(_ request: URLRequest) async throws -> Data {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let response = response as? HTTPURLResponse else {
                throw RealDebridErrors.badRepsonse(response)
            }
            
            logger.debug("Response from Real-Debrid: \(response.statusCode)", metadata: [
                "url": .stringConvertible(request.url!),
                "body": .string(.init(data: data, encoding: .utf8) ?? "<invalid utf8>")
            ])
            
            guard response.statusCode/100 == 2 else  {
                throw RealDebridErrors.badResponseStatus(response, body: data)
            }
            
            return data
        }
    }
    
    /// Response types for Real-Debrid API methods.
    enum Response {
        
        /**
         A response to a `/torrents/addMagnet` request. See
         [https://api.real-debrid.com](https://api.real-debrid.com) for
         information on the field values.
         */
        struct AddMagnet: Decodable {
            var id: String
            var uri: String
        }
        
        /**
         A response to a `/torrents/info/{id}` request. See
         [https://api.real-debrid.com](https://api.real-debrid.com) for
         information on the field values.
         */
        struct TorrentInfo: Decodable {
            var id: String
            var filename: String
            var originalFilename: String
            var hash: String
            var bytes: UInt
            var originalBytes: UInt
            var host: String
            var split: UInt
            var progress: UInt8 // 0 to 100
            var status: Status
            var added: Date
            var files: Array<File>
            var links: Array<URL>
            var ended: Date?
            var speed: UInt?
            var seeders: UInt?
            
            private enum CodingKeys: CodingKey {
                case id
                case filename
                case originalFilename
                case hash
                case bytes
                case originalBytes
                case host
                case split
                case progress
                case status
                case added
                case files
                case links
                case ended
                case speed
                case seeders
            }
            
            /**
             Torrent statuses used in `/torrents/info/{id}` responses. See
             [https://api.real-debrid.com](https://api.real-debrid.com) for
             information on the enum values.
             */
            enum Status: String, Decodable {
                case magnetError = "magnet_error"
                case magnetConversion = "magnet_conversion"
                case awaitingFileSelection = "waiting_files_selection"
                case queued, downloading, downloaded, error, virus, compressing, uploading, dead
            }
            
            /**
             A file within a `/torrents/info/{id}` response. See
             [https://api.real-debrid.com](https://api.real-debrid.com) for
             information on the field values.
             */
            struct File: Decodable {
                var id: UInt
                var path: String
                var bytes: UInt
                var selected: Bool
                
                init(from decoder: Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)
                    self.id = try container.decode(UInt.self, forKey: .id)
                    self.path = try container.decode(String.self, forKey: .path)
                    self.bytes = try container.decode(UInt.self, forKey: .bytes)
                    
                    let selected = try container.decode(UInt.self, forKey: .selected)
                    self.selected = selected == 1
                }
                
                private enum CodingKeys: CodingKey {
                    case id
                    case path
                    case bytes
                    case selected
                }
            }
        }
        
        /**
         Response type for `/unrestrict/link` requests. See
         [https://api.real-debrid.com](https://api.real-debrid.com) for
         information on the field values.
         */
        struct UnrestrictedLink: Decodable {
            var id: String
            var filename: String
            var mimeType: String
            var fileSize: UInt
            var originalURL: URL
            var host: String
            var hostIcon: URL?
            var chunks: UInt
            var crc: Bool
            var unrestrictedURL: URL
            var streamable: Bool
            
            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                self.id = try container.decode(String.self, forKey: .id)
                self.filename = try container.decode(String.self, forKey: .filename)
                self.mimeType = try container.decode(String.self, forKey: .mimeType)
                self.host = try container.decode(String.self, forKey: .host)
                self.hostIcon = try container.decodeIfPresent(URL.self, forKey: .hostIcon)
                self.chunks = try container.decode(UInt.self, forKey: .chunks)
                self.fileSize = try container.decode(UInt.self, forKey: .fileSize)
                self.originalURL = try container.decode(URL.self, forKey: .originalURL)
                self.unrestrictedURL = try container.decode(URL.self, forKey: .unrestrictedURL)
                
                 let crc = try container.decode(UInt.self, forKey: .crc)
                self.crc = crc == 1
                 let streamable = try container.decode(UInt.self, forKey: .streamable)
                self.streamable = streamable == 1
            }
            
            private enum CodingKeys: String, CodingKey {
                case id, filename, mimeType, host, hostIcon, chunks, crc, streamable
                case fileSize = "filesize"
                case originalURL = "link"
                case unrestrictedURL = "download"
            }
        }
    }
}
