options no_aot = true//since this is merely loader
require ecs
require app
require %dasGameLibs.ecs.fs
require DagorSystem

[init]
def load
  var ok = true
  if app::get_game_name() == "aot" || get_DAGOR_DBGLEVEL() > 0
    ok = load_das("%game/linter/linter.das") && ok

  ok = load_folder("%game") && ok
  ok = load_optional_folder("%gameDev/game") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")