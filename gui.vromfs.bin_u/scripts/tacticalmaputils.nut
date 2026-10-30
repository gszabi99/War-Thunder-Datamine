from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/options/consoleMode.nut" import showConsoleButtons
from "%scripts/dagui_library.nut" import *

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")

function fillSwitchMapTypeBtn(btnContainer, handler) {
  const shortcutName = "ID_SWITCH_TACTICAL_MAP_TYPE"
  let shType = g_shortcut_type.getShortcutTypeByShortcutId(shortcutName)
  let view = {
    accessKey = shType.getGuiAccessKeys(shortcutName)
    shortcut = "".concat("{{", shortcutName, "}}")
    isConsoleButton = showConsoleButtons.get()
  }
  let data = handyman.renderCached("%gui/respawn/tacticalMapHudBtn.tpl", view)
  btnContainer.getScene().replaceContentFromText(btnContainer, data, data.len(), handler)
}

return freeze({
  fillSwitchMapTypeBtn
})