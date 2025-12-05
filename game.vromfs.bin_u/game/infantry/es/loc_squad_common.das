module loc_squad_common shared
require ecs
require net
require DagorRandom
require DagorDataBlock
require BehNodes

require %appGame.wt_events
require %appGame.infantry.es.walker_common
require %appGame.infantry.es.squad_behaviour_command_common
require %appGame.infantry.ai.covers_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require DngBehTree

variant MaybeOrder
  order : SquadMateOrder
  nothing : void?

struct MemberForOrder
  eid : EntityId
  executeOrder : bool

def reset_squad_mate_ai_components(squad_member_eid : EntityId)
  query(squad_member_eid) <| $ [es] (var beh_tree__capzoneOfInterest : EntityId&)
    beh_tree__capzoneOfInterest = INVALID_ENTITY_ID
  reset_covers(squad_member_eid)

def reload_squad_mate_beh_tree(squad_member_eid : EntityId)
  var was_maxStance = STANCE_STAND
  var was_maxStanceOrder = STANCE_STAND
  var was_maxStanceOrderForce = false
  var was_maxStanceOrderEndTime = 0.0
  var was_maxStanceAtLeast = STANCE_CRAWL
  var was_wishPosition = float3()
  var was_regroupPosition = float3()
  var was_leaderTargetEid = 0

  query(squad_member_eid) <| $ [es] (beh_tree : BehaviourTree)
    was_maxStance             = beh_tree.blackBoard |> datablock_getInt("maxStance", STANCE_STAND)
    was_maxStanceOrder        = beh_tree.blackBoard |> datablock_getInt("maxStanceOrder", STANCE_STAND)
    was_maxStanceOrderForce   = beh_tree.blackBoard |> datablock_getBool("maxStanceOrderForce", false)
    was_maxStanceOrderEndTime = beh_tree.blackBoard |> datablock_getReal("maxStanceOrderEndTime", 0.0)
    was_maxStanceAtLeast      = beh_tree.blackBoard |> datablock_getInt("maxStanceAtLeast", STANCE_CRAWL)
    was_wishPosition          = beh_tree.blackBoard |> datablock_getPoint3("wishPosition", float3())
    was_regroupPosition       = beh_tree.blackBoard |> datablock_getPoint3("regroupPosition", float3())
    was_leaderTargetEid       = beh_tree.blackBoard |> datablock_getInt("leaderTargetEid", 0)

  DngBehTree::load_beh_tree_from_ecs(squad_member_eid)

  query(squad_member_eid) <| $ [es] (var beh_tree : BehaviourTree&;
                                     var beh_tree__latencyLoadBlackBoard : Object?)
    if beh_tree__latencyLoadBlackBoard != null
      *beh_tree__latencyLoadBlackBoard |> set("maxStance", was_maxStance)
      *beh_tree__latencyLoadBlackBoard |> set("maxStanceOrder", was_maxStanceOrder)
      *beh_tree__latencyLoadBlackBoard |> set("maxStanceOrderForce", was_maxStanceOrderForce)
      *beh_tree__latencyLoadBlackBoard |> set("maxStanceOrderEndTime", was_maxStanceOrderEndTime)
      *beh_tree__latencyLoadBlackBoard |> set("maxStanceAtLeast", was_maxStanceAtLeast)
      *beh_tree__latencyLoadBlackBoard |> set("wishPosition", was_wishPosition)
      *beh_tree__latencyLoadBlackBoard |> set("regroupPosition", was_regroupPosition)
      *beh_tree__latencyLoadBlackBoard |> set("leaderTargetEid", was_leaderTargetEid)
    beh_tree.blackBoard |> set("maxStance", was_maxStance)
    beh_tree.blackBoard |> set("maxStanceOrder", was_maxStanceOrder)
    beh_tree.blackBoard |> set("maxStanceOrderForce", was_maxStanceOrderForce)
    beh_tree.blackBoard |> set("maxStanceOrderEndTime", was_maxStanceOrderEndTime)
    beh_tree.blackBoard |> set("maxStanceAtLeast", was_maxStanceAtLeast)
    beh_tree.blackBoard |> set("wishPosition", was_wishPosition)
    beh_tree.blackBoard |> set("regroupPosition", was_regroupPosition)
    beh_tree.blackBoard |> set("leaderTargetEid", was_leaderTargetEid)

