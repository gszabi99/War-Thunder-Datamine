let { getLocalizedShortcutName } = require("%scripts/controls/controlsVisual.nut")

::Input.NullInput <- class extends ::Input.InputBase
{
  showPlaceholder = false

  function getMarkup()
  {
    return showPlaceholder
      ? ::handyman.renderCached("%gui/controls/input/nullInput", { text = getText() })
      : null
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
