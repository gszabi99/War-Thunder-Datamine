require ecs

require %appGame.wt_events
require DagorDataBlock
require hud


[es(tag=gameClient, REQUIRE=hero)]
def hero_log_es(evt : CmdHeroLogEvent)
  using() <| $(var eventData : DataBlock)
    hud_notify_script("hint:{evt.text}", eventData)
