require ecs

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require human_net_speech.modules.human_net_speech_request_common

require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums

[es(tag=server)]
def on_personal_squadmate_defend_order(evt : RequestPersonalSquadMateOrder;
                                       eid : EntityId;
                                       squad_member__squad : EntityId;
                                       
                                       var squad_member__orderType : int&;
                                       var squad_member__orderPosition : float3&;
                                       var squad_member__orderByDirection : float3&;
                                       var squad_member__orderToPosition : float3&;
                                       var squad_member__orderToDirection : float3&;
                                       var squad_member__orderUseEntity : EntityId&;
                                       var squad_member__isPersonalOrder : bool&)
  if evt.orderType == int(SquadMateOrder.ESMO_DEFEND_POINT)
    query(squad_member__squad) <| $ [es, unused_argument(squad__leader)] (squad__leader : EntityId)
      reset_squad_mate_beh_tree(eid)

      squad_member__orderType = int(SquadMateOrder.ESMO_DEFEND_POINT)
      squad_member__orderPosition = evt.orderPosition
      squad_member__orderByDirection = evt.orderByDirection
      squad_member__orderToPosition = evt.orderToPosition
      squad_member__orderToDirection = evt.orderToDirection
      squad_member__orderUseEntity = evt.orderUseEntity
      squad_member__isPersonalOrder = true

      reset_next_squad_mate_order(eid)

      request_squad_member_response_fast(eid)
      

[es(tag=server)]
def squadmate_defend_order_speech(evt : RequestPersonalSquadMateOrder;
                                  eid : EntityId;
                                  squad_member__squad : EntityId)
  if evt.orderType == int(SquadMateOrder.ESMO_DEFEND_POINT)
    query(squad_member__squad) <| $ [es] (squad__leader : EntityId)
      request_net_speech(squad__leader, "squadDefendOrder")
      request_squad_member_response_delayed(eid)
