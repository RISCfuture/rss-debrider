import ArgumentParser
import Foundation

/**
 The main entry point for the rss-debrider command-line tool.

 This command downloads magnet links from an RSS feed, submits them to
 Real-Debrid for remote downloading, and then sends the resulting download
 URLs to a Synology NAS for local download.

 Configuration can be provided via command-line arguments or environment
 variables. Environment variables are prefixed with `RSS_DEBRIDER_` (e.g.,
 `RSS_DEBRIDER_API_KEY`). Command-line arguments take precedence over
 environment variables.

 - SeeAlso: <doc:Usage>
 */
@main
struct Executable: AsyncParsableCommand {
  @Option(
    name: [.long, .customShort("k")],
    help: "The API key for Real-Debrid. Can also be set via RSS_DEBRIDER_API_KEY."
  )
  var apiKey: String?

  @Option(
    name: .shortAndLong,
    help: "The hostname of the Synology NAS. Can also be set via RSS_DEBRIDER_SYNOLOGY_HOSTNAME."
  )
  var hostname: String?

  @Option(
    name: .shortAndLong,
    help: "The port of the Synology NAS. Can also be set via RSS_DEBRIDER_SYNOLOGY_PORT."
  )
  var port: Int?

  @Option(
    name: .shortAndLong,
    help: "The username of the Synology NAS. Can also be set via RSS_DEBRIDER_SYNOLOGY_USERNAME."
  )
  var username: String?

  @Option(
    name: [.customShort("P"), .long],
    help: "The password of the Synology NAS. Can also be set via RSS_DEBRIDER_SYNOLOGY_PASSWORD."
  )
  var password: String?

  @Option(
    name: [.customShort("i"), .customLong("1pw-id")],
    help:
      "The ID of the 1Password item containing the information for the Synology account. Can also be set via RSS_DEBRIDER_1PW_ID."
  )
  var itemID: String?

  @Option(
    name: .long,
    help: "The path to the history file. Can also be set via RSS_DEBRIDER_HISTORY_FILE."
  )
  var historyFile: String?

  @Flag(
    name: .shortAndLong,
    help: "Enable debug-level logging. Can also be set via RSS_DEBRIDER_DEBUG."
  )
  var debug = false

  @Argument(
    help: "The URL of the RSS feed of magnet links.",
    transform: { URL(string: $0)! }
  )
  var url: URL

  mutating func run() async throws {
    try await withErrorHandling {
      // Build configuration from CLI arguments and environment variables
      let config = AppConfiguration(
        cliOverrides: .init(
          apiKey: apiKey,
          synologyHostname: hostname,
          synologyPort: port,
          synologyUsername: username,
          synologyPassword: password,
          onePasswordItemID: itemID,
          historyFile: historyFile,
          debug: debug ? true : nil
        )
      )

      // Validate required configuration
      guard let resolvedApiKey = config.apiKey else {
        throw ConfigurationError.missingRequired("API key")
      }

      // Configure logging
      let debugEnabled = config.debugLogging
      Task { @MainActor in logger.logLevel = debugEnabled ? .debug : .notice }

      // Build history file URL from config
      let historyFileURL = URL(
        filePath: config.historyFile,
        directoryHint: .notDirectory,
        relativeTo: .currentDirectory()
      )

      let rssClient = try await RSS.Client(feedURL: url, historyFileURL: historyFileURL)
      let onePWClient: OnePassword.Client? =
        config.onePasswordItemID != nil ? .init(itemID: config.onePasswordItemID!) : nil
      let synologyClient = try await getSynologyClient(config: config, onePWClient: onePWClient)

      let urls = try await rssClient.undownloadedLinks(rssClient.links())
      for await (url, debridedURL) in try debridURLs(urls, apiKey: resolvedApiKey) {
        try await synologyClient.createTask(url: debridedURL)
        try await rssClient.markAsDownloaded(link: url)
        await logDownloadTask(url: url, debridedURL: debridedURL)
      }

      try await synologyClient.logout()
    }
  }

  @MainActor
  private func logDownloadTask(url: URL, debridedURL: URL) {
    if let name = RSS.displayName(forMagnetURL: url) {
      logger.notice(
        "Added download task for \(name)",
        metadata: [
          "url": .stringConvertible(debridedURL)
        ]
      )
    } else {
      logger.notice(
        "Added download task",
        metadata: [
          "url": .stringConvertible(debridedURL)
        ]
      )
    }
  }
}
