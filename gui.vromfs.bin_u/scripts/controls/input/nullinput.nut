from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { getLocalizedShortcutName } = require("%scripts/controls/controlsVisual.nut")

::Input.NullInput <- class extends ::Input.InputBase
{
  showPlaceholder = false

  function getMarkup()
  {
    return this.showPlaceholder
      ? ::handyman.renderCached("%gui/controls/input/nullInput", { text = this.getText() })
      : null
  }

  function getText()
  {
    return (this.showPlaceholder && this.shortcutId != "")
      ? getLocalizedShortcutName(this.shortcutId)
      : ""
  }

  function getConfig()
  {
    return {
      inputName = "nullInput"
      shortcutId = this.shortcutId
      showPlaceholder = this.showPlaceholder
    }
  }
}
