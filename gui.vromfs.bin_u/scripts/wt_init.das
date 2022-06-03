options no_aot = true//since this is merely loader
require %game.events
require ecs
require app
require DagorSystem

[init]
def load
  var ok = true
  if app::get_game_name() == "aot" || get_DAGOR_DBGLEVEL() > 0
    ok = load_das("%game/linter/linter.das") && ok
  if app::get_game_name() == "aot"
    assert(ok)
