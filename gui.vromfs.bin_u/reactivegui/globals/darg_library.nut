// Put to global namespace for compatibility
require("%globalScripts/ui_globals.nut")
require("%sqStdLibs/helpers/backCompatibility.nut")
require("%rGui/compatibility.nut")
require("%rGui/library.nut")
require("%globalScripts/sqModuleHelpers.nut")
require("%globalScripts/sharedEnums.nut")
let functools = require("%sqstd/functools.nut")
let darg_library = require("%darg/darg_library.nut")
let {Computed, Watched, set_nested_observable_debug} = require("frp")

let log = require("%globalScripts/logs.nut")
getroottable().__update(require("daRg"))

set_nested_observable_debug(true)

//frp
::Watched <- Watched //warning disable: -ident-hides-ident
::Computed <- Computed //warning disable: -ident-hides-ident

//darg helpers
::hdpx <- darg_library.hdpx
::wrap <- darg_library.wrap
::shHud <- @(value) (darg_library.fsh(value)).tointeger()

//function tools
::kwarg <- functools.kwarg

//logging
::dlog <- log.dlog
::log <- log.log  //warning disable: -ident-hides-ident

::math <- require("math")
::string <- require("string")
