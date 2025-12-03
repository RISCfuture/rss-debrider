import Foundation

extension Executable {

  /**
   Creates and authenticates a Synology client.
  
   This method retrieves Synology credentials either from command-line
   arguments, 1Password (if an item ID was provided), or by prompting the
   user interactively. It then creates the client, downloads API info, and
   logs in.
  
   - Parameter onePWClient: An optional 1Password client to retrieve
     credentials from. If `nil`, credentials will be taken from command-line
     arguments or prompted interactively.
   - Returns: An authenticated Synology client ready for API calls.
   - Throws: Throws an error if authentication fails.
   */
  func getSynologyClient(onePWClient: OnePassword.Client? = nil) async throws -> Synology.Client {
    let hostname = prompt(
      String(localized: "Hostname for Synology NAS:", comment: "prompt"),
      default: hostname
    )

    var username = self.username
    var password = self.password
    var OTP: String?
    if let onePWClient {
      username = try await onePWClient.username ?? self.username
      password = try await onePWClient.password ?? self.password
      OTP = try await onePWClient.OTP
    }
    if username == nil {
      username = prompt(
        String(localized: "Username for Synology NAS:", comment: "prompt"),
        default: self.username
      )
    }
    if password == nil {
      let passwordPrompt = String(localized: "Password for user %@:", comment: "prompt")
      password = promptPassword(String(format: passwordPrompt, username!), default: self.password)
    }

    let synologyClient = Synology.Client(
      hostname: hostname,
      port: port,
      username: username!,
      password: password!
    )
    try await synologyClient.getAPIs()
    try await synologyClient.login(OTP: OTP)

    return synologyClient
  }
}
