import Configuration
import Foundation

/// Centralized configuration management for rss-debrider.
///
/// This struct provides a unified interface to access configuration values from
/// multiple sources with the following priority (highest to lowest):
/// 1. Command-line arguments (passed as overrides)
/// 2. Environment variables (prefixed with `RSS_DEBRIDER_`)
/// 3. Default values
///
/// ## Environment Variables
///
/// | Setting | Environment Variable |
/// |---------|---------------------|
/// | API key | `RSS_DEBRIDER_API_KEY` |
/// | Synology hostname | `RSS_DEBRIDER_SYNOLOGY_HOSTNAME` |
/// | Synology port | `RSS_DEBRIDER_SYNOLOGY_PORT` |
/// | Synology username | `RSS_DEBRIDER_SYNOLOGY_USERNAME` |
/// | Synology password | `RSS_DEBRIDER_SYNOLOGY_PASSWORD` |
/// | 1Password item ID | `RSS_DEBRIDER_1PW_ID` |
/// | History file path | `RSS_DEBRIDER_HISTORY_FILE` |
/// | Debug logging | `RSS_DEBRIDER_DEBUG` |
struct AppConfiguration: Sendable {

  // MARK: - Properties

  private let reader: ConfigReader

  // MARK: - Typed Accessors

  /// The Real-Debrid API key.
  var apiKey: String? {
    reader.string(forKey: Keys.apiKey, isSecret: true)
  }

  /// The Synology NAS hostname.
  var synologyHostname: String? {
    reader.string(forKey: Keys.synologyHostname)
  }

  /// The Synology NAS port.
  var synologyPort: Int {
    reader.int(forKey: Keys.synologyPort, default: 5000)
  }

  /// The Synology NAS username.
  var synologyUsername: String? {
    reader.string(forKey: Keys.synologyUsername)
  }

  /// The Synology NAS password.
  var synologyPassword: String? {
    reader.string(forKey: Keys.synologyPassword, isSecret: true)
  }

  /// The 1Password item ID for Synology credentials.
  var onePasswordItemID: String? {
    reader.string(forKey: Keys.onePasswordItemID)
  }

  /// The path to the history file.
  var historyFile: String {
    reader.string(forKey: Keys.historyFile, default: ".rss-client-history")
  }

  /// Whether debug logging is enabled.
  var debugLogging: Bool {
    reader.bool(forKey: Keys.debug, default: false)
  }

  // MARK: - Initialization

  /// Creates a new configuration by loading from environment variables with optional CLI overrides.
  ///
  /// - Parameter cliOverrides: Values from command-line arguments that take priority over
  ///   environment variables.
  init(cliOverrides: CLIOverrides = .init()) {
    var providers: [any ConfigProvider] = []

    // CLI overrides (highest priority)
    let overrideValues = cliOverrides.asConfigValues()
    if !overrideValues.isEmpty {
      providers.append(InMemoryProvider(name: "cli", values: overrideValues))
    }

    // Environment variables with RSS_DEBRIDER_ prefix
    let envProvider = EnvironmentVariablesProvider(
      secretsSpecifier: .specific([
        "RSS_DEBRIDER_API_KEY",
        "RSS_DEBRIDER_SYNOLOGY_PASSWORD"
      ])
    )
    let prefixedEnvProvider = KeyMappingProvider(upstream: envProvider) { key in
      key.prepending(["rss", "debrider"])
    }
    providers.append(prefixedEnvProvider)

    self.reader = ConfigReader(providers: providers)
  }

  // MARK: - Configuration Keys

  private enum Keys {
    static let apiKey: ConfigKey = "apiKey"
    static let synologyHostname: ConfigKey = "synology.hostname"
    static let synologyPort: ConfigKey = "synology.port"
    static let synologyUsername: ConfigKey = "synology.username"
    static let synologyPassword: ConfigKey = "synology.password"
    static let onePasswordItemID: ConfigKey = "1pw.id"
    static let historyFile: ConfigKey = "historyFile"
    static let debug: ConfigKey = "debug"
  }
}

// MARK: - CLI Overrides

extension AppConfiguration {

  /// Command-line argument overrides that take priority over environment variables.
  struct CLIOverrides: Sendable {
    var apiKey: String?
    var synologyHostname: String?
    var synologyPort: Int?
    var synologyUsername: String?
    var synologyPassword: String?
    var onePasswordItemID: String?
    var historyFile: String?
    var debug: Bool?

    init(
      apiKey: String? = nil,
      synologyHostname: String? = nil,
      synologyPort: Int? = nil,
      synologyUsername: String? = nil,
      synologyPassword: String? = nil,
      onePasswordItemID: String? = nil,
      historyFile: String? = nil,
      debug: Bool? = nil
    ) {
      self.apiKey = apiKey
      self.synologyHostname = synologyHostname
      self.synologyPort = synologyPort
      self.synologyUsername = synologyUsername
      self.synologyPassword = synologyPassword
      self.onePasswordItemID = onePasswordItemID
      self.historyFile = historyFile
      self.debug = debug
    }

    fileprivate func asConfigValues() -> [AbsoluteConfigKey: ConfigValue] {
      var values: [AbsoluteConfigKey: ConfigValue] = [:]

      if let apiKey {
        values["apiKey"] = ConfigValue(.string(apiKey), isSecret: true)
      }
      if let synologyHostname {
        values["synology.hostname"] = ConfigValue(.string(synologyHostname), isSecret: false)
      }
      if let synologyPort {
        values["synology.port"] = ConfigValue(.int(synologyPort), isSecret: false)
      }
      if let synologyUsername {
        values["synology.username"] = ConfigValue(.string(synologyUsername), isSecret: false)
      }
      if let synologyPassword {
        values["synology.password"] = ConfigValue(.string(synologyPassword), isSecret: true)
      }
      if let onePasswordItemID {
        values["1pw.id"] = ConfigValue(.string(onePasswordItemID), isSecret: false)
      }
      if let historyFile {
        values["historyFile"] = ConfigValue(.string(historyFile), isSecret: false)
      }
      if let debug {
        values["debug"] = ConfigValue(.bool(debug), isSecret: false)
      }

      return values
    }
  }
}
