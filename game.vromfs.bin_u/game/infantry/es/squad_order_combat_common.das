module squad_order_combat_common shared

require ecs
require net
require math.random
require pathfinder
require PropsManager
require BallisticsProps
require DaWeaponProps
require HumanPhys
require Unit

require %appGame.wt_events
require %appGame.infantry.es.squad_order_common
require %appGame.infantry.ai.ai_combat_common
require %appGame.infantry.ai.ai_weapons_common
require %appGame.squad_order_enums


def find_attack_vehicle_squad_candidates(squad__allMembers : EidList;
                                         squad__leader : EntityId;
                                         is_ground_vehicle : bool;
                                         is_air_vehicle : bool;
                                         var candidates : array<EntityId>&)
  var primaryCandidates : array<EntityId>
  var secondaryCandidates : array<EntityId>
  let numMembers = length(squad__allMembers)
  primaryCandidates |> reserve(numMembers)
  secondaryCandidates |> reserve(numMembers)

  for memberEid in squad__allMembers
    if memberEid == squad__leader
      continue
    query(memberEid) <| $ [es] (isAlive : bool;
                                isDowned : bool;
                                human_weap__gunEids : EidList;
                                squad_member__canAttackGroundVehicle : bool;
                                squad_member__canAttackAirVehicle : bool;
                                squad_member__orderType : int)
      if !isAlive || isDowned || is_squad_mate_order_action(squad_member__orderType)
        return

      let gunEid = human_weap__gunEids[int(HUWeaponSlots.EWS_TERTIARY)]
      var isGunReloaded = false
      query(gunEid) <| $ [es] (gun__ammo : int; gun__maxAmmo : int)
        isGunReloaded = gun__ammo == gun__maxAmmo
      if is_ground_vehicle && squad_member__canAttackGroundVehicle || is_air_vehicle && squad_member__canAttackAirVehicle
        if isGunReloaded
          primaryCandidates |> push(memberEid)
        else
          secondaryCandidates |> push(memberEid)

  let lenPrimary = length(primaryCandidates)
  let lenSecondary = length(secondaryCandidates)
  if lenPrimary > 0 || lenSecondary > 0
    candidates |> reserve(lenPrimary + lenSecondary)
    if lenPrimary > 0
      candidates |> push(primaryCandidates)
    if lenSecondary > 0
      candidates |> push(secondaryCandidates)
    return true

  return false

def find_attack_vehilce_executor_and_positions(candidates : array<EntityId>;
                                               vehicle_eid : EntityId;
                                               var out_executor_eid : EntityId&;
                                               var out_shoot_pos_to : float3&;
                                               var out_shoot_pos_from : float3&)
  var found = false
  var executorEid = INVALID_ENTITY_ID
  var shootPosTo : float3 = float3(0.0, 0.0, 0.0)
  var shootPosFrom : float3 = float3(0.0, 0.0, 0.0)

  for memberEid in candidates
    query(memberEid) <| $ [es] (transform : float3x4;
                                human_weap__gunEids : EidList)
      let gunEid = human_weap__gunEids[int(HUWeaponSlots.EWS_TERTIARY)]
      var traceParams = TracePierceShotParams()
      query(gunEid) <| $ [es] (gun__curShellId : PropsId;
                               combatBallisticCoef : float = 0.0;
                               specialAIWeaponType : int = 0)
        let runShootGuided = specialAIWeaponType == int(SpecialAIWeaponType.ATGM_MPADS_LAUNCHERS)
        if !runShootGuided
          shell_start_get_props(gun__curShellId) <| $(shellStartProps : ShellStartProps)
            if shellStartProps.speed > 0.0
              traceParams.shellVel = shellStartProps.speed
          get_props_RocketProperties(gun__curShellId) <| $(rocketMotorProps : RocketProperties)
            let speed = rocketMotorProps.rocketMotor.endSpeed
            if speed > 0.0
              traceParams.shellVel = speed
        traceParams.shellId = gun__curShellId
        traceParams.ballisticCoef = combatBallisticCoef

      let randOffset = float2(0.35, 0.15)
      var targetDMAIPoints : array<TargetDMAIPoint>
      pick_target_dm_ai_points(targetDMAIPoints, 5, transform[3], vehicle_eid, false, randOffset,  false, 0.25)
      for dmPoint in targetDMAIPoints
        let innerRadius = 1.0
        let outerRadius = 6.0
        var outShootPos : float3
        if check_shoot_positions_in_radius(transform[3], dmPoint.worldPos, innerRadius, outerRadius, vehicle_eid, traceParams, outShootPos)
          executorEid = memberEid
          shootPosFrom = outShootPos
          shootPosTo = dmPoint.worldPos
          found = true
          return
    if found
      break

  if found
    out_executor_eid = executorEid
    out_shoot_pos_to = shootPosTo
    out_shoot_pos_from = shootPosFrom
    return true
  return false

