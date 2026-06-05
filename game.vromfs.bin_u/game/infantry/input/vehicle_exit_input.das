require ecs
require ecs.common
require net
require WTInput
require %game.input.input_events
require %game.player_events
require %appGame.wt_events
require %appGame.infantry.es.vehicle.vehicle_events




[es(tag=input, REQUIRE=controlledHero)]
def vehicle_controlled_hero_exit_input_es(evt : EventOnKeyDown;
                                          eid : EntityId;
                                          vehicle_seats__seatEids : EidList)
  if evt.eventId != int(ShortcutEventId.ID_HUMAN_USE)
    return

  
  
  var ownerPlayerEid = INVALID_ENTITY_ID
  var driverSoldierEid = INVALID_ENTITY_ID
  for seatEid in vehicle_seats__seatEids
    if !!ownerPlayerEid
      break
    query(seatEid) <| $ [es] (seat__playerEid : EntityId; seat__ownerEid : EntityId; seatOwnsEntityControl : bool)
      if seatOwnsEntityControl && seat__playerEid != INVALID_ENTITY_ID
        ownerPlayerEid = seat__playerEid
        driverSoldierEid = seat__ownerEid

  if ownerPlayerEid == INVALID_ENTITY_ID
    return

  
  
  if driverSoldierEid != INVALID_ENTITY_ID
    sendEvent(ownerPlayerEid, CmdRequestSwitchControlledUnit(toEid = driverSoldierEid))

  
  for seatEid in vehicle_seats__seatEids
    query(seatEid) <| $ [es] (seat__playerEid : EntityId; seat__ownerEid : EntityId)
      if seat__playerEid == ownerPlayerEid && seat__ownerEid != INVALID_ENTITY_ID
        send_net_event(eid, RequestKickFromVehicle(requester = seat__ownerEid))
