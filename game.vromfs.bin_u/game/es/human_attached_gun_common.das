module human_attached_gun_common shared
require ecs
require app

require %appGame.es.team_common
require DaWeapons
require DngWeapon
require Weapon

require %appGame.es.interactable_common
require HumanPhys
require WTPhysActor
require DngHuman
require net
require EffectorData
require AnimV20
require GeomNodeTree
require math
require math.base
require DagorMath
require Dacoll
require walkerai

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanAttachToGunResponse
  gun_eid : EntityId

[event(unicast, routing=ROUTING_SERVER_TO_CLIENT)]
struct HumanDetachFromGunResponse {}

[event(unicast)]
struct HumanDetachFromGunComplete {}


def reset_attached_gun(gun_eid : EntityId)
  query(gun_eid) <| $ [es] (dependsOnBuildingEid : EntityId = INVALID_ENTITY_ID;
                            var mounted_gun : MountedGun;
                            var gun : Gun;
                            var gun__owner : EntityId&;
                            var animchar__updatable : bool&;
                            var interactable : bool&;
                            var mounted_gun__active : bool&;
                            var team : int?;
                            lower_stationary_gun_after_use__loweringSide : int const?)
    gun.appliedControls.shoot = false

    gun__owner = INVALID_ENTITY_ID

    if lower_stationary_gun_after_use__loweringSide != null 
      addSubTemplate(gun_eid, "lower_stationary_gun_after_use")
    else
      animchar__updatable = false
    interactable = true

    mounted_gun__active = false
    mounted_gun.wishShoot = false
    mounted_gun.locked = false
    if team != null
      *team = TEAM_UNASSIGNED
    query(dependsOnBuildingEid) <| $ [es] (var team : int&)
      team = TEAM_UNASSIGNED


def detach_from_gun(eid : EntityId;
                    var human_attached_gun__attachedGunEid : EntityId&)
  reset_attached_gun(human_attached_gun__attachedGunEid)
  human_attached_gun__attachedGunEid = INVALID_ENTITY_ID
  query(eid) <| $ [es] (var human_net_phys : HumanActor;
                        var animchar_effectors__effectorsState : Object;
                        var human_attached_gun__lhandNodeIdx : int&;
                        var human_attached_gun__rhandNodeIdx : int&)

    var rightHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.hand")
    if rightHandEffector != null
      rightHandEffector.weight = 0.0
    var leftHandEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.hand")
    if leftHandEffector != null
      leftHandEffector.weight = 0.0

    human_attached_gun__lhandNodeIdx = -1
    human_attached_gun__rhandNodeIdx = -1

    if is_server()
      human_net_phys.phys.currentState.weapEquipState.progress = 0.0
      human_net_phys.phys.currentState.weapEquipState.curState = HUWeaponEquipState EES_EQUIPING
      send_net_event(eid, [[HumanDetachFromGunResponse]])

    sendEventImmediate(eid, [[HumanDetachFromGunComplete]])

    human_net_phys.phys.currentState |> human_phys_state_set_isAttached(false)


def gun_needs_detach(gun_eid : EntityId; human_pos : float3)
  var res = false
  query(gun_eid) <| $ [es] (transform : float3x4;
                            animchar : AnimcharBaseComponent;
                            gun_autodetach__threshold : float3;
                            gun_autodetach__nodeId : int = -1)
    var gunTm = transform
    if gun_autodetach__nodeId >= 0
      geomtree_getNodeWtmScalar(*animchar.nodeTree, gun_autodetach__nodeId, gunTm)
    let humanToGunDir = gunTm[3] - human_pos
    let forwardDist = abs(dot(humanToGunDir, gunTm[2]))
    let upDist = dot(humanToGunDir, float3(0.0, 1.0, 0.0))
    let sideDist = abs(dot(humanToGunDir, gunTm[0]))
    if ((upDist < 0.0) || (forwardDist > gun_autodetach__threshold.z) ||
        (upDist > gun_autodetach__threshold.y) || (sideDist > gun_autodetach__threshold.x))
      res = true
  return res


