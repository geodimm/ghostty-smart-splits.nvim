on run argv
    if (count of argv) is not 2 then error "Expected a terminal ID and a Ghostty action"
    set terminalID to item 1 of argv
    set actionName to item 2 of argv
    tell application "Ghostty"
        set targetTerminal to first terminal whose id is terminalID
        return perform action actionName on targetTerminal
    end tell
end run
