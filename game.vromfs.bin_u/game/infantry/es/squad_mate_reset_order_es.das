require ecs
require DngWalkerai
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.battle_area_common
require %appGame.infantry.es.team_common
require %appGame.squad_order_enums
require math.base
require net

require %appGame.infantry.es.squad_order_common

[es(tag=server, no_order, REQUIRE_NOT=deadEntity)]
def squadmate_reset_personal_order_far_away_es(act : UpdateStageInfoAct;
                                               eid : EntityId;
                                               transform : float3x4;
                                               squad_member__squad : EntityId;
                                               squad_member__orderType : int;
                                               squad_member__orderPosition : float3;
                                               squad_member__orderUseEntity : EntityId;
                                               squad_member__isPersonalOrder : bool)
  if !squad_member__isPersonalOrder
    return
  if !is_squad_mate_order_cancelled_when_too_far(squad_member__orderType)
    return
  if squad_member__orderType == int(SquadMateOrder.ESMO_DEFEND_POINT) && squad_member__orderUseEntity != INVALID_ENTITY_ID 
    return
  query(squad_member__squad) <| $ [es] (squad__leader : EntityId; squad__maxOrderDistance : float)
    if eid == squad__leader
      return

    let memberTm = transform
    query(squad__leader) <| $ [es] (transform : float3x4)
      let leaderTM = transform
      let maxOrderDistSq = square(squad__maxOrderDistance)
      let distSqFromOrderPosToLeader = distance_sq(squad_member__orderPosition, leaderTM[3])
      let distSqFromMemberToLeader = distance_sq(memberTm[3], leaderTM[3])

      if distSqFromOrderPosToLeader >= maxOrderDistSq && distSqFromMemberToLeader >= maxOrderDistSq
        send_net_event(squad__leader, CmdHeroLogEvent(event = "squad_order_canceled", text = "personal_context_command_canceled/too_far"))
        reset_squad_mate_order(eid)
        reset_squad_mate_behaviour(eid)
        


[es(tag=server)]
def squadmate_reset_personal_order_on_battlearea_deactivation_es(evt : EventBattleAreaStatusChanged)
  if evt.active
    return

  query() <| $ [es] (eid : EntityId;
                     team : int = TEAM_UNASSIGNED;
                     squad_member__orderType : int;
                     squad_member__orderPosition : float3;
                     squad_member__orderUseEntity : EntityId;
                     squad_member__isPersonalOrder : bool)
    if !squad_member__isPersonalOrder
      return
    if squad_member__orderType != int(SquadMateOrder.ESMO_DEFEND_POINT) && squad_member__orderType != int(SquadMateOrder.ESMO_USE_VEHICLE)
      return
    if squad_member__orderType == int(SquadMateOrder.ESMO_DEFEND_POINT) && squad_member__orderUseEntity != INVALID_ENTITY_ID 
      return
    if !has_active_human_battle_area_at(squad_member__orderPosition, team)
      reset_squad_mate_order(eid)
      reset_squad_mate_behaviour(eid)
      

[es(tag=server, REQUIRE=capzone, track=active)]
def squadmate_reset_personal_order_on_capzone_deactivation_es(evt : Event; eid aka zone_eid : EntityId; active : bool)
  if active
    return

  query() <| $ [es] (eid : EntityId;
                     squad_member__orderType : int;
                     squad_member__orderUseEntity : EntityId;
                     squad_member__isPersonalOrder : bool)
    if !squad_member__isPersonalOrder
      return
    if squad_member__orderType != int(SquadMateOrder.ESMO_DEFEND_POINT)
      return
    if squad_member__orderUseEntity != zone_eid
      return
    
    reset_squad_mate_order(eid)
    reset_squad_mate_behaviour(eid)
