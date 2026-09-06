-- smart-splits v2 loads this adapter when multiplexer_integration = 'ghostty'.
local ghostty = require('ghostty-smart-splits.ghostty')
local M = {
  type = 'ghostty',
  is_in_session = ghostty.detect,
  current_pane_id = ghostty.focused_terminal_id,
  next_pane = ghostty.move,
  resize_pane = ghostty.resize,
  split_pane = ghostty.split,
  -- Preserve the helpers exposed by the original module.
  attach = ghostty.attach,
  perform = ghostty.perform,
}

function M.current_pane_at_edge()
  return false
end

function M.current_pane_is_zoomed()
  return false
end

function M.update_mux_layout_details() end

return M