def reset_squad_mate_beh_tree(squad_member_eid : EntityId)
  query(squad_member_eid) <| $ [es] (var beh_tree : BehaviourTree&)
    beh_tree_reset(beh_tree)


def reset_squad_mate_behaviour(squad_member_eid : EntityId;
                               new_behaviour : string;
                               var behaviour : das_string&)
  reset_squad_mate_ai_components(squad_member_eid)

  behaviour := new_behaviour
  reset_squad_mate_beh_tree(squad_member_eid)

def reset_squad_mate_behaviour(squad_member_eid : EntityId)
  query(squad_member_eid) <| $ [es] (squad_member__squad : EntityId;
                                     var beh_tree__refs__behaviour : das_string&)
    query(squad_member__squad) <| $ [es] (squad__squadBehaviour : int;
                                          squad__ownerPlayer : EntityId;
                                          squad__orderType : int)
      var formationSpread = int(SquadFormationSpread.ESFN_CLOSEST)
      query(squad__ownerPlayer) <| $ [es] (squadFormationSpread : int)
        formationSpread = squadFormationSpread

      if squad__orderType == int(SquadOrder.ESO_FOLLOW_ME)
        if formationSpread == int(SquadFormationSpread.ESFN_CLOSEST)
          beh_tree__refs__behaviour := "dummy"
        elif formationSpread == int(SquadFormationSpread.ESFN_STANDARD)
          beh_tree__refs__behaviour := "dummy"
        else
          beh_tree__refs__behaviour := "dummy"

        if squad__squadBehaviour == int(SquadBehaviour.ESB_AGGRESSIVE)
          reset_squad_mate_behaviour(squad_member_eid, "dummy", beh_tree__refs__behaviour)

def reset_squad_behaviour(squad_eid : EntityId)
  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    for squadMemberEid in squad__allMembers
      reset_squad_mate_behaviour(squadMemberEid)

def reset_squad_behaviour_exclude_personal(squad_eid : EntityId)
  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    for squadMemberEid in squad__allMembers
      query(squadMemberEid) <| $ [es] (squad_member__isPersonalOrder : bool)
        if !squad_member__isPersonalOrder
          reset_squad_mate_behaviour(squadMemberEid)

def request_squad_member_response(member_eid : EntityId; phrase : string; delay_min, delay_max : float)
  query(member_eid) <| $ [es] (var squad_member__responseTimer : float&; var squad_member__response : das_string)
    squad_member__responseTimer = rnd_float(delay_min, delay_max)
    squad_member__response := phrase

def request_squad_member_response_fast(member_eid : EntityId; phrase = "confirmResponse")
  request_squad_member_response(member_eid, phrase, 0.1, 0.3)

def request_squad_member_response_delayed(member_eid : EntityId; phrase = "confirmResponse")
  request_squad_member_response(member_eid, phrase, 2.5, 3.5)

def reset_squad_order(var squad__orderType : int&; var squad__orderUseEntity : EntityId&)
  squad__orderUseEntity = INVALID_ENTITY_ID
  squad__orderType = int(SquadOrder.ESO_FOLLOW_ME)

def reset_squad_order(squad_eid : EntityId)
  query(squad_eid) <| $ [es] (var squad__orderType : int&;
                              var squad__orderUseEntity : EntityId&)
    reset_squad_order(squad__orderType,
                      squad__orderUseEntity)

def collect_squad(squad_eid, squad__leader : EntityId; callback : block<(eid : EntityId) : bool>) : bool
  return find_query() <| $ [es(REQUIRE=walker_agent)] (eid : EntityId; squad_member__squad : EntityId; isAlive : bool)
    if isAlive && squad_eid == squad_member__squad && eid != squad__leader
      return invoke(callback, eid)
    return false

