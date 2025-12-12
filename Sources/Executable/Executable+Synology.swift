import Foundation

extension Executable {

  /**
   Creates and authenticates a Synology client.
  
   This method retrieves Synology credentials either from the configuration,
   1Password (if an item ID was provided), or by prompting the user
   interactively. It then creates the client, downloads API info, and logs in.
  
   - Parameters:
     - config: The application configuration containing Synology settings.
     - onePWClient: An optional 1Password client to retrieve credentials from.
       If `nil`, credentials will be taken from configuration or prompted
       interactively.
   - Returns: An authenticated Synology client ready for API calls.
   - Throws: Throws an error if authentication fails.
   */
  func getSynologyClient(
    config: AppConfiguration,
    onePWClient: OnePassword.Client? = nil
  ) async throws -> Synology.Client {
    let hostname = prompt(
      String(localized: "Hostname for Synology NAS:", comment: "prompt"),
      default: config.synologyHostname
    )

    var username = config.synologyUsername
    var password = config.synologyPassword
    var OTP: String?
    if let onePWClient {
      username = try await onePWClient.username ?? config.synologyUsername
      password = try await onePWClient.password ?? config.synologyPassword
      OTP = try await onePWClient.OTP
    }
    if username == nil {
      username = prompt(
        String(localized: "Username for Synology NAS:", comment: "prompt"),
        default: config.synologyUsername
      )
    }
    if password == nil {
      let passwordPrompt = String(localized: "Password for user %@:", comment: "prompt")
      password = promptPassword(
        String(format: passwordPrompt, username!),
        default: config.synologyPassword
      )
    }

    let synologyClient = Synology.Client(
      hostname: hostname,
      port: config.synologyPort,
      username: username!,
      password: password!
    )
    try await synologyClient.getAPIs()
    try await synologyClient.login(OTP: OTP)

    return synologyClient
  }
}
