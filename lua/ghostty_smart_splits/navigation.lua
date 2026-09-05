-- Find a Neovim neighbor before handing navigation to Ghostty.
local M = {}

local dir_keys = {
  left = 'h',
  right = 'l',
  up = 'k',
  down = 'j',
}

-- Treat low-zindex floats as embedded sidebars, as in the original workaround.
-- This is a heuristic, not a Neovim guarantee about every floating window.
local function is_nav_window(win)
  if not vim.api.nvim_win_is_valid(win) then
    return false
  end
  local cfg = vim.api.nvim_win_get_config(win)
  if cfg.relative == '' then
    return true
  end
  return cfg.zindex ~= nil and cfg.zindex < 50
end

---@param direction 'left'|'right'|'up'|'down'
---@return integer|nil
function M.neighbor_win(direction)
  local key = dir_keys[direction]
  if not key then
    return nil
  end

  local cur = vim.api.nvim_get_current_win()
  local dest_nr = vim.fn.winnr(key)
  if dest_nr ~= vim.fn.winnr() then
    local id = vim.fn.win_getid(dest_nr)
    if id ~= 0 and id ~= cur then
      return id
    end
  end

  local cpos = vim.api.nvim_win_get_position(cur)
  local crow, ccol = cpos[1], cpos[2]
  local cw = vim.api.nvim_win_get_width(cur)
  local ch = vim.api.nvim_win_get_height(cur)
  local cbottom, cright = crow + ch, ccol + cw

  local best, best_dist = nil, math.huge
  for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
    if win ~= cur and is_nav_window(win) then
      local p = vim.api.nvim_win_get_position(win)
      local w = vim.api.nvim_win_get_width(win)
      local h = vim.api.nvim_win_get_height(win)
      local bottom, right = p[1] + h, p[2] + w
      local overlap_v = p[1] < cbottom and crow < bottom
      local overlap_h = p[2] < cright and ccol < right
      local dist
      if direction == 'right' and overlap_v and p[2] >= cright - 1 then
        dist = p[2] - cright
      elseif direction == 'left' and overlap_v and right <= ccol + 1 then
        dist = ccol - right
      elseif direction == 'down' and overlap_h and p[1] >= cbottom - 1 then
        dist = p[1] - cbottom
      elseif direction == 'up' and overlap_h and bottom <= crow + 1 then
        dist = crow - bottom
      end
      if dist and dist < best_dist then
        best, best_dist = win, dist
      end
    end
  end
  return best
end

---Move within Neovim. Return false at an edge so the caller can try Ghostty.
function M.move(direction)
  local win = M.neighbor_win(direction)
  if win then
    if vim.fn.mode() == 't' then
      vim.cmd('stopinsert')
    end
    vim.api.nvim_set_current_win(win)
    return true
  end
  return false
end

return M
