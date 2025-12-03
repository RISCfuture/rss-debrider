import Foundation

extension Executable {

  /**
   Prompts the user for input with an optional default value.
  
   If a default value is provided, it is returned immediately without
   prompting. Otherwise, the user is prompted until they provide a non-empty
   value.
  
   - Parameter message: The prompt message to display to the user.
   - Parameter default: An optional default value. If provided, the prompt
     is skipped and this value is returned.
   - Returns: The user's input or the default value.
   */
  func prompt(_ message: String, default: String?) -> String {
    var input = `default`
    while input == nil {
      print("\(message) ", terminator: "")
      input = readLine(strippingNewline: true)
    }
    return input!
  }

  /**
   Prompts the user for a password with an optional default value.
  
   If a default value is provided, it is returned immediately without
   prompting. Otherwise, the user is prompted using `getpass()` which hides
   the input from the terminal.
  
   - Parameter message: The prompt message to display to the user.
   - Parameter default: An optional default value. If provided, the prompt
     is skipped and this value is returned.
   - Returns: The user's password input or the default value.
   */
  func promptPassword(_ message: String, default: String?) -> String {
    var input = `default`
    while input == nil {
      guard let cInput = getpass(message) else { continue }
      input = String(cString: cInput)
    }
    return input!
  }
}
