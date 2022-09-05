options no_aot = true//since this is merely loader
require ecs
require app
require %dasGameLibs.ecs.fs
require %danetlibs.route_prober.route_prober_init
require DagorSystem

[init]
def load
  var ok = true

  if !is_in_aot() && get_DAGOR_ADDRESS_SANITIZER() == 0 && typeinfo(builtin_module_exists network) && typeinfo(builtin_module_exists debugapi)
    ok = load_optional_folder("%gameDev/debugger") && ok

  ok = load_folder("%game") && ok
  ok = load_optional_folder("%gameDev/game") && ok
  ok = load_route_prober("%danetlibs/route_prober") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")