def collect_squad_ai(squad_eid, squad__leader : EntityId; callback : block<(var tree : BehaviourTree) : bool>) : bool
  return find_query() <| $ [es] (eid : EntityId; squad_member__squad : EntityId; isAlive : bool; var beh_tree : BehaviourTree&)
    if isAlive && squad_eid == squad_member__squad && eid != squad__leader
      return invoke(callback, beh_tree)
    return false

def reset_next_squad_mate_order(squad_mate_eid : EntityId)
  query(squad_mate_eid) <| $ [es] (var squad_member__nextOrderType : int&;
                                   var squad_member__nextOrderPosition : float3&;
                                   var squad_member__nextOrderByDirection : float3&;
                                   var squad_member__nextOrderToPosition : float3&;
                                   var squad_member__nextOrderToDirection : float3&;
                                   var squad_member__nextOrderUseEntity : EntityId&;
                                   var squad_member__nextPersonalOrder : bool&)
    squad_member__nextOrderType = int(SquadMateOrder.ESMO_NO_ORDER)
    squad_member__nextOrderPosition = float3()
    squad_member__nextOrderByDirection = float3()
    squad_member__nextOrderToPosition  = float3()
    squad_member__nextOrderToDirection = float3()
    squad_member__nextOrderUseEntity = INVALID_ENTITY_ID
    squad_member__nextPersonalOrder = false

def duplicate_to_next_squad_mate_order(squad_mate_eid : EntityId)
  query(squad_mate_eid) <| $ [es] (squad_member__orderType : int;
                                   squad_member__orderPosition : float3;
                                   squad_member__orderByDirection : float3;
                                   squad_member__orderToPosition : float3;
                                   squad_member__orderToDirection : float3;
                                   squad_member__orderUseEntity : EntityId;
                                   squad_member__isPersonalOrder : bool;
                                   var squad_member__nextOrderType : int&;
                                   var squad_member__nextOrderPosition : float3&;
                                   var squad_member__nextOrderByDirection : float3&;
                                   var squad_member__nextOrderToPosition : float3&;
                                   var squad_member__nextOrderToDirection : float3&;
                                   var squad_member__nextOrderUseEntity : EntityId&;
                                   var squad_member__nextPersonalOrder : bool&)
    squad_member__nextOrderType = squad_member__orderType
    squad_member__nextOrderPosition = squad_member__orderPosition
    squad_member__nextOrderByDirection = squad_member__orderByDirection
    squad_member__nextOrderToPosition = squad_member__orderToPosition
    squad_member__nextOrderToDirection = squad_member__orderToDirection
    squad_member__nextOrderUseEntity = squad_member__orderUseEntity
    squad_member__nextPersonalOrder = squad_member__isPersonalOrder

def has_next_squad_mate_order(squad_mate_eid : EntityId)
  var result = false
  query(squad_mate_eid) <| $ [es] (squad_member__nextOrderType : int)
    if squad_member__nextOrderType != int(SquadMateOrder.ESMO_NO_ORDER)
      result = true
  return result

def switch_to_next_squad_mate_order(squad_mate_eid : EntityId)
  if !has_next_squad_mate_order(squad_mate_eid)
    reset_squad_mate_order(squad_mate_eid, false)
    return
  query(squad_mate_eid) <| $ [es] (var squad_member__orderType : int&;
                                   var squad_member__orderPosition : float3&;
                                   var squad_member__orderByDirection : float3&;
                                   var squad_member__orderToPosition : float3&;
                                   var squad_member__orderToDirection : float3&;
                                   var squad_member__orderUseEntity : EntityId&;
                                   var squad_member__isPersonalOrder : bool&;
                                   squad_member__nextOrderType : int;
                                   squad_member__nextOrderPosition : float3;
                                   squad_member__nextOrderByDirection : float3;
                                   squad_member__nextOrderToPosition : float3;
                                   squad_member__nextOrderToDirection : float3;
                                   squad_member__nextOrderUseEntity : EntityId;
                                   squad_member__nextPersonalOrder : bool)
    squad_member__orderType = squad_member__nextOrderType
    squad_member__orderPosition = squad_member__nextOrderPosition
    squad_member__orderByDirection = squad_member__nextOrderByDirection
    squad_member__orderToPosition = squad_member__nextOrderToPosition
    squad_member__orderToDirection = squad_member__nextOrderToDirection
    squad_member__orderUseEntity = squad_member__nextOrderUseEntity
    squad_member__isPersonalOrder = squad_member__nextPersonalOrder
  reset_next_squad_mate_order(squad_mate_eid)


