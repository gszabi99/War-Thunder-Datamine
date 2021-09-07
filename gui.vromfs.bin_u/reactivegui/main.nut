// Put to global namespace for compatibility
::getroottable().__update(require("daRg"))
require("scripts/ui_globals.nut")
require("sqStdLibs/helpers/backCompatibility.nut")
require("reactiveGui/compatibility.nut")
require("reactiveGui/library.nut")
require("scripts/sqModuleHelpers.nut")
require("scripts/sharedEnums.nut")
local functools = require("%sqstd/functools.nut")
local darg_library = require("%darg/darg_library.nut")
local {Computed, Watched, set_nested_observable_debug} = require("frp")

local {tostring_r} = require("%sqstd/string.nut")
local logLib = require("%sqstd/log.nut")
getroottable().__update(require("daRg"))

set_nested_observable_debug(true)

local tostringfuncTbl = [
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
]

local log = logLib(tostringfuncTbl)

//frp
::Watched <- Watched //warning disable: -ident-hides-ident
::Computed <- Computed //warning disable: -ident-hides-ident

//darg helpers
::hdpx <- darg_library.hdpx
::wrap <- darg_library.wrap

//function tools
::kwarg <- functools.kwarg

//logging
::dlog <- log.dlog
::log <- log  //warning disable: -ident-hides-ident

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

local widgets = require("reactiveGui/widgets.nut")

return {
  children = [
    widgets
  ]
}
