-- Compatibility alias: both names share one module instance.
vim.notify_once(
  "ghostty-smart-splits: require('ghostty_smart_splits') is deprecated; use require('ghostty-smart-splits') instead",
  vim.log.levels.WARN
)
return require('ghostty-smart-splits')
