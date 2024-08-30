let { activateShortcut, setAxisValue, setVirtualAxisValue, setVirtualAxesAileronsElevatorValue, setVirtualAxesAim = null, setVirtualAxesAileronsAssist = null, setVirtualAxesDirectControl = null, changeCruiseControl } = require("controls")

local toggleShortcut = @(shortcutName) activateShortcut(shortcutName, true, true)

local setShortcutOn = @(shortcutName) activateShortcut(shortcutName, true, false)

local setShortcutOff = @(shortcutName) activateShortcut(shortcutName, false, false)

return {
  toggleShortcut
  setShortcutOn
  setShortcutOff
  setAxisValue
  setVirtualAxisValue
  setVirtualAxesAileronsElevatorValue
  setVirtualAxesAim
  setVirtualAxesAileronsAssist
  setVirtualAxesDirectControl
  changeCruiseControl
}