def find_gun_to_attach(human_eid : EntityId; radius : float = 2.0; ignore_checks : bool = false)
  var gunEid = find_interactable(ecs_hash("interactable"), human_eid, radius, ignore_checks) <| $(eid : EntityId)
    return has(eid, "stationary_gun")
  if gunEid != INVALID_ENTITY_ID
    query(human_eid) <| $ [es] (human_net_phys : HumanActor)
      if gun_needs_detach(gunEid, float3(human_net_phys.phys.currentState.location.P))
        gunEid = INVALID_ENTITY_ID
  return gunEid


let
  MOUNTED_GUN_DEFAULT_ROT_OFFSET = float3(0.0, 0.3, 0.3)
  MOUNTED_GUN_DEFAULT_LIMITS_MOD = float2(0.95, 0.95)
  MOUNTED_GUN_DEFAULT_FIRE_RANGE = float2(5.0, 90.0)
  MOUNTED_GUN_TARGET_AVG_TIME_TO_COME = 5.0
  MOUNTED_GUN_TRACE_SKIP_DISTANCE = 1.5

def can_shoot_from_attached_gun(gun_eid : EntityId)
  var canShoot = false
  query(gun_eid) <| $ [es(REQUIRE=stationary_gun)] (isAlive : bool; gun : Gun)
    canShoot = isAlive && get_sync_time() >= gun.nextShotAtTime
  return canShoot

def get_attached_gun_ai_aim_point(var out_pos : float3&; gun_eid : EntityId; k_yaw : float; k_pitch : float; k_dist : float)
  var res = false
  query(gun_eid) <| $ [es] (transform : float3x4;
                            mounted_gun__aiRotOffset : float3 = MOUNTED_GUN_DEFAULT_ROT_OFFSET;
                            mounted_gun__aiLimitsMod : float2 = MOUNTED_GUN_DEFAULT_LIMITS_MOD;
                            mounted_gun__aiFireRange : float2 = MOUNTED_GUN_DEFAULT_FIRE_RANGE;
                            mounted_gun__horz_limits : float2;
                            mounted_gun__vert_limits : float2)
    let gunFw = -transform[2]
    let gunRt = -transform[0]
    let gunUp = transform[1]
    let gunPos = transform[3] + gunUp * mounted_gun__aiRotOffset.y + mounted_gun__aiRotOffset.x * gunRt + gunFw * mounted_gun__aiRotOffset.z

    let yaw = deg_to_rad((k_yaw < 0.0 ? (mounted_gun__horz_limits.x * -k_yaw) : (mounted_gun__horz_limits.y * k_yaw)) * mounted_gun__aiLimitsMod.x)
    let pitch = deg_to_rad((k_pitch < 0.0 ? (mounted_gun__vert_limits.x * -k_pitch) : (mounted_gun__vert_limits.y * k_pitch)) * mounted_gun__aiLimitsMod.y)
    let dist = lerp(mounted_gun__aiFireRange.x, mounted_gun__aiFireRange.y, k_dist)

    let dx = sin(yaw)
    let dy = sin(pitch)
    let dz = cos(pitch) * cos(yaw)
    out_pos = gunPos + (gunRt * dx + gunUp * dy + gunFw * dz) * dist
    res = true
  return res

