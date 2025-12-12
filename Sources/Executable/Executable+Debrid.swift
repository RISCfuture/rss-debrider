import Foundation

extension Executable {

  /// Maximum number of magnet URLs to process concurrently to avoid
  /// overwhelming the Real-Debrid API rate limit (250 requests/minute).
  private static let maxConcurrentRequests = 3

  /**
   Processes a list of magnet URLs through Real-Debrid and returns an async
   stream of the resulting download URLs.
  
   For each magnet URL, this method:
   1. Submits the magnet to Real-Debrid
   2. Polls for torrent status until files are available
   3. Selects the largest file in the torrent
   4. Waits for the download to complete
   5. Unrestricts the download link
  
   - Parameters:
     - urls: The magnet URLs to process.
     - apiKey: The Real-Debrid API key.
   - Returns: An async stream of tuples containing the original magnet URL
     and the resulting debrided download URL.
   */
  func debridURLs(_ urls: [URL], apiKey: String) throws -> AsyncStream<
    (original: URL, debrided: URL)
  > {
    return AsyncStream { continuation in
      let client = RealDebrid.Client(apiKey: apiKey)
      Task {
        await withTaskGroup(of: Void.self) { group in
          var iterator = urls.makeIterator()
          var activeCount = 0

          // Start initial batch of concurrent tasks
          while activeCount < Self.maxConcurrentRequests, let magnetURL = iterator.next() {
            group.addTask {
              await self.processMagnetURLWithLogging(
                magnetURL,
                client: client,
                continuation: continuation
              )
            }
            activeCount += 1
          }

          // As each task completes, start the next one
          while activeCount > 0 {
            await group.next()
            activeCount -= 1

            if let magnetURL = iterator.next() {
              group.addTask {
                await self.processMagnetURLWithLogging(
                  magnetURL,
                  client: client,
                  continuation: continuation
                )
              }
              activeCount += 1
            }
          }
        }
        continuation.finish()
      }
    }
  }

  private func processMagnetURLWithLogging(
    _ magnetURL: URL,
    client: RealDebrid.Client,
    continuation: AsyncStream<(original: URL, debrided: URL)>.Continuation
  ) async {
    do {
      try await processMagnetURL(magnetURL, client: client) {
        continuation.yield(($0, $1))
      }
    } catch let error as LocalizedError {
      await logger.error(
        "Error when processing URL",
        metadata: [
          "url": .stringConvertible(magnetURL),
          "errorDescription": .string(error.localizedDescription),
          "failureReason": .string(error.failureReason ?? ""),
          "recoverySuggestion": .string(error.recoverySuggestion ?? "")
        ]
      )
    } catch {
      await logger.error(
        "Error when processing URL",
        metadata: [
          "url": .stringConvertible(magnetURL),
          "errorDescription": .string(error.localizedDescription)
        ]
      )
    }
  }

  private func processMagnetURL(
    _ magnetURL: URL,
    client: RealDebrid.Client,
    callback: ((URL, URL) -> Void)
  ) async throws {
    let torrentID = try await client.addMagnet(magnetURL)

    statusLoop: while true {
      let torrentInfo = try await client.torrentInfo(id: torrentID)

      switch torrentInfo.status {
        case .queued, .downloading, .compressing, .uploading, .magnetConversion:
          try await Task.sleep(for: .seconds(1))

        case .magnetError, .virus, .error, .dead:
          throw RealDebridTorrentError.downloadFailed(id: torrentID, status: torrentInfo.status)

        case .awaitingFileSelection:
          let `continue` = try await selectLargestFile(
            client: client,
            torrentID: torrentID,
            torrentInfo: torrentInfo
          )
          if !`continue` { break statusLoop }

        case .downloaded:
          if torrentInfo.links.isEmpty {
            await logger.warning(
              "No links in torrent",
              metadata: [
                "torrentID": .string(torrentID)
              ]
            )
          }
          for debridedURL in torrentInfo.links {
            let unrestrictedURL = try await client.unrestrictedLink(url: debridedURL)
            callback(magnetURL, unrestrictedURL)
          }
          break statusLoop
      }
    }
  }

  private func selectLargestFile(
    client: RealDebrid.Client,
    torrentID: String,
    torrentInfo: RealDebrid.Response.TorrentInfo
  ) async throws -> Bool {
    guard let largestFile = torrentInfo.files.max(by: { $0.bytes < $1.bytes }) else {
      await logger.warning(
        "No files in torrent",
        metadata: [
          "torrentID": .string(torrentID)
        ]
      )
      return false
    }

    try await client.selectFiles(torrentID: torrentID, file: largestFile.id)
    return true
  }
}
