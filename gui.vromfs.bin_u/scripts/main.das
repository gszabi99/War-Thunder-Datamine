options no_aot = true//since this is merely loader
require ecs
require %dasGameLibs.ecs.fs
require DagorSystem

[init]
def load
  var ok = true
  ok = load_folder("%wt/game") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")