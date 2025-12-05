require ecs
require WTInput
require %game.input.input_events

require %appGame.wt_events

[es(tag=input, REQUIRE=controlledHero)]
def human_inventory_input_medkit_terminated_es(evt : EventOnKeyUp;
                                               eid : EntityId;
                                               heal__continuousInput : bool)
  if int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_USE_MEDKIT) && heal__continuousInput
    sendEvent(eid, CmdMedkitUseCancel())






