from "%scripts/dagui_library.nut" import *

/** (anti)pattern service locator. We need it to avoid circullar dependecies.
  used for forward declaration.
  The main improvemetn is that you can verify that module can be defined only once
  usage:
    let {getGlobalModule} = require("%scripts/global_modules.nut")
    let g_squad_manager = getGlobalModule("g_squad_manager")
*/

let services = {}
let lateBindings = {}
let requireLateBindings = {}

function registerGlobalModule(name, module=null) {
  assert(type(name=="string"))
  assert(module == null || type(module)=="table" || type(module) == "instance" || type(module) == "class")
  assert(name not in services, $"module {name} already registered")
  services[name] <- module ?? {}
  if (module==null)
    requireLateBindings[name] <- null
}

function lateBindGlobalModule(name, module) {
  assert(type(name=="string"), "lateBindGlobalModule error: name should be string")
  assert(type(module)=="table" || type(module)=="instance" || type(module)=="class",
      "lateBindGlobalModule error: module should be table, class or instance")
  assert(name in services, $"module {name} is not registered")
  assert(name not in lateBindings, $"{name} has been already bound")
  assert(name in requireLateBindings, $"{name} has been already bound")
  assert(type(services[name])=="table")
  services[name].clear()
  services[name].__update(freeze(module))
  lateBindings[name] <- null
}

function getGlobalModule(name) {
  assert(type(name=="string"))
  assert(name in services, $"module {name} is not registered")
  return services[name]
}

return {
  registerGlobalModule
  lateBindGlobalModule
  getGlobalModule
}