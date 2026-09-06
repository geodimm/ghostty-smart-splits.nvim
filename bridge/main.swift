import Carbon
import Darwin
import Foundation
import OSAKit

private struct Request: Decodable {
    let command: String
    let terminalID: String?
    let action: String?
}

private struct Response: Encodable {
    let ok: Bool
    let result: String?
    let error: String?

    static func success(_ result: String) -> Response {
        Response(ok: true, result: result, error: nil)
    }

    static func failure(_ error: String) -> Response {
        Response(ok: false, result: nil, error: error)
    }
}

private enum BridgeError: LocalizedError {
    case invalidRequest
    case automation(String)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Invalid bridge request"
        case let .automation(message):
            message
        case .missingResult:
            "Ghostty automation returned no result"
        }
    }
}

private func execute(_ script: OSAScript, handler: String, arguments: [String]) throws -> String {
    var error: NSDictionary?
    let result = script.executeHandler(withName: handler, arguments: arguments, error: &error)
    guard let result else {
        throw BridgeError.automation(error?.description ?? "Ghostty automation failed")
    }
    if let scriptError = error {
        throw BridgeError.automation(scriptError.description)
    }

    if result.descriptorType == typeBoolean {
        return result.booleanValue ? "true" : "false"
    }
    guard let value = result.stringValue else {
        throw BridgeError.missingResult
    }
    return value
}

private func write(_ response: Response) {
    do {
        var data = try JSONEncoder().encode(response)
        data.append(0x0a)
        FileHandle.standardOutput.write(data)
    } catch {
        fputs("ghostty-smart-splits-bridge: failed to encode response\n", stderr)
    }
}

// The CLI and bridge share the same implementation and owning-process lookup.
let scriptURL = URL(fileURLWithPath: CommandLine.arguments[0])
    .deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("scripts/ghostty.js")
guard let source = try? String(contentsOf: scriptURL, encoding: .utf8),
      let language = OSALanguage(forName: "JavaScript")
else {
    fputs("ghostty-smart-splits-bridge: could not load scripts/ghostty.js\n", stderr)
    exit(EXIT_FAILURE)
}
let script = OSAScript(source: source, language: language)

let decoder = JSONDecoder()
while let line = readLine(strippingNewline: true) {
    guard let data = line.data(using: .utf8),
          let request = try? decoder.decode(Request.self, from: data)
    else {
        write(.failure(BridgeError.invalidRequest.localizedDescription))
        continue
    }

    do {
        let result: String
        switch request.command {
        case "focused-terminal-id":
            result = try execute(script, handler: "focusedTerminalID", arguments: [])
        case "perform":
            guard let terminalID = request.terminalID, let action = request.action else {
                throw BridgeError.invalidRequest
            }
            result = try execute(
                script,
                handler: "performAction",
                arguments: [terminalID, action]
            )
        default:
            throw BridgeError.invalidRequest
        }
        write(.success(result.trimmingCharacters(in: .whitespacesAndNewlines)))
    } catch {
        write(.failure(error.localizedDescription))
    }
}
