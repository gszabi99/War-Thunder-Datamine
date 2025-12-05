require ecs
require net
require WTInput
require %game.input.input_events

require %appGame.wt_events


[es(tag=input, REQUIRE=hero, after=human_input_es)]
def toogle_laser_input_use_action_triggered(evt : EventOnKeyDown;
                                            eid : EntityId;
                                            input__enabled : bool = true;
                                            human_weap__currentGunSlot : int)
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_LASER_TOGGLE)
    send_net_event(eid, LaserToggle(slotId = human_weap__currentGunSlot))

[es(tag=input, REQUIRE=hero, after=human_input_es)]
def toogle_flash_light_input_use_action_triggered(evt : EventOnKeyDown;
                                                  eid : EntityId;
                                                  input__enabled : bool = true;
                                                  human_weap__currentGunSlot : int)
  if input__enabled && evt.eventId == int(ShortcutEventId.ID_HUMAN_FLASH_LIGHT_TOGGLE)
    send_net_event(eid, FlashLightToggle(slotId = human_weap__currentGunSlot))
