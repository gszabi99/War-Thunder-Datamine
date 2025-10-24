options no_aot = true
require %game.events
require ecs
require app
require DagorSystem
require DagorFindFiles

require %appGame.wt_events





[init]
def load
  var ok = true
  if is_in_aot() || (get_DAGOR_DBGLEVEL() > 0 && find_index(get_command_line_arguments(), "--das-no-linter") == -1)
    ok = load_das_linter("%game/linter/linter.das") && ok
  
  find_files_in_folder("%gameDev", "_events.das") <| $(files)
    for file in files
      ok = load_das(file) && ok
  if is_in_aot()
    assert(ok)
