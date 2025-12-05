require ecs

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.squad_behaviour_command_common
require %appGame.infantry.es.squad_order_grenade_common
require %appGame.infantry.es.squad_order_combat_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

def squad_order_response(squad_eid : EntityId; leader_eid : EntityId)
  query() <| $ [es(REQUIRE=squad_member)] (eid : EntityId; squad_member__squad : EntityId)
    if squad_member__squad == squad_eid && eid != leader_eid
      request_squad_member_response_delayed(eid)

























[es(tag=server)]
def squad_order_es(
                   evt : RequestSquadOrder;
                   eid : EntityId;
                   
                   var squad__orderType : int&;
                   var squad__orderPosition : float3&;
                   var squad__orderUseEntity : EntityId&)
  if evt.orderType == SquadOrder.ESO_AUTO_THROW_FRAG_GRENADE
    squad_order_throw_grenade_execute(eid, "fougasse", int(SquadMateOrder.ESMO_THROW_FRAG_GRENADE), evt.orderPosition, evt.orderDirection, evt.orderAltPosition)
    return
  if evt.orderType == SquadOrder.ESO_AUTO_THROW_SMOKE_GRENADE
    squad_order_throw_grenade_execute(eid, "smoke", int(SquadMateOrder.ESMO_THROW_SMOKE_GRENADE), evt.orderPosition, evt.orderDirection, evt.orderAltPosition)
    return
  if evt.orderType == SquadOrder.ESO_AUTO_THROW_FLASH_GRENADE
    squad_order_throw_grenade_execute(eid, "flash", int(SquadMateOrder.ESMO_THROW_FLASH_GRENADE), evt.orderPosition, evt.orderDirection, evt.orderAltPosition)
    return
  if evt.orderType == SquadOrder.ESO_AUTO_ATTACK_VEHICLE
    squad_order_attack_vehicle_execute(eid, evt.orderUseEntity)
    return

  squad__orderType = int(evt.orderType)
  squad__orderPosition = evt.orderPosition
  squad__orderUseEntity = evt.orderUseEntity

  
  

  reset_squad_behaviour_exclude_personal(eid)





























