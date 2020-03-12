local { getLocalizedShortcutName } = require("scripts/controls/controlsVisual.nut")

class ::Input.NullInput extends ::Input.InputBase
{
  showPlaceholder = false

  function getMarkup()
  {
    return showPlaceholder ? "textareaNoTab { text:t='{0}' }".subst(getText()) : null
  }

  function getText()
  {
    return (showPlaceholder && shortcutId != "")
      ? getLocalizedShortcutName(shortcutId)
      : ""
  }

  function getConfig()
  {
    return {
      inputName = "nullInput"
      shortcutId = shortcutId
      showPlaceholder = showPlaceholder
    }
  }
}
