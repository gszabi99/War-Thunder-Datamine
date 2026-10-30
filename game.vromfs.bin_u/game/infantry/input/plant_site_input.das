require ecs
require net
require WTInput
require %game.input.input_events
require %appGame.wt_events


[es(tag=input, REQUIRE=controlledHero)]
def plant_site_input_action_triggered(evt : EventOnKeyDown;
                                      input__enabled : bool = true;
                                      human_use_object__selectedObject : EntityId;
                                      var human_plant_site__usePressed : bool&)
  if !input__enabled || evt.eventId != int(ShortcutEventId.ID_HUMAN_USE)
    return
  if has(human_use_object__selectedObject, "plantSite")
    human_plant_site__usePressed = true


[es(tag=input, REQUIRE=controlledHero)]
def plant_site_input_action_terminated(evt : EventOnKeyUp;
                                       eid : EntityId;
                                       input__enabled : bool = true;
                                       human_plant_site__siteEid : EntityId;
                                       var human_plant_site__usePressed : bool&)
  if !input__enabled || evt.eventId != int(ShortcutEventId.ID_HUMAN_USE)
    return
  if human_plant_site__usePressed || human_plant_site__siteEid != INVALID_ENTITY_ID
    send_net_event(eid, CmdStopInteractPlantSite())
  human_plant_site__usePressed = false
