// Put to global namespace for compatibility
require("frp").set_nested_observable_debug(true)
::getroottable().__update(require("daRg"))
require("scripts/ui_globals.nut")
require("daRg/library.nut")
require("sqStdLibs/helpers/backCompatibility.nut")
require("reactiveGui/compatibility.nut")
require("reactiveGui/library.nut")
require("scripts/sqModuleHelpers.nut")
require("scripts/sharedEnums.nut")
local {editor, editorIsActive} = require("editor.nut")

::math <- require("math")
::string <- require("string")

// configure scene when hosted in game
::gui_scene.config.clickRumbleEnabled = false

require("ctrlsState.nut") //need this for controls mask updated
/*scale px by font size*/
local fontsState = require("style/fontsState.nut")
::fpx <- fontsState.getSizePx //equal @sf/1@pf in gui
::dp <- fontsState.getSizeByDp //equal @dp in gui
::scrn_tgt <- fontsState.getSizeByScrnTgt //equal @scrn_tgt in gui
::shHud <- @(value) min(sh(value),(0.75*sw(value)))

local function root() {
  local children = [
  ]

  if (editorIsActive.value)
    children = [editor]

  return {
    watch = [editorIsActive]
    size = flex()
    children
  }
}

return root