def reset_squad_mate_order(squad_mate_eid : EntityId; reset_follow : bool = true)
  query(squad_mate_eid) <| $ [es] (var squad_member__orderType : int&;
                                   var squad_member__orderPosition : float3&;
                                   var squad_member__orderByDirection : float3&;
                                   var squad_member__orderToPosition : float3&;
                                   var squad_member__orderToDirection : float3&;
                                   var squad_member__orderUseEntity : EntityId&;
                                   var squad_member__isPersonalOrder : bool&;
                                   var beh_tree : BehaviourTree&)
    squad_member__orderType = int(SquadMateOrder.ESMO_NO_ORDER)
    squad_member__orderPosition = float3()
    squad_member__orderByDirection = float3()
    squad_member__orderToPosition = float3()
    squad_member__orderToDirection = float3()
    squad_member__orderUseEntity = INVALID_ENTITY_ID
    squad_member__isPersonalOrder = false

    beh_tree.blackBoard |> set("regroupPosition", float3())
    beh_tree.blackBoard |> set("wishPosition", float3())

    beh_tree.blackBoard |> set("healRequester", 0) 

  reset_next_squad_mate_order(squad_mate_eid)

  if reset_follow
    query(squad_mate_eid) <| $ [es] (var squad_member__followLeader : bool&;
                                     var squad_member__followLeaderPos : float3&)
      squad_member__followLeader = false
      squad_member__followLeaderPos = float3()

def has_any_squad_mate_order(squad_mate_eid : EntityId)
  var result = false
  query(squad_mate_eid) <| $ [es] (squad_member__orderType : int)
    if squad_member__orderType != int(SquadMateOrder.ESMO_NO_ORDER)
      result = true
  return result

def reset_squad_mate_orders(squad_eid, squad__leader : EntityId)
  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    for memberEid in squad__allMembers
      if memberEid != squad__leader
        if has_any_squad_mate_order(memberEid)
          reset_squad_mate_order(memberEid)

def reset_squadmate_orders_exclude_personal(squad_eid : EntityId)
  query(squad_eid) <| $ [es] (squad__allMembers : EidList)
    for memberEid in squad__allMembers
      var hasPersonal = false
      query(memberEid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__isPersonalOrder : bool)
        if squad_member__isPersonalOrder
          hasPersonal = true
      if !hasPersonal
        reset_squad_mate_order(memberEid)

def reset_personal_squadmate_orders(squad_mate_eid : EntityId)
  query(squad_mate_eid) <| $ [es(REQUIRE_NOT=deadEntity)] (squad_member__squad : EntityId;
                                                           squad_member__orderType : int;
                                                           squad_member__orderUseEntity : EntityId;
                                                           squad_member__isPersonalOrder : bool;
                                                           var beh_tree : BehaviourTree&)
    if squad_member__isPersonalOrder
      if squad_member__orderType == int(SquadMateOrder.ESMO_DEFEND_POINT) && has(squad_member__orderUseEntity, "capzone")
        query(squad_member__squad) <| $ [es] (squad__regroupPos : float3)
          beh_tree.blackBoard |> set("wishPosition", squad__regroupPos)
      reset_squad_mate_order(squad_mate_eid)

def get_nearest_squad_mate_for_order(squad_eid, squad__leader : EntityId; order : SquadMateOrder) : MemberForOrder
  return get_nearest_squad_mate_for_order(squad_eid, squad__leader, order) <| $ [unused_argument(_)] (_ : EntityId) => true

