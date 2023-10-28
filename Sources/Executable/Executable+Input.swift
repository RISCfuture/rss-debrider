import Foundation

extension Executable {
    func prompt(_ message: String, default: String?) -> String {
        var input = `default`
        while input == nil {
            print("\(message) ", terminator: "")
            input = readLine(strippingNewline: true)
        }
        return input!
    }
    
    func promptPassword(_ message: String, default: String?) -> String {
        var input = `default`
        while input == nil {
            guard let cInput = getpass(message) else { continue }
            input = String(cString: cInput)
        }
        return input!
    }
}
