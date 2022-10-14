#explicit-this
#no-root-fallback
let {require_native} = require("%globalScripts/sqModuleHelpers.nut")
local { activateShortcut, setAxisValue, setVirtualAxisValue, changeCruiseControl } = require_native("controls")

local toggleShortcut = @(shortcutName) activateShortcut(shortcutName, true, true)

local setShortcutOn = @(shortcutName) activateShortcut(shortcutName, true, false)

local setShortcutOff = @(shortcutName) activateShortcut(shortcutName, false, false)

return {
  toggleShortcut
  setShortcutOn
  setShortcutOff
  setAxisValue
  setVirtualAxisValue
  changeCruiseControl
}
