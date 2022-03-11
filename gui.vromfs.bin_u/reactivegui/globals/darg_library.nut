// Put to global namespace for compatibility
require("globalScripts/ui_globals.nut")
require("sqStdLibs/helpers/backCompatibility.nut")
require("reactiveGui/compatibility.nut")
require("reactiveGui/library.nut")
require("globalScripts/sqModuleHelpers.nut")
require("globalScripts/sharedEnums.nut")
let functools = require("%sqstd/functools.nut")
let darg_library = require("%darg/darg_library.nut")
let {Computed, Watched, set_nested_observable_debug} = require("frp")

let {tostring_r} = require("%sqstd/string.nut")
let logLib = require("%sqstd/log.nut")
getroottable().__update(require("daRg"))

set_nested_observable_debug(true)

let tostringfuncTbl = [
  {
    compare = @(val) val instanceof Watched
    tostring = @(val) "Watched: {0}".subst(tostring_r(val.value,{maxdeeplevel = 3, splitlines=false}))
  }
]

let log = logLib(tostringfuncTbl)

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
::log <- log  //warning disable: -ident-hides-ident

::math <- require("math")
::string <- require("string")
