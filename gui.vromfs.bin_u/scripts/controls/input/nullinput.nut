from "%scripts/dagui_library.nut" import *

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getLocalizedShortcutName } = require("%scripts/controls/controlsVisual.nut")
let { InputBase } = require("%scripts/controls/input/inputBase.nut")

let NullInput = class (InputBase) {
  showPlaceholder = false

  function getMarkup(_hasHoldButtonSign = false) {
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
return {NullInput}