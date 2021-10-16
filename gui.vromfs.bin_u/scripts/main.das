options no_aot = true//since this is merely loader
require ecs
require DagorSystem

[init]
def load
  var ok = true
  ok = load_es("scripts/game/scene_loader.das") && ok
  ok = load_es("scripts/game/unit_loader.das") && ok
  ok = load_es("scripts/game/routing.das") && ok
  ok = load_es("scripts/game/mission.das") && ok
  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")