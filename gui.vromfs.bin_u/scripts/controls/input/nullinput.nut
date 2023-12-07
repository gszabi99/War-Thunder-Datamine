//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")

let { getLocalizedShortcutName } = require("%scripts/controls/controlsVisual.nut")

::Input.NullInput <- class (::Input.InputBase) {
  showPlaceholder = false

  function getMarkup() {
    return this.showPlaceholder
      ? handyman.renderCached("%gui/controls/input/nullInput.tpl", { text = this.getText() })
      : null
  }

  function getText() {
    return (this.showPlaceholder && this.shortcutId != "")
      ? getLocalizedShortcutName(this.shortcutId)
      : ""
  }

  function getConfig() {
    return {
      inputName = "nullInput"
      shortcutId = this.shortcutId
      showPlaceholder = this.showPlaceholder
    }
  }
}
