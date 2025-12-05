require ecs
require math
require math.base

require %appGame.wt_events
require %game.player_events
require %appGame.infantry.es.loc_squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.es.walker_common
require DagorDataBlock
require BehNodes


def find_next_member(members : EidList; leader_eid : EntityId)
  let curMemberIdx = get_int(leader_eid, "squad_member__memberIdx") ?? -1
  var foundEid = INVALID_ENTITY_ID
  var foundPriority = 0
  var foundUndowned = false

  for memberEid in members
    if memberEid == leader_eid
      continue
    query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (eid : EntityId;
                                                        isDowned : bool;
                                                        isAlive : bool;
                                                        squad_member__memberIdx : int;
                                                        squad_member__canBeLeader : bool)
      if !isAlive || !squad_member__canBeLeader || (isDowned && foundUndowned)
        return
      let priority = ((squad_member__memberIdx - curMemberIdx + 10000) % 10000)
      if !foundEid || priority < foundPriority || (!isDowned && !foundUndowned)
        foundEid = eid
        foundPriority = priority
        foundUndowned = !isDowned

  return foundEid

def is_valid_squad_member(eid, squad_eid)
  var isValid = false
  query(eid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__canBeLeader : bool; squad_member__squad : EntityId)
    isValid = squad_member__canBeLeader && squad_member__squad == squad_eid
  return isValid

def update_squad_orders_on_leader_change(was_leader : EntityId; new_leader : EntityId)
  if new_leader == was_leader
    return

  query(new_leader) <| $ [es] (transform : float3x4;
                               var squad_member__wasPosWhenBecameLeader : float3&)
    squad_member__wasPosWhenBecameLeader = transform[3]

  query(was_leader) <| $ [es] (squad_member__isPersonalOrder : bool;
                               transform : float3x4;
                               human_net_phys__isCrouch : bool;
                               human_net_phys__isCrawl : bool;
                               var squad_member__followLeader : bool&;
                               var squad_member__followLeaderPos : float3&;
                               var squad_member__followLeaderDir : float3&;
                               var squad_member__followLeaderStance : int&;
                               var squad_member__followLeaderRun : bool&;
                               var squad_member__orderType : int&;
                               var squad_member__orderPosition : float3&;
                               var squad_member__orderByDirection : float3&;
                               squad_member__wasPosWhenBecameLeader : float3;
                               squad_member__newPosOnLeaderChangeDistance : float = 1.5)
    if !squad_member__isPersonalOrder
      squad_member__followLeader = false
      squad_member__followLeaderPos = transform[3]
      squad_member__followLeaderDir = transform[0]
      squad_member__followLeaderStance = STANCE_CROUCH
      squad_member__followLeaderRun = false

      query(was_leader) <| $ [es] (var beh_tree : BehaviourTree&)
        beh_tree.blackBoard |> set("regroupPosition", squad_member__followLeaderPos)
        beh_tree.blackBoard |> set("wishPosition", squad_member__followLeaderPos)

      reset_squad_mate_beh_tree(was_leader)

    if squad_member__isPersonalOrder && is_squad_mate_order_overwatch_by_direction(squad_member__orderType)
      let newPos = transform[3]
      if distance_sq(squad_member__wasPosWhenBecameLeader, newPos) > square(squad_member__newPosOnLeaderChangeDistance)
        squad_member__orderPosition = transform[3]
        squad_member__orderByDirection = transform[0]

        if human_net_phys__isCrawl
          squad_member__orderType = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_PRONE)
        elif human_net_phys__isCrouch
          squad_member__orderType = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_CROUCHED)
        else
          squad_member__orderType = int(SquadMateOrder.ESMO_OVERWATCH_ALONG_STANDING)

        query(was_leader) <| $ [es] (var beh_tree : BehaviourTree&)
          beh_tree.blackBoard |> set("regroupPosition", squad_member__orderPosition)
          beh_tree.blackBoard |> set("wishPosition", squad_member__orderPosition)

        reset_squad_mate_beh_tree(was_leader)


[es(tag=server, after=human_ai_enable_on_switch_to)]
def switch_squad_leader_es(evt : EventPlayerChangeControlTo;
                           eid : EntityId;
                           squad_member__squad : EntityId)
  let newLeaderEid = eid
  query(squad_member__squad) <| $ [es] (var squad__leader : EntityId&)
    let wasLeaderEid = squad__leader
    squad__leader = newLeaderEid
    update_squad_orders_on_leader_change(wasLeaderEid, newLeaderEid)

[es(tag=server, no_order)]
def switch_bot_squad_leader_es(act : UpdateStageInfoAct;
                               eid aka squad_eid : EntityId;
                               squad__allMembers : EidList;
                               squad__ownerPlayer : EntityId;
                               var squad__leader : EntityId&)
  if !has(squad__ownerPlayer, "playerIsBot")
    return
  if is_valid_squad_member(squad__leader, squad_eid)
    return
  
  let newLeaderEid = find_next_member(squad__allMembers, squad__leader)
  if squad__leader != newLeaderEid
    let wasLeaderEid = squad__leader
    squad__leader = newLeaderEid
    update_squad_orders_on_leader_change(wasLeaderEid, newLeaderEid)
