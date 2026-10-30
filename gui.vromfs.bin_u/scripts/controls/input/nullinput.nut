from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/controls/controlsVisual.nut" import getLocalizedShortcutName
from "%scripts/controls/input/inputBase.nut" import InputBase
from "%scripts/dagui_library.nut" import *

let NullInput = class (InputBase) {
  showPlaceholder = false

  constructor(shortcutId, showPlaceholder) {
    this.shortcutId = shortcutId
    this.showPlaceholder = showPlaceholder
  }

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
return freeze({NullInput})