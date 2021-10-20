// Put to global namespace for compatibility
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
