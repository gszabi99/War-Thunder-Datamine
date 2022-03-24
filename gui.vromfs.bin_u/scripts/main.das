options no_aot = true//since this is merely loader
require ecs
require app
require %dasGameLibs.ecs.fs
require DagorSystem
require DagorConsole

[init]
def load
  if (get_console_model() == ConsoleModel PS4) || (get_console_model() == ConsoleModel PS4_PRO)
    print("switch off smallgrass")
    console_command("smallgrass.grassRender 0")
  var ok = true
  if app::get_game_name() == "aot" || get_DAGOR_DBGLEVEL() > 0
    ok = load_das("%game/linter/linter.das") && ok

  ok = load_folder("%game") && ok
  ok = load_optional_folder("%gameDev/game") && ok

  print("Das scripts are loaded")
  if !ok
    logerr("Das scripts loading failed")