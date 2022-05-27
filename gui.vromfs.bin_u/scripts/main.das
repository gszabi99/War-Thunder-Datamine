options no_aot = true//since this is merely loader
require ecs
require app
require %dasGameLibs.ecs.fs
require DagorSystem

[init]
def load
  var ok = true

  ok = load_folder("%game") && ok
  ok = load_optional_folder("%gameDev/game") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")