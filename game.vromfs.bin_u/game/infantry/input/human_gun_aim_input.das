require ecs

require %appGame.wt_events
require WTInput
require %game.input.input_events




















[es(tag=input, REQUIRE=hero)]
def human_input_action_triggered_es(evt : EventOnKeyDown;
                                    human_weap__gunEids : EidList;
                                    human_weap__currentGunSlot : int;
                                    input__enabled : bool = true)
  if !input__enabled
    return

  if human_weap__currentGunSlot >= 0
    let weapEid = human_weap__gunEids[human_weap__currentGunSlot]

    if evt.eventId == int(ShortcutEventId.ID_HUMAN_SIGHT_NEXT)
      sendEvent(weapEid, CmdWeapSwitchSight(toNext = true))
    if evt.eventId == int(ShortcutEventId.ID_HUMAN_SIGHT_PREV)
      sendEvent(weapEid, CmdWeapSwitchSight(toNext = false))
