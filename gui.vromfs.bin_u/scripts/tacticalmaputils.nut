from "%scripts/dagui_library.nut" import *
let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

function fillSwitchMapTypeBtn(btnContainer, handler) {
  let shortcutName = "ID_SWITCH_TACTICAL_MAP_TYPE"
  let shType = g_shortcut_type.getShortcutTypeByShortcutId(shortcutName)
  let view = {
    accessKey = shType.getGuiAccessKeys(shortcutName)
    shortcut = "".concat("{{", shortcutName, "}}")
    isConsoleButton = showConsoleButtons.get()
  }
  let data = handyman.renderCached("%gui/respawn/tacticalMapHudBtn.tpl", view)
  btnContainer.getScene().replaceContentFromText(btnContainer, data, data.len(), handler)
}

return {
  fillSwitchMapTypeBtn
}