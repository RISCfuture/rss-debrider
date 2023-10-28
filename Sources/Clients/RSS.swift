import Foundation
import RegexBuilder

/// Container module for code related to RSS feed consumption.
enum RSS {
    
    /**
     A client that downloads and parses an RSS feed for magnet URLs. This would
     typically be used with a website like [showRSS](https://showrss.info/).
     
     A client can be initialized with the URL to a history file, which is a
     newline-delimited list of magnet URLs that have already been downloaded.
     The ``undownloadedLinks(_:)`` and ``markAsDownloaded(link:)`` methods can
     be used to track which links have already been downloaded.
     
     - SeeAlso: ``RSSErrors``
     */
    class Client {
        private let data: Data
        private let historyFileURL: URL?
        
        /**
         Initialize a client that parses the given RSS data.
         
         - Parameter data: The RSS feed data.
         - Parameter historyFileURL: The URL to a file that will be used to
           store the magnet links for files that have already been downloaded.
           If this is `nil`, no history will be kept.
         */
        init(data: Data, historyFileURL: URL? = nil) {
            self.data = data
            self.historyFileURL = historyFileURL
        }
        
        /**
         Initialize a client that downloads and parses the given RSS feed.
         
         - Parameter feedURL: The URL to the RSS feed.
         - Parameter historyFileURL: The URL to a file that will be used to
           store the magnet links for files that have already been downloaded.
           If this is `nil`, no history will be kept.
         - Throws: Throws an error if the RSS feed could not be downloaded or
           parsed.
         */
        convenience init(feedURL: URL, historyFileURL: URL? = nil) async throws {
            let (data, response) = try await URLSession.shared.data(from: feedURL)
            
            guard let response = response as? HTTPURLResponse else { throw RSSErrors.badRepsonse(response) }
            guard response.statusCode/100 == 2 else  { throw RSSErrors.badResponseStatus(response, body: data) }
            
            self.init(data: data, historyFileURL: historyFileURL)
        }
        
        /// - Returns: The magnet links found by the parser.
        func links() -> Array<URL> {
            let parser = XMLParser(data: data)
            let delegate = ParserDelegate()
            parser.delegate = delegate
            parser.parse()
            
            return delegate.links
        }
        
        /**
         Removes already-downloaded links from a list of links and returns the
         remaining links. Does nothing if `historyFileURL` was not set.
         
         - Parameter links: The links to filter.
         - Returns: The links that have not already been downloaded.
         - Throws: Throws an error if the history file could not be read.
         - SeeAlso: ``markAsDownloaded(link:)``
         */
        func undownloadedLinks(_ links: Array<URL>) throws -> Array<URL> {
            guard let historyFileURL = historyFileURL else { return links }
            guard historyFileURL.isFileURL else { return links }
            guard FileManager.default.fileExists(atPath: historyFileURL.path) else { return links }
            
            let history = try String(contentsOf: historyFileURL).components(separatedBy: "\n")
            
            return links.filter { !history.contains($0.absoluteString) }
        }
        
        /**
         Marks a link as having been downloaded by storing it in the history
         file. Does nothing if `historyFileURL` was not set.
         
         - Parameter link: The link to mark as downloaded.
         - Throws: Throws an error if the history file could not be read or
           written.
         - SeeAlso: ``undownloadedLinks(_:)``
         */
        func markAsDownloaded(link: URL) throws {
            guard let historyFileURL = historyFileURL else { return }
            guard historyFileURL.isFileURL else { return }
            
            let history: Array<String> = if FileManager.default.fileExists(atPath: historyFileURL.path) {
                try String(contentsOf: historyFileURL).components(separatedBy: "\n")
            } else {
                []
            }
            
            var newHistory = Set(history)
            newHistory.insert(link.absoluteString)
            try newHistory.joined(separator: "\n").write(to: historyFileURL, atomically: true, encoding: .utf8)
        }
    }
    
    @objc private class ParserDelegate: NSObject, XMLParserDelegate {
        var links: Array<URL> = []
        
        private static let magnetURLRegex = Regex {
            Anchor.startOfLine
            "magnet:?xt=urn:btih:"
            OneOrMore(.any)
            Anchor.endOfLine
        }
        
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
            guard elementName == "enclosure" else { return }
            guard let urlString = attributeDict["url"] else { return }
            guard try! Self.magnetURLRegex.firstMatch(in: urlString) != nil else {
                logger.info("Not a magnet URL", metadata: [
                    "url": .string(urlString)
                ])
                return
            }
            
            guard let decodedURLString = CFXMLCreateStringByUnescapingEntities(nil, urlString as CFString, nil) else {
                logger.info("Couldn’t decode XML entities", metadata: [
                    "url": .string(urlString)
                ])
                return
            }
            guard let url = URL(string: decodedURLString as String) else { return }
            
            links.append(url)
        }
    }
    
    /**
     Returns a human-readable torrent name for a magnet link.
     
     - Parameter url: The magnet link.
     - Returns: The display name, or `nil` if the name could not be determined.
     */
    static func displayName(forMagnetURL url: URL) -> String? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        return components.queryItems?.first(where: { $0.name == "dn" })?.value
    }
}