def check_shoot_positions_in_radius(soldier_pos : float3;
                                    target_pos : float3;
                                    inner_radius : float;
                                    outer_radius : float;
                                    target_eid : EntityId;
                                    trace_params : TracePierceShotParams,
                                    var out_run_shoot_pos : float3&)
  let heightOffset = 1.45
  var aimShootHitPos : float3
  
  if trace_pierce_shot(aimShootHitPos, soldier_pos + float3(0, heightOffset, 0), target_pos, target_eid, trace_params)
    out_run_shoot_pos = soldier_pos
    return true

  let MAX_SHOOT_POSITIONS = 5
  let maxPathDist = 20.0
  let angleStep = 2.0 * PI / float(MAX_SHOOT_POSITIONS)
  var found = false
  for i in 0..MAX_SHOOT_POSITIONS + 1
    let angle = angleStep * float(i)
    let dist = rnd_float(inner_radius, outer_radius)
    let offset = float3(cos(angle), 0.0, sin(angle)) * dist
    let extents = float3(0.1, 2.5, 0.1)
    var memberPos : float3 = soldier_pos + offset
    var hasPath = false
    find_path(soldier_pos, memberPos, extents, 0.5, 1.0) <| $(path)
      let numPoints = length(path)
      if numPoints <= 1
        return
      var totalPathDist = 0.0
      for j in range(numPoints - 1)
        let pt1 = path[j]
        let pt2 = path[j + 1]
        let partPathDist = length(pt2 - pt1)
        totalPathDist += partPathDist
        if totalPathDist > maxPathDist
          return
      memberPos = path[numPoints - 1]
      hasPath = true

    if !hasPath
      continue

    let shootPos = memberPos + float3(0, heightOffset, 0)
    if trace_pierce_shot(aimShootHitPos, shootPos, target_pos, target_eid, trace_params)
      out_run_shoot_pos = memberPos
      found = true
      break
  return found

def squad_order_attack_vehicle_execute(squad_eid : EntityId; vehicle_eid : EntityId)
  query(squad_eid) <| $ [es] (squad__leader : EntityId; squad__allMembers : EidList)
    var vehicleTransform : float3x4
    var isGroundVehicle = false
    var isAirVehicle = false
    var isVehicleAlive = true
    query(vehicle_eid) <| $ [es] (transform : float3x4;
                                  unit__ref : UnitRef;
                                  unit_tag__tank : Tag const?;
                                  unit_tag__aircraft : Tag const?)
      if !unit__ref.unit.isAlive
        isVehicleAlive = false
        return
      vehicleTransform = transform
      isGroundVehicle = unit_tag__tank != null
      isAirVehicle = unit_tag__aircraft != null

    if !isVehicleAlive
      send_net_event(squad__leader, CmdHeroLogEvent(event = "squad_order_canceled", text = "squad_orders/no_way_to_attack_vehicle_dead"))
      return

    var foundExecutor = false
    var candidates : array<EntityId>
    var executorEid = INVALID_ENTITY_ID
    var shootPosTo : float3 = float3(0.0, 0.0, 0.0)
    var shootPosFrom : float3 = float3(0.0, 0.0, 0.0)
    if find_attack_vehicle_squad_candidates(squad__allMembers, squad__leader, isGroundVehicle, isAirVehicle, candidates)
      foundExecutor = find_attack_vehilce_executor_and_positions(candidates, vehicle_eid, executorEid, shootPosTo, shootPosFrom)

    if !foundExecutor
      send_net_event(squad__leader, CmdHeroLogEvent(event = "squad_order_canceled", text = "squad_orders/no_way_to_attack_vehicle_no_one_can"))
      return

    let localPosTo = inverse(vehicleTransform) * shootPosTo

    send_net_event(executorEid, RequestPersonalSquadMateOrder(orderType = int(SquadMateOrder.ESMO_ATTACK_VEHICLE), orderPosition = shootPosFrom, orderToPosition = localPosTo, orderUseEntity = vehicle_eid))
