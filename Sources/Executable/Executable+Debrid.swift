import Foundation

extension Executable {
  func debridURLs(_ urls: [URL]) throws -> AsyncStream<(original: URL, debrided: URL)> {
    return AsyncStream { continuation in
      let client = RealDebrid.Client(apiKey: apiKey)
      Task {
        await withDiscardingTaskGroup { group in
          for magnetURL in urls {
            group.addTask {
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
          }
        }
        continuation.finish()
      }
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
          throw RealDebridErrors.torrentDownloadFailed(id: torrentID, status: torrentInfo.status)

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