def is_pos_in_attached_gun_ai_aim_range(pos : float3; gun_eid : EntityId)
  var res = false
  query(gun_eid) <| $ [es] (transform : float3x4;
                            mounted_gun__aiRotOffset : float3 = MOUNTED_GUN_DEFAULT_ROT_OFFSET;
                            mounted_gun__aiLimitsMod : float2 = MOUNTED_GUN_DEFAULT_LIMITS_MOD;
                            mounted_gun__aiFireRange : float2 = MOUNTED_GUN_DEFAULT_FIRE_RANGE;
                            mounted_gun__horz_limits : float2;
                            mounted_gun__vert_limits : float2)
    let gunFw = -transform[2]
    let gunRt = -transform[0]
    let gunUp = transform[1]
    let gunPos = transform[3] + gunUp * mounted_gun__aiRotOffset.y + mounted_gun__aiRotOffset.x * gunRt + gunFw * mounted_gun__aiRotOffset.z

    let delta = pos - gunPos
    let distSq = length_sq(delta)
    if distSq < square(mounted_gun__aiFireRange.x) || distSq > square(mounted_gun__aiFireRange.y)
      return

    var localPos = inverse(transform) * pos
    localPos.x = -localPos.x
    localPos.z = -localPos.z
    localPos -= mounted_gun__aiRotOffset

    let yaw = atan2(localPos.x, localPos.z)
    let yawMin = deg_to_rad(mounted_gun__horz_limits.x * mounted_gun__aiLimitsMod.x)
    let yawMax = deg_to_rad(mounted_gun__horz_limits.y * mounted_gun__aiLimitsMod.x)
    if yaw < yawMin || yaw > yawMax
      return

    let yawLimitsPitchCoef = cos(yaw)
    let pitchCoef = mounted_gun__aiLimitsMod.y * yawLimitsPitchCoef

    let xzLen = sqrt(square(localPos.x) + square(localPos.z))
    let pitch = atan2(localPos.y, xzLen)
    let pitchMin = deg_to_rad(mounted_gun__vert_limits.x * pitchCoef)
    let pitchMax = deg_to_rad(mounted_gun__vert_limits.y * pitchCoef)
    if pitch < pitchMin || pitch > pitchMax
      return

    res = true
  return res

def get_attached_gun_ai_aim_to_dir(gun_eid : EntityId)
  var dir = float3()
  query(gun_eid) <| $ [es] (transform : float3x4)
    let gunFw = -transform[2]
    dir = gunFw
  return dir

def get_attached_gun_ai_aim_from_pos(gun_eid : EntityId)
  var pos = float3()
  query(gun_eid) <| $ [es] (transform : float3x4;
                            mounted_gun__aiRotOffset : float3 = MOUNTED_GUN_DEFAULT_ROT_OFFSET)
    let gunFw = -transform[2]
    let gunRt = -transform[0]
    let gunUp = transform[1]
    let gunPos = transform[3] + gunUp * mounted_gun__aiRotOffset.y + mounted_gun__aiRotOffset.x * gunRt + gunFw * mounted_gun__aiRotOffset.z
    pos = gunPos
  return pos

def check_attached_gun_target(gun_eid : EntityId; target_eid : EntityId; trace_hit : bool; var traced : bool&)
  var res = false
  traced = false
  query(target_eid) <| $ [es] (ai_target : Target)
    if !ai_target.isAlive || ai_target.isHidden
      return
    if !is_pos_in_attached_gun_ai_aim_range(ai_target.targetPos, gun_eid)
      return
    if trace_hit
      var fromPos = get_attached_gun_ai_aim_from_pos(gun_eid)
      let dir = ai_target.targetPos - fromPos
      let ndir = normalize(dir)
      fromPos += ndir * MOUNTED_GUN_TRACE_SKIP_DISTANCE
      var norm : float3
      var dist = length(dir) - MOUNTED_GUN_TRACE_SKIP_DISTANCE
      traced = true
      if traceray_normalized(fromPos, ndir, dist, norm, ETF_ALL)
        return
    res = true
  return res

def is_attached_gun_hidden_target_incoming(gun_eid : EntityId; target_eid : EntityId)
  var res = false
  query(target_eid) <| $ [es] (ai_target : Target; human_net_phys : HumanActor)
    if is_pos_in_attached_gun_ai_aim_range(ai_target.targetPos, gun_eid)
      res = true
      return
    assume vel = human_net_phys.phys.currentState.velocity
    let predictedPos = ai_target.targetPos + vel * MOUNTED_GUN_TARGET_AVG_TIME_TO_COME
    if is_pos_in_attached_gun_ai_aim_range(predictedPos, gun_eid)
      res = true
      return
  return res
