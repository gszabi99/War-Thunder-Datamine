// Put to global namespace for compatibility
::getroottable().__update(require("daRg"))
require("daRg/library.nut")
require("sqStdLibs/helpers/backCompatibility.nut")
require("reactiveGui/compatibility.nut")
require("reactiveGui/library.nut")
require("scripts/sqModuleHelpers.nut")
require("scripts/sharedEnums.nut")

::math <- require("math")
::string <- require("string")
::loc <- require("dagor.localize").loc
::utf8 <- require("utf8")
::regexp2 <- require("regexp2")

// configure scene when hosted in game
::gui_scene.config.clickRumbleEnabled = false

require("ctrlsState.nut") //need this for controls mask updated
/*scale px by font size*/
local fontsState = require("style/fontsState.nut")
::fpx <- fontsState.getSizePx //equal @sf/1@pf in gui
::dp <- fontsState.getSizeByDp //equal @dp in gui
::scrn_tgt <- fontsState.getSizeByScrnTgt //equal @scrn_tgt in gui
::shHud <- @(value) min(sh(value),(0.75*sw(value)))

local widgets = require("reactiveGui/widgets.nut")

return {
  children = [
    widgets
  ]
}
