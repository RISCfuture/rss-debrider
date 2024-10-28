import Foundation
import ArgumentParser

@main
struct Executable: AsyncParsableCommand {
    @Option(
        name: [.long, .customShort("k")],
        help: "The API key for Real-Debrid.")
    var apiKey: String
    
    @Option(
        name: .shortAndLong,
        help: "The hostname of the Synology NAS.")
    var hostname: String? = nil
    
    @Option(
        name: .shortAndLong,
        help: "The port of the Synology NAS.")
    var port = 5000
    
    @Option(
        name: .shortAndLong,
        help: "The username of the Synology NAS.")
    var username: String? = nil
    
    @Option(
        name: [.customShort("P"), .long],
        help: "The password of the Synology NAS.")
    var password: String? = nil
    
    @Option(name: [.customShort("i"), .customLong("1pw-id")],
            help: "The ID of the 1Password item containing the information for the Synology account.")
    var itemID: String? = nil
    
    @Flag(
        name: .shortAndLong,
        help: "Enable debug-level logging.")
    var debug = false
    
    @Argument(
        help: "The URL of the RSS feed of magnet links.",
        transform: { URL(string: $0)! })
    var url: URL
    
    private var historyFileURL: URL {
        .init(filePath: ".rss-client-history", directoryHint: .notDirectory, relativeTo: .currentDirectory())
    }
    
    mutating func run() async throws {
        try await withErrorHandling {
            logger.logLevel = debug ? .debug : .notice
            
            let rssClient = try await RSS.Client(feedURL: url, historyFileURL: historyFileURL)
            let onePWClient: OnePassword.Client? = itemID != nil ? .init(itemID: itemID!) : nil
            let synologyClient = try await getSynologyClient(onePWClient: onePWClient)
            
            let urls = try rssClient.undownloadedLinks(rssClient.links())
            for await (url, debridedURL) in try debridURLs(urls) {
                try await synologyClient.createTask(url: debridedURL)
                try rssClient.markAsDownloaded(link: url)
                logDownloadTask(url: url, debridedURL: debridedURL)
            }
            
            try await synologyClient.logout()
        }
    }
    
    private func logDownloadTask(url: URL, debridedURL: URL) {
        if let name = RSS.displayName(forMagnetURL: url) {
            logger.notice("Added download task for \(name)", metadata: [
                "url": .stringConvertible(debridedURL)
            ])
        } else {
            logger.notice("Added download task", metadata: [
                "url": .stringConvertible(debridedURL)
            ])
        }
    }
}
