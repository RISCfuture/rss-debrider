import Foundation

extension URLComponents {
  /// Characters allowed in form-urlencoded values (RFC 3986 unreserved characters).
  /// This excludes &, =, +, and other special characters that have meaning in form encoding.
  private static let formURLEncodedAllowed: CharacterSet = {
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-._~")
    return allowed
  }()

  /// Sets the query string from a dictionary using proper form-urlencoded encoding.
  /// Unlike `queryItems`, this correctly encodes `&` and `=` characters in values.
  mutating func setFormEncodedQueryItems(_ parameters: [String: String]) {
    let formEncodedPairs = parameters.map { key, value -> String in
      let encodedKey =
        key.addingPercentEncoding(withAllowedCharacters: Self.formURLEncodedAllowed)
        ?? key
      let encodedValue =
        value.addingPercentEncoding(withAllowedCharacters: Self.formURLEncodedAllowed)
        ?? value
      return "\(encodedKey)=\(encodedValue)"
    }
    percentEncodedQuery = formEncodedPairs.joined(separator: "&")
  }
}
