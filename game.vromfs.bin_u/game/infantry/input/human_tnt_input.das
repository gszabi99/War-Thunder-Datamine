require ecs
require app
require WTInput
require %game.input.input_events
require %appGame.infantry.es.tnt_common


[es(tag=input, REQUIRE=hero)]
def human_tnt_input_action_triggered_es(evt : EventOnKeyDown;
                                        eid aka human_eid : EntityId;
                                        human_weap__currentGunEid : EntityId;
                                        input__enabled : bool = true)
  if !input__enabled
    return
  query(human_weap__currentGunEid) <| $ [es(REQUIRE=(tnt_exploder, tnt_launcher))] (throwable_launcher__itemsCount : int;
                                                                                    throwable_launcher__inProgress : bool;
                                                                                    tnt_exploder__inProgress : bool)
    if evt.eventId == int(ShortcutEventId.ID_HUMAN_THROW_TNT)
      tnt_exploder_with_launcher_throw_tnt(human_eid, human_weap__currentGunEid, get_sync_time(), throwable_launcher__itemsCount, throwable_launcher__inProgress, tnt_exploder__inProgress)
