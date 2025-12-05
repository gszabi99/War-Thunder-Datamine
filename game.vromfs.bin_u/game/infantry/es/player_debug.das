options no_aot

require ecs
require net
require DagorConsole
require %appGame.infantry.es.hero_common

require %appGame.wt_events


[console_cmd(name="player.kill")]
def player_kill_cmd()
  sendEvent(get_controlled_hero_eid(), CmdRequestSuicide())

[console_cmd(name="player.suicide")]
def player_suicide_cmd()
  sendEvent(get_controlled_hero_eid(), CmdRequestSuicide())
