
require ecs

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

[es(tag=server)]
def on_personal_squadmate_attack_vehicle_order(evt : RequestPersonalSquadMateOrder;
                                               eid : EntityId;
                                               squad_member__squad : EntityId;
                                               
                                               var squad_member__orderType : int&;
                                               var squad_member__orderPosition : float3&;
                                               var squad_member__orderByDirection : float3&;
                                               var squad_member__orderToPosition : float3&;
                                               var squad_member__orderToDirection : float3&;
                                               var squad_member__orderUseEntity : EntityId&;
                                               var squad_member__isPersonalOrder : bool&)
  if evt.orderType == int(SquadMateOrder ESMO_ATTACK_VEHICLE)
    query(squad_member__squad) <| $ [es, unused_argument(squad__leader)] (squad__leader : EntityId)
      reset_squad_mate_beh_tree(eid)
      duplicate_to_next_squad_mate_order(eid)
      squad_member__orderType = evt.orderType
      squad_member__orderPosition = evt.orderPosition
      squad_member__orderByDirection = evt.orderByDirection
      squad_member__orderToPosition = evt.orderToPosition
      squad_member__orderToDirection = evt.orderToDirection
      squad_member__orderUseEntity = evt.orderUseEntity
      squad_member__isPersonalOrder = true
      request_squad_member_response_fast(eid)
      
