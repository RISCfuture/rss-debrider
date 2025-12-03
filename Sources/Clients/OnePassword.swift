import Foundation

/// Container module for code related to 1Password CLI integration.
enum OnePassword {

  /**
   A client that retrieves credentials from 1Password using the `op` CLI tool.
  
   This client wraps the 1Password CLI (`op`) to securely retrieve usernames,
   passwords, and one-time passwords (OTPs) from a 1Password vault. The CLI
   must be installed and authenticated before using this client.
  
   - Important: The 1Password CLI must be installed at `/usr/bin/env op` and
     the user must be signed in to 1Password before using this client.
  
   - SeeAlso: [1Password CLI](https://developer.1password.com/docs/cli/)
   */
  actor Client {

    /// The unique identifier of the 1Password item containing the credentials.
    let itemID: String

    /// The username stored in the 1Password item, or `nil` if not found.
    var username: String? {
      get throws {
        try run("item", "get", itemID, "--fields", "label=username")
      }
    }

    /// The password stored in the 1Password item, or `nil` if not found.
    var password: String? {
      get throws {
        try run("item", "get", itemID, "--fields", "label=password", "--reveal")
      }
    }

    /// The current one-time password (TOTP) for the 1Password item, or `nil`
    /// if no OTP is configured.
    var OTP: String? {
      get throws {
        try run("item", "get", itemID, "--otp")
      }
    }

    /**
     Creates a new 1Password client.
    
     - Parameter itemID: The unique identifier of the 1Password item
       containing the credentials to retrieve.
     */
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
