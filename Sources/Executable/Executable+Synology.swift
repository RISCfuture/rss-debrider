import Foundation

extension Executable {
    func getSynologyClient(onePWClient: OnePassword.Client? = nil) async throws -> Synology.Client {
        let hostname = prompt(String(localized: "Hostname for Synology NAS:", comment: "prompt"), default: hostname)

        var username = self.username, password = self.password, OTP: String?
        if let onePWClient {
            username = try await onePWClient.username ?? self.username
            password = try await onePWClient.password ?? self.password
            OTP = try await onePWClient.OTP
        }
        if username == nil {
            username = prompt(String(localized: "Username for Synology NAS:", comment: "prompt"), default: self.username)
        }
        if password == nil {
            let passwordPrompt = String(localized: "Password for user %@:", comment: "prompt")
            password = promptPassword(String(format: passwordPrompt, username!), default: self.password)
        }

        let synologyClient = Synology.Client(hostname: hostname, port: port, username: username!, password: password!)
        try await synologyClient.getAPIs()
        try await synologyClient.login(OTP: OTP)

        return synologyClient
    }
}
