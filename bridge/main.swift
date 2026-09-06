import Carbon
import Darwin
import Foundation

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

private let focusedTerminalScript = """
on focusedTerminalID()
    tell application "Ghostty"
        return id of focused terminal of selected tab of front window
    end tell
end focusedTerminalID
"""

private let performActionScript = """
on performAction(terminalIdentifier, actionIdentifier)
    tell application "Ghostty"
        set targetTerminal to first terminal whose id is terminalIdentifier
        return perform action actionIdentifier on targetTerminal
    end tell
end performAction
"""

private enum BridgeError: LocalizedError {
    case invalidRequest
    case appleScript(String)
    case missingResult

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Invalid bridge request"
        case let .appleScript(message):
            message
        case .missingResult:
            "AppleScript returned no result"
        }
    }
}

private func makeHandlerEvent(handler: String, arguments: [String]) -> NSAppleEventDescriptor {
    let event = NSAppleEventDescriptor(
        eventClass: AEEventClass(kASAppleScriptSuite),
        eventID: AEEventID(kASSubroutineEvent),
        targetDescriptor: nil,
        returnID: AEReturnID(kAutoGenerateReturnID),
        transactionID: AETransactionID(kAnyTransactionID)
    )
    event.setDescriptor(
        NSAppleEventDescriptor(string: handler),
        forKeyword: AEKeyword(keyASSubroutineName)
    )

    let argumentList = NSAppleEventDescriptor(listDescriptor: ())
    for argument in arguments {
        // Index zero appends to an Apple Event list.
        argumentList.insert(NSAppleEventDescriptor(string: argument), at: 0)
    }
    event.setDescriptor(argumentList, forKeyword: AEKeyword(keyDirectObject))
    return event
}

private func execute(_ script: NSAppleScript, handler: String, arguments: [String]) throws -> String {
    var error: NSDictionary?
    let result = script.executeAppleEvent(
        makeHandlerEvent(handler: handler, arguments: arguments),
        error: &error
    )
        as NSAppleEventDescriptor?
    guard let result else {
        throw BridgeError.appleScript(error?.description ?? "AppleScript execution failed")
    }
    if let scriptError = error {
        throw BridgeError.appleScript(scriptError.description)
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

guard let focusedTerminalScript = NSAppleScript(source: focusedTerminalScript),
      let performActionScript = NSAppleScript(source: performActionScript)
else {
    fputs("ghostty-smart-splits-bridge: failed to compile AppleScript\n", stderr)
    exit(EXIT_FAILURE)
}

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
            result = try execute(focusedTerminalScript, handler: "focusedTerminalID", arguments: [])
        case "perform":
            guard let terminalID = request.terminalID, let action = request.action else {
                throw BridgeError.invalidRequest
            }
            result = try execute(
                performActionScript,
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