def get_nearest_squad_mate_for_order(squad_eid, squad__leader : EntityId; order : SquadMateOrder; cond : block<(EntityId) : bool>) : MemberForOrder
  return get_nearest_squad_mate_for_order_impl(squad_eid, squad__leader, MaybeOrder(order = order), cond)

def get_nearest_squad_mate_not_ordered(squad_eid, squad__leader : EntityId) : MemberForOrder
  return get_nearest_squad_mate_not_ordered(squad_eid, squad__leader) <| $ [unused_argument(_)] (_ : EntityId) => true

def get_nearest_squad_mate_not_ordered(squad_eid, squad__leader : EntityId; cond : block<(EntityId) : bool>) : MemberForOrder
  return get_nearest_squad_mate_for_order_impl(squad_eid, squad__leader, MaybeOrder(nothing = null), cond)

def private get_nearest_squad_mate_for_order_impl(squad_eid, squad__leader : EntityId; maybe_order : MaybeOrder; cond : block<(EntityId) : bool>) : MemberForOrder
  let leaderTMRef = get_TMatrix(squad__leader, "transform")
  if leaderTMRef == null
    return MemberForOrder(eid = INVALID_ENTITY_ID, executeOrder = false)
  let leaderTM = *leaderTMRef
  var alreadyOrdered = false
  var nearestTeammate = INVALID_ENTITY_ID
  var minDistSq = 0.0
  find_query() <| $ [es(REQUIRE=walker_agent)] (eid : EntityId;
                                                squad_member__squad : EntityId;
                                                squad_member__orderType : int;
                                                transform : float3x4;
                                                isAlive : bool;
                                                isDowned : bool = false)
    if squad_eid != squad_member__squad || eid == squad__leader || !isAlive || isDowned
      return false
    if maybe_order is order
      alreadyOrdered = squad_member__orderType == int(maybe_order as order)
      if alreadyOrdered
        nearestTeammate = eid
        return true
    if !invoke(cond, eid)
      return false
    let distSq = distance_sq(transform[3], leaderTM[3])
    if nearestTeammate == INVALID_ENTITY_ID || distSq < minDistSq
      minDistSq = distSq
      nearestTeammate = eid
    return false

  return MemberForOrder(eid = nearestTeammate, executeOrder = alreadyOrdered)


def get_num_alive_squad_members(squad_eid : EntityId)
  return get_int(squad_eid, "squad__numAliveMembers") ?? 0

def get_squad_leader(squad_eid : EntityId)
  return get_Eid(squad_eid, "squad__leader") ?? INVALID_ENTITY_ID

def get_squad_owner(squad_eid : EntityId)
  var ownerEid = INVALID_ENTITY_ID
  query(squad_eid) <| $ [es] (squad__ownerPlayer : EntityId)
    ownerEid = squad__ownerPlayer
  return ownerEid

def is_squad_member(squad_eid : EntityId; memberEid : EntityId) : bool
  if !squad_eid
    return false

  var isMemberSquad = false
  query(memberEid) <| $ [es] (squad_member__squad : EntityId)
    isMemberSquad = squad_member__squad == squad_eid
  return isMemberSquad

def suicide_kill(eid : EntityId)
  sendEvent(eid, CmdRequestSuicide())

def kill_squad(squad_eid : EntityId)
  kill_squad(squad_eid) <| $ [unused_argument(_)] (_) => true

def kill_squad(squad_eid : EntityId; blk : block<(eid : EntityId) : bool>)
  query() <| $ [es] (eid : EntityId; squad_member__squad : EntityId; isAlive : bool)
    if isAlive && squad_eid == squad_member__squad && invoke(blk, eid)
      suicide_kill(eid)

def kill_player_squad(player_eid : EntityId) : void
  query(player_eid) <| $ [es(REQUIRE=player)] (possessed : EntityId)
    let squad_eid : EntityId = get_Eid(possessed, "squad_member__squad") ?? INVALID_ENTITY_ID
    if squad_eid != INVALID_ENTITY_ID
      kill_squad(squad_eid)
