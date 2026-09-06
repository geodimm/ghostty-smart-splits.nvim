-- Only used by the local benchmark, never by the plugin at runtime.
on run argv
  set operation to item 1 of argv
  set terminalID to item 2 of argv
  tell application "Ghostty"
    if operation is "split" then
      set sourceTerminal to first terminal whose id is terminalID
      set createdTerminal to split sourceTerminal direction right
      return id of createdTerminal
    else if operation is "close" then
      set originalID to item 3 of argv
      if terminalID is "" or terminalID is originalID then error "Refusing to close the original terminal"
      set matches to every terminal whose id is terminalID
      if (count of matches) > 0 then close (item 1 of matches)
    else if operation is "focus" then
      focus (first terminal whose id is terminalID)
    else
      error "Unknown benchmark pane operation: " & operation
    end if
  end tell
end run
