local shortcutsListModule = require("scripts/controls/shortcutsList/shortcutsList.nut")

local getShortcutById = @(shortcutId) shortcutsListModule?[shortcutId]

return {
  getShortcutById
}
