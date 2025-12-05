require ecs
require DngWalkerai
require DagorRandom
require math
require math.base
require %appGame.infantry.es.squad_common
require %appGame.infantry.es.squad_order_common
require %appGame.squad_order_enums
require %appGame.infantry.ai.ai_covers_common

let
  predefined_angles = fixed_array<float>(-HALF_PI, HALF_PI, -HALF_PI * 1.5f, HALF_PI * 1.5f)

def recalc_member_offset(member_idx : int; spread : float) : float3
  let ang = predefined_angles[member_idx % length(predefined_angles)]
  var sine, cosine : float
  sincos(ang, sine, cosine)
  let offset = float((member_idx / length(predefined_angles)) + 1) * spread
  return float3(cosine * offset, 0.0, sine * offset)

def squad_members_count_impl(dt : float;
                             squad__leader : EntityId;
                             squad__orderType : int;
                             squad__regroupPos : float3;
                             squad__orderUseEntity : EntityId;
                             squad__shouldStandExactAtOrderPoint : bool;
                             squad__spreadAroundOrderPoint : float3;
                             squad__checkMembersTimeout : float;
                             squad__allMembers : EidList;
                             var squad__numAliveMembers : int&;
                             var squad__numMembers : int&;
                             var squad__checkMembersTimer : float&)
  squad__checkMembersTimer -= dt
  if squad__checkMembersTimer <= 0.0f
    squad__checkMembersTimer = squad__checkMembersTimeout * (1.0f + gfrnd() * 0.5f)
    let avoidLeaderActing = get_squad_leader_acting(squad__leader)
    var numMembers = 0
    var numAliveMembers = 0
    var shouldStandExactAtOrderPoint = squad__shouldStandExactAtOrderPoint && squad__orderType == int(SquadOrder.ESO_DEFEND_POINT) && squad__orderUseEntity == INVALID_ENTITY_ID
    var members : array<EntityId>
    var posList : array<tuple<offset : float3; pos : float3>>
    for memberEid in squad__allMembers
      query(memberEid) <| $ [es] (var squad_member__offset : float3&; transform : float3x4; isAlive : bool; isDowned = false)
        numMembers++
        if isAlive
          numAliveMembers++
        if (memberEid != squad__leader) && (!shouldStandExactAtOrderPoint || is_conflict_with_squad_leader_acting(avoidLeaderActing, transform[3], memberEid))
          push(members, memberEid)
        elif isAlive && !isDowned
          shouldStandExactAtOrderPoint = false
          squad_member__offset = float3(0.0, 0.0, 0.0)

    var numPoses = length(members)
    if numPoses % 2 != 0
      numPoses++
    if avoidLeaderActing.actingFlags != 0
      numPoses += 2
    for i in range(0, numPoses)
      let offset = recalc_member_offset(i, squad__spreadAroundOrderPoint.y)
      let pos = find_best_squad_pos(squad__leader, squad__orderType, squad__regroupPos, offset, squad__spreadAroundOrderPoint.x).p
      posList |> emplace((offset, pos))

    for memberEid in members
      query(memberEid) <| $ [es] (transform : float3x4; var squad_member__offset : float3&)
        var minDistSq : float = 0.0f
        var minI : int = -1
        for i in range(0, length(posList))
          let pos = posList[i].pos
          let distSq = length_sq(pos - transform[3])
          if minI < 0 || distSq < minDistSq
            if !is_conflict_with_squad_leader_acting(avoidLeaderActing, pos, memberEid)
              minI = i
              minDistSq = distSq
        if minI >= 0
          squad_member__offset = posList[minI].offset
          erase(posList, minI)
        else
          squad_member__offset = float3(-1.0, 0.0, 0.0) * squad__spreadAroundOrderPoint.y

    squad__numMembers = max(squad__numMembers, numMembers)
    squad__numAliveMembers = numAliveMembers


[es(tag=server, no_order)]
def squad_members_count_es(act : UpdateStageInfoAct; squad__leader : EntityId;
                           squad__orderType : int; squad__regroupPos : float3; squad__orderUseEntity : EntityId;
                           squad__shouldStandExactAtOrderPoint : bool; squad__spreadAroundOrderPoint : float3;
                           squad__checkMembersTimeout : float; squad__allMembers : EidList;
                           var squad__numAliveMembers : int&;
                           var squad__numMembers : int&; var squad__checkMembersTimer : float&)
  squad_members_count_impl(act.dt, squad__leader, squad__orderType, squad__regroupPos, squad__orderUseEntity,
    squad__shouldStandExactAtOrderPoint, squad__spreadAroundOrderPoint, squad__checkMembersTimeout,
    squad__allMembers, squad__numAliveMembers, squad__numMembers, squad__checkMembersTimer)

[es(track=(squad__orderType, squad__leader, squad__orderUseEntity), tag=server)]
def squad_members_count_trigger_es(evt : Event; squad__leader : EntityId;
                                   squad__orderType : int; squad__regroupPos : float3; squad__orderUseEntity : EntityId;
                                   squad__shouldStandExactAtOrderPoint : bool; squad__spreadAroundOrderPoint : float3;
                                   squad__checkMembersTimeout : float; squad__allMembers : EidList;
                                   var squad__numAliveMembers : int&;
                                   var squad__numMembers : int&; var squad__checkMembersTimer : float&)
  squad__checkMembersTimer = 0.0f
  squad_members_count_impl(0.0f, squad__leader, squad__orderType, squad__regroupPos, squad__orderUseEntity,
    squad__shouldStandExactAtOrderPoint, squad__spreadAroundOrderPoint, squad__checkMembersTimeout,
    squad__allMembers, squad__numAliveMembers, squad__numMembers, squad__checkMembersTimer)
