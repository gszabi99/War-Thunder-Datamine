let shortcutsListModule = require("scripts/controls/shortcutsList/shortcutsList.nut")

let getShortcutById = @(shortcutId) shortcutsListModule?[shortcutId]

return {
  getShortcutById
}
