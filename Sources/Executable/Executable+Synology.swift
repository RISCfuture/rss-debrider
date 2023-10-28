import Foundation

extension Executable {
    func getSynologyClient() async throws -> Synology.Client {
        let (hostname, username, password) = promptForSynologyCredentials()
        let synologyClient = Synology.Client(hostname: hostname, port: port, username: username, password: password)
        try await synologyClient.getAPIs()
        try await synologyClient.login()
        
        return synologyClient
    }
    
    func promptForSynologyCredentials() -> (hostname: String, username: String, password: String) {
        let hostname = prompt(NSLocalizedString("Hostname for Synology NAS:", comment: "prompt"), default: hostname)
        let username = prompt(NSLocalizedString("Username for Synology NAS:", comment: "prompt"), default: username)
        let passwordPrompt = NSLocalizedString("Password for user %@:", comment: "prompt")
        let password = promptPassword(String(format: passwordPrompt, username), default: password)
        
        return (hostname, username, password)
    }
}
