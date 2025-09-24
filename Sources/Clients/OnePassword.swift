import Foundation

enum OnePassword {
  actor Client {
    let itemID: String

    var username: String? {
      get throws {
        try run("item", "get", itemID, "--fields", "label=username")
      }
    }

    var password: String? {
      get throws {
        try run("item", "get", itemID, "--fields", "label=password", "--reveal")
      }
    }

    var OTP: String? {
      get throws {
        try run("item", "get", itemID, "--otp")
      }
    }

    init(itemID: String) {
      self.itemID = itemID
    }

    private func run(_ commands: String...) throws -> String? {
      let process = Process()
      let pipe = Pipe()

      process.executableURL = URL(filePath: "/usr/bin/env", directoryHint: .notDirectory)
      process.arguments = ["op"] + commands
      process.standardOutput = pipe

      try process.run()
      process.waitUntilExit()

      let data = pipe.fileHandleForReading.readDataToEndOfFile()
      return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
  }
}
