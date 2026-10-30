require ecs
require hud
require DagorDataBlock
require WTInput
require %game.input.input_events


[es(tag=input, REQUIRE=controlledHero)]
def supply_transport_buy_input_es(evt : EventOnKeyDown;
                                  input__enabled : bool = true;
                                  human_use_object__selectedObject : EntityId)
  let nodeEid = get_Eid(human_use_object__selectedObject, "supply_laptop__nodeEid") ?? INVALID_ENTITY_ID
  if input__enabled && nodeEid != INVALID_ENTITY_ID && evt.eventId == int(ShortcutEventId.ID_HUMAN_USE)
    using() <| $(var eventData : DataBlock)
      set(eventData, "nodeEid", int(uint(nodeEid)))
      set(eventData, "laptopEid", int(uint(human_use_object__selectedObject)))
      hud_notify_script("supply_transport_buy_menu", eventData)
