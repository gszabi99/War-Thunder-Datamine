require ecs
require app
require DagorMath
require DagorMathUtils
require DngHuman
require AnimV20
require GeomNodeTree
require Dacoll
require math.base
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.bipod_common
require PhysMat
require EffectorData
require %appGame.infantry.es.equipment_common


def get_anim_node_offset(animchar; nodeId) : float3
  var rootTm : float3x4
  var nodeTm : float3x4
  geomtree_getNodeWtmScalar(*animchar.nodeTree, 0, rootTm)
  geomtree_getNodeWtmScalar(*animchar.nodeTree, nodeId, nodeTm)
  swap_xz(rootTm)
  swap_xz(nodeTm)
  let relTm = inverse(rootTm) * nodeTm
  return relTm[3]

[es(tag=server, on_appear)]
def bipod_init_offset(evt : Event;
                      animchar : AnimcharBaseComponent;
                      gun__bipodNode : string;
                      gun__barrelTipNode : string;
                      var gun__bipodOffset : float3&;
                      var gun__barrelTipOffset : float3&;
                      gun__barrelTipOffsetOverride : float3 = float3(0.0, 0.0, 0.0))
  let bipodNodeId = geomtree_findNodeIndex(*animchar.nodeTree, gun__bipodNode)
  if bipodNodeId >= 0
    gun__bipodOffset = get_anim_node_offset(animchar, bipodNodeId)

  let barrelTipNodeId = geomtree_findNodeIndex(*animchar.nodeTree, gun__barrelTipNode)
  if barrelTipNodeId >= 0
    gun__barrelTipOffset = get_anim_node_offset(animchar, barrelTipNodeId)

  if gun__barrelTipOffsetOverride.x != 0.0
    gun__barrelTipOffset = gun__barrelTipOffsetOverride

def bipod_update_height(var human_net_phys : HumanActor&; is_fpv : bool;
                        human_tm : float3x4; bipod_is_crawl : bool; aim_pitch : float;
                        bipod_anchor_pos : float3; bipod_anchor_height : float; bipod_anchor_offset : float3; var bipod_pitch_limit : float2&)
  let anchorPos = bipod_anchor_pos + float3(0.0, bipod_anchor_height, 0.0)
  let sinPitch = sin(aim_pitch)

  var height = 0.0
  if bipod_is_crawl
    height = -1.0
  else
    let stick = bipod_anchor_offset.x
    let baseY = anchorPos.y - bipod_anchor_offset.y
    let findY = baseY - stick * sinPitch - (1.0 - cos(aim_pitch)) * bipod_anchor_height * 0.5

    var gun1 = is_fpv ? calc_fpv_gun_pos_for_height(human_net_phys, human_tm, aim_pitch, 1.0) : calc_tpv_gun_pos_for_height(human_net_phys, human_tm, aim_pitch, 1.0)
    var gun2 = is_fpv ? calc_fpv_gun_pos_for_height(human_net_phys, human_tm, aim_pitch, 0.0) : calc_tpv_gun_pos_for_height(human_net_phys, human_tm, aim_pitch, 0.0)

    let bipod__pitchLimitExtraHeight = 0.3
    gun1.y += bipod__pitchLimitExtraHeight
    gun2.y -= bipod__pitchLimitExtraHeight

    height = cvt(findY, gun1.y, gun2.y, 1.0, 0.0)

    if bipod_anchor_offset.x > 0.0
      let upH = max(gun1.y - baseY, 0.0)
      let dnH = max(baseY - gun2.y, 0.0)
      bipod_pitch_limit.x = clamp(rad_to_deg(atan2(-upH, stick)), BIPOD_DEFAULT_PITCH_MIN, BIPOD_DEFAULT_PITCH_MAX)
      bipod_pitch_limit.y = clamp(rad_to_deg(atan2(dnH, stick)), BIPOD_DEFAULT_PITCH_MIN, BIPOD_DEFAULT_PITCH_MAX)
    else
      bipod_pitch_limit.x = 0.0
      bipod_pitch_limit.y = 0.0

  human_net_phys.phys.currentState.height = height


[es(tag=netClient, REQUIRE_NOT=hero, on_event=ParallelUpdateFrameDelayed )]
def bipod_other_human_act_es(evt : Event;
                             bipod__anchorPos : float3;
                             bipod__anchorHeight : float;
                             bipod__anchorOffset : float3;
                             bipod__isCrawl : bool;
                             bipod__enabled : bool;
                             var human_net_phys : HumanActor&)
  if !bipod__enabled
    return

  var humanTm : float3x4
  location_toTM(human_net_phys.phys.previousState.location, humanTm)

  let aimAngle = dir_to_angles(human_net_phys.phys.appliedCT.wishShootDir)

  var tmpPitchLimit : float2
  bipod_update_height(human_net_phys, false,
                      humanTm, bipod__isCrawl, aimAngle.y,
                      bipod__anchorPos, bipod__anchorHeight, bipod__anchorOffset, tmpPitchLimit)

let
  BIPOD_MAX_AWAY_DIST               = 0.20
  BIPOD_MAX_AWAY_DIST_OFF           = 1.80
  BIPOD_MAX_AWAY_DIST_OFF_Y_MOUNT   = 0.70
  BIPOD_MAX_AWAY_DIST_OFF_Y_WEAPON  = 0.45

  BIPOD_MAX_AWAY_DIST_SQ     = square(BIPOD_MAX_AWAY_DIST)
  BIPOD_MAX_AWAY_DIST_OFF_SQ = square(BIPOD_MAX_AWAY_DIST_OFF)

  BIPOD_WEAPON_HEIGHT_SCALE  = 0.6
  BIPOD_WEAPON_HEIGHT_BASE   = 0.7
  BIPOD_WEAPON_HEIGHT_CRAWL  = 0.1

  BIPOD_APPROACH_DIST                = 0.30
  BIPOD_MIN_DIST_FROM_WISH_POS       = 0.02
  BIPOD_PREVALIDATION_MOVE_SPEED     = 15.
  BIPOD_MOVE_SPEED                   = 45.
  BIPOD_MOVE_SPEED_CRAWL             = 20.

  BIPOD_MIN_WISHPOS_X_OFFSET = 0.7
  BIPOD_BODY_DIR_OFFSET        = 0.14

  BIPOD_SPHERE_CAST_HEIGHT   = 0.35
  BIPOD_SPHERE_CAST_RAD      = 0.35
  BIPOD_SPHERE_CAST_OFFSET   = 0.2

def turn_off_bipod_effectors(var animchar_effectors__effectorsState : Object)
  var weaponAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "weapon.attach")
  if weaponAttachEffector != null
    weaponAttachEffector.weight = 0.
  var clavicleAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.clavicle.attach")
  if clavicleAttachEffector != null
    clavicleAttachEffector.weight = 0.
  clavicleAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.clavicle.attach")
  if clavicleAttachEffector != null
    clavicleAttachEffector.weight = 0.

[es(tag=gameClient, track=bipod__enabled, REQUIRE=hero)]
def turn_off_bipod_weapon_attach_effector(evt : Event;
                                          bipod__enabled : bool;
                                          var animchar_effectors__effectorsState : Object)
  if !bipod__enabled
    turn_off_bipod_effectors(animchar_effectors__effectorsState)

[es(tag=gameClient, REQUIRE=watchedByPlr, on_disappear)]
def turn_off_bipod_effectors_on_soldier_disappear(evt : Event; var animchar_effectors__effectorsState : Object)
  turn_off_bipod_effectors(animchar_effectors__effectorsState)


def bipod_weapon_placing_update(eid : EntityId; shootDir : float3)
  query(eid) <| $ [es] (transform : float3x4;
                        bipod__enabled : bool;
                        bipod__anchorPos : float3;
                        bipod__anchorOffset : float3;
                        bipod__anchorHeight : float;
                        bipod__validateTimer : float;
                        human_weap__isReloadRequested : bool;
                        var animchar_effectors__effectorsState : Object)
    var weaponAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "weapon.attach")
    if weaponAttachEffector == null
      return
    if !bipod__enabled || bipod__validateTimer > 0. || human_weap__isReloadRequested
      weaponAttachEffector.weight = 0.
      return

    let aimAngle = dir_to_angles(shootDir)
    let bipodDir = normalize(float3(shootDir.x, 0., shootDir.z))
    

    var wantedPos = bipod__anchorPos
    wantedPos += float3(0., bipod__anchorHeight, 0.) * cos(aimAngle.y)
    wantedPos -= float3(bipodDir.x, 0., bipodDir.z) * sin(aimAngle.y) * bipod__anchorHeight
    wantedPos -= geomtree_calc_optimal_wofs(transform[3])

    var weaponTm = IDENT_TM
    weaponTm[0] = shootDir
    weaponTm[1] = normalize(cross(normalize(cross(weaponTm[0], float3(0f, 1f, 0f))), weaponTm[0]))
    weaponTm[2] = normalize(cross(weaponTm[0], weaponTm[1]))
    weaponTm[3] = wantedPos - weaponTm * bipod__anchorOffset

    var tmForAnimcharNode = IDENT_TM
    tmForAnimcharNode[2] = weaponTm[1]
    tmForAnimcharNode[1] = -weaponTm[2]
    tmForAnimcharNode[0] = -weaponTm[0]
    tmForAnimcharNode[3] = weaponTm[3]

    weaponAttachEffector.position = tmForAnimcharNode[3]
    weaponAttachEffector.wtm = tmForAnimcharNode
    weaponAttachEffector.weight = 1.

[es(tag=gameClient, REQUIRE=hero, after=update_phys_es, before=(bipod_weapon_placing_update_hero, animchar_es))]
def bipod_hand_effector(info : ParallelUpdateFrameDelayed;
                        isTpsView : bool;
                        bipod__enabled : bool;
                        human_weap__isReloadRequested : bool;
                        human_weap__currentGunEid : EntityId;
                        bipod__validateTimer : float;
                        transform : float3x4;
                        bipod__lClavicleGunRelTm : float3x4;
                        bipod__rClavicleGunRelTm : float3x4;
                        var animchar_effectors__effectorsState : Object)
  var gunTm = IDENT_TM
  var rClavicleAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "r.clavicle.attach")
  var lClavicleAttachEffector = getNullableRW_EffectorData(animchar_effectors__effectorsState, "l.clavicle.attach")
  if !bipod__enabled || bipod__validateTimer > 0. || human_weap__isReloadRequested || isTpsView
    if rClavicleAttachEffector != null
      rClavicleAttachEffector.weight = 0.
    if lClavicleAttachEffector != null
      lClavicleAttachEffector.weight = 0.
  elif get_gun_tm(human_weap__currentGunEid, gunTm)
    if rClavicleAttachEffector != null
      var rClavicleWtm = gunTm * bipod__rClavicleGunRelTm
      rClavicleWtm[3] -= geomtree_calc_optimal_wofs(transform[3])

      rClavicleAttachEffector.weight = 1.
      rClavicleAttachEffector.position = rClavicleWtm[3]
      rClavicleAttachEffector.wtm = rClavicleWtm
    if lClavicleAttachEffector != null
      var clavicleWtm = gunTm * bipod__lClavicleGunRelTm
      clavicleWtm[3] -= geomtree_calc_optimal_wofs(transform[3])

      lClavicleAttachEffector.weight = 1.
      lClavicleAttachEffector.position = clavicleWtm[3]
      lClavicleAttachEffector.wtm = clavicleWtm

[es(tag=gameClient, REQUIRE=hero, REQUIRE_NOT=isReplayObserved, after=update_phys_es, before=animchar_es)]
def bipod_weapon_placing_update_hero(info : ParallelUpdateFrameDelayed; eid : EntityId; human_net_phys : HumanActor)
  bipod_weapon_placing_update(eid, human_net_phys.phys.producedCT.wishLookDir)

[es(track=(bipod__enabled, isTpsView, possessedByPlr, isAlive), on_appear, on_disappear, tag=gameClient)]
def animchar_visibility_in_bipod_state(evt : Event;
                                       eid aka human_eid : EntityId;
                                       bipod__enabled : bool;
                                       isTpsView : bool;
                                       isAlive : bool;
                                       attaches_list : EidList;
                                       possessedByPlr : EntityId;
                                       animchar : AnimcharBaseComponent;
                                       transform : float3x4;
                                       bipod__animcharCutSphereRadius : float;
                                       bipod__cutSphereOffset : float3;
                                       var bipod__animcharWasHidden : bool&)
  let shouldHide = (bipod__enabled && isAlive && !isTpsView  && possessedByPlr == get_local_player_eid())
  if bipod__animcharWasHidden == shouldHide
    return

  bipod__animcharWasHidden = shouldHide

  let hideCounter = shouldHide ? 1 : -1
  for attachEid in attaches_list
    query(attachEid) <| $ [es(REQUIRE=hide_counter, REQUIRE_NOT=gun__visible)] (attaches_list : EidList const? = null;
                                                                                bipodDontHideAttach : Tag const? = null;
                                                                                bipodDontHideAttachButChildren : Tag const? = null)
      if bipodDontHideAttach == null
        item_change_hide_counter(attachEid, hideCounter)
      elif bipodDontHideAttachButChildren != null && attaches_list != null
        for childEid in *attaches_list
          item_change_hide_counter(childEid, hideCounter)
    query(attachEid) <| $ [es] (var gun__visible : bool&; human_gun_attached : bool)
      if !human_gun_attached
        gun__visible = !shouldHide

  if shouldHide
    let nodeIdx = *animchar.nodeTree |> geomtree_findNodeIndex("Bip01 Spine1")
    var tm = IDENT_TM
    tm[3] = geomtree_getNodeWpos(*animchar.nodeTree, nodeIdx)
    tm[3] += rotate(transform, bipod__cutSphereOffset)
    createEntity("bipod_cut_sphere") <| $(var init : ComponentsInitializer)
      set(init, "human_target", human_eid)
      set(init, "transform", tm)
      set(init, "radius", bipod__animcharCutSphereRadius)
  else
    query() <| $ [es(REQUIRE=bipodCutSphere)] (eid aka sphere_eid : EntityId;
                                               human_target : EntityId)
      if human_target == human_eid
        destroyEntity(sphere_eid)

[es(after=update_phys_es, before=animchar_es, REQUIRE_NOT=(hero, deadEntity))]
def bipod_weapon_placing_update_non_hero(info : ParallelUpdateFrameDelayed; eid : EntityId; human_net_phys : HumanActor)
  bipod_weapon_placing_update(eid, human_net_phys.phys.appliedCT.wishShootDir)

[es(after=update_phys_es, before=animchar_es, REQUIRE=isReplayObserved)]
def bipod_weapon_placing_update_replay(info : ParallelUpdateFrameDelayed; eid : EntityId; human_net_phys : HumanActor)
  bipod_weapon_placing_update(eid, human_net_phys.phys.appliedCT.wishShootDir)

[es]
def human_attached_gun_update_phys(evt : CmdPostPhysUpdate;
                                   human_attached_gun__attachedGunEid : EntityId;
                                   bipod__enabled : bool;
                                   var human_net_phys : HumanActor&)
  human_net_phys.phys.currentState |> human_phys_state_set_attachedToExternalGun(!!human_attached_gun__attachedGunEid || bipod__enabled)

def private check_human_collides_with_ri(transform : float3x4; dir : float3; height : float)
  let sphereFrom = transform[3] + float3(0.0, BIPOD_SPHERE_CAST_HEIGHT + BIPOD_SPHERE_CAST_RAD, 0.0) + dir * BIPOD_SPHERE_CAST_OFFSET
  let sphereTo = sphereFrom + float3(0.0, height, 0.0)

  var tmp = 0
  var queryOut = ShapeQueryOutput()
  sphere_cast_land(sphereFrom, sphereTo, BIPOD_SPHERE_CAST_RAD, queryOut)
  sphere_query_ri(sphereFrom, sphereTo, BIPOD_SPHERE_CAST_RAD, queryOut, -1, null) <| $(desc : RendInstDesc; t : float)
    if desc.cellIdx == 0 && t < 0.0
      tmp += 1
    return true
  return abs(queryOut.t - 1.0) > 0.001

[es(before=after_net_phys_sync)]
def bipod_human_pre_phys_act_es(evt : CmdPrePhysUpdate;
                                bipod__anchorPos : float3;
                                bipod__anchorDir : float3;
                                bipod__anchorHeight : float;
                                bipod__anchorOffset : float3;
                                bipod__anchorNormal : float3;
                                bipod__isCrawl : bool;
                                transform : float3x4;
                                bipod__fpvCorrectionBodyOffset : float2 = float2(0.0, 0.12);
                                bipod__fpvCorrectionBodyOffsetCrawl : float2 = float2(0.0, 0.1);
                                human_cam__calculatedOffset : DPoint3 const?;
                                human_cam__offsetMult : float = 1.0;
                                var bipod__enabled : bool&;
                                var bipod__offsetMult : float&;
                                var bipod__pitchLimit : float2&;
                                var bipod__validateTimer : float&;
                                var human_net_phys : HumanActor&)
  if !bipod__enabled
    return

  if (human_net_phys.phys.currentState.moveState == HUMoveState.EMS_WALK ||
      human_net_phys.phys.currentState.moveState == HUMoveState.EMS_SPRINT)
    bipod__enabled = false
    return

  let worldMountPos = bipod__anchorPos + float3(0.0, bipod__anchorHeight, 0.0)
  let aimAngle = dir_to_angles(human_net_phys.phys.appliedCT.wishShootDir)

  if bipod__validateTimer < 0.
    let bodyWeaponHeight = (transform[3].y + (bipod__isCrawl ?
                            BIPOD_WEAPON_HEIGHT_CRAWL : BIPOD_WEAPON_HEIGHT_BASE + human_net_phys.phys.currentState.height * BIPOD_WEAPON_HEIGHT_SCALE))
    let worldWeaponHeight = worldMountPos.y - bipod__anchorOffset.x * sin(aimAngle.y)
    let distMount = bodyWeaponHeight - worldMountPos.y
    let distWeapon = bodyWeaponHeight - worldWeaponHeight
    if abs(distMount) > BIPOD_MAX_AWAY_DIST_OFF_Y_MOUNT || abs(distWeapon) > BIPOD_MAX_AWAY_DIST_OFF_Y_WEAPON
      bipod__enabled = false
      return
  else
    bipod__validateTimer -= evt.dt

  var humanTm : float3x4
  location_toTM(human_net_phys.phys.previousState.location, humanTm)
  let humanItm = inverse(humanTm)

  var gunTm : float3x4
  calc_gun_tm(gunTm, human_net_phys, humanTm, aimAngle.y)
  if human_cam__calculatedOffset != null
    gunTm[3] += float3(*human_cam__calculatedOffset * human_cam__offsetMult)

  let weaponAnchorWorldPos = gunTm * bipod__anchorOffset

  let curPos = float3(human_net_phys.phys.currentState.location.P)
  let offset = -(humanItm * weaponAnchorWorldPos)
  var wishPos = calc_human_pos(aimAngle.x, worldMountPos, offset, bipod__anchorNormal)
  wishPos.y = curPos.y

  let offDist = sin(aimAngle.y) * bipod__anchorHeight
  wishPos.x -= bipod__anchorDir.x * offDist
  wishPos.z -= bipod__anchorDir.z * offDist

  let fpvOffset = bipod__isCrawl ? bipod__fpvCorrectionBodyOffsetCrawl : bipod__fpvCorrectionBodyOffset
  var fpvOffsetX = fpvOffset.x
  var rotateRadius = distance(worldMountPos.xz, wishPos.xz)
  if rotateRadius < BIPOD_MIN_WISHPOS_X_OFFSET
    fpvOffsetX -= BIPOD_MIN_WISHPOS_X_OFFSET - rotateRadius
  wishPos += humanTm[0] * fpvOffsetX
  rotateRadius = distance(worldMountPos.xz, wishPos.xz)

  if bipod__isCrawl
    bipod__offsetMult = safediv(BIPOD_MIN_ROTATE_RADIUS_CRAWL, clamp(rotateRadius, BIPOD_MIN_ROTATE_RADIUS_CRAWL, BIPOD_MAX_ROTATE_RADIUS_CRAWL))
  else
    bipod__offsetMult = safediv(BIPOD_MIN_ROTATE_RADIUS, clamp(rotateRadius, BIPOD_MIN_ROTATE_RADIUS, BIPOD_MAX_ROTATE_RADIUS))
  wishPos += humanTm[2] * fpvOffset.y

  human_net_phys.phys.currentState.velocity = float3(0.f)
  human_net_phys.phys.currentState.breathOffset = float2(0.f)
  human_net_phys.phys.currentState.moveState = HUMoveState.EMS_STAND

  let distSq = distance_sq(wishPos.xz, curPos.xz)

  if distSq > square(BIPOD_MIN_DIST_FROM_WISH_POS)
    let moveDir = wishPos - curPos
    var speed = BIPOD_PREVALIDATION_MOVE_SPEED
    if bipod__validateTimer < 0. || distSq < square(BIPOD_APPROACH_DIST)
      if distSq > BIPOD_MAX_AWAY_DIST_OFF_SQ
        bipod__enabled = false
        return
      speed = length(moveDir) * (bipod__isCrawl ? BIPOD_MOVE_SPEED_CRAWL : BIPOD_MOVE_SPEED)
    let moveVel = normalize(moveDir) * min(speed, safediv(BIPOD_APPROACH_DIST, evt.dt))
    if bipod__isCrawl || !check_human_collides_with_ri(transform, normalize(moveVel), human_net_phys.phys.currentState.height)
      human_net_phys.phys.currentState.velocity = moveVel

  bipod_update_height(human_net_phys, true, humanTm, bipod__isCrawl, aimAngle.y,
                      bipod__anchorPos, bipod__anchorHeight, bipod__anchorOffset, bipod__pitchLimit)


[es(before=after_net_phys_sync)]
def bipod_human_post_phys_act_es(evt : CmdPostPhysUpdate;
                                 transform : float3x4;
                                 bipod__anchorPos : float3;
                                 bipod__anchorHeight : float;
                                 bipod__enabled : bool;
                                 bipod__isCrawl : bool;
                                 bipod__fpvCorrectionBodyOffset : float2 = float2(0.0, 0.12);
                                 bipod__fpvCorrectionBodyOffsetCrawl : float2 = float2(0.0, 0.1);
                                 var bipod__prevBodyDirYaw : float&;
                                 var bipod__prevBodyDirYawDelta : float&;
                                 var human_net_phys : HumanActor&)
  if !bipod__enabled
    return

  let fpvOffset = bipod__isCrawl ? bipod__fpvCorrectionBodyOffsetCrawl : bipod__fpvCorrectionBodyOffset
  let worldMountPos = bipod__anchorPos + float3(0.0, bipod__anchorHeight, 0.0)
  assume bodyOrientDir = human_net_phys.phys.currentState.bodyOrientDir

  var newBodyDir = worldMountPos - (transform[3] - transform[2] * (fpvOffset.y + BIPOD_BODY_DIR_OFFSET))
  newBodyDir.y = 0.0
  newBodyDir = normalize(newBodyDir)
  bodyOrientDir = float2(newBodyDir.x, newBodyDir.z)

  let newBodyYaw = dir_to_angles(float3(newBodyDir.x, 0.0, newBodyDir.z)).x
  bipod__prevBodyDirYawDelta = safediv(norm_s_ang(newBodyYaw - bipod__prevBodyDirYaw), evt.dt)
  bipod__prevBodyDirYaw = dir_to_angles(float3(newBodyDir.x, 0.0, newBodyDir.z)).x

[es(tag=server)]
def human_place_bipod_server_es(evt : RequestBipodPlacing;
                                var bipod__enabled : bool&;
                                var bipod__isCrawl : bool&;
                                var bipod__anchorPos : float3&;
                                var bipod__anchorDir : float3&;
                                var bipod__anchorHeight : float&;
                                var bipod__anchorOffset : float3&;
                                var bipod__anchorNormal : float3&;
                                var bipod__anchorYawLimit : float2&;
                                var bipod__recoilMult : float&;
                                var bipod__pitchLimit : float2&;
                                var bipod__validateTimer : float&;
                                var bipod__lastValidAngle : float2&)
  bipod__enabled        = evt.enabled
  bipod__isCrawl        = evt.isCrawl
  bipod__anchorPos      = evt.anchorPos
  bipod__anchorDir      = evt.anchorDir
  bipod__lastValidAngle = dir_to_angles(bipod__anchorDir)
  bipod__anchorHeight   = evt.anchorHeight
  bipod__anchorOffset   = evt.anchorOffset
  bipod__anchorNormal   = evt.anchorNormal
  bipod__anchorYawLimit = evt.anchorYawLimit
  bipod__recoilMult     = clamp(evt.recoilMult, 0.0, 1.0)

  if bipod__enabled
    bipod__pitchLimit     = float2(BIPOD_DEFAULT_PITCH_MIN, BIPOD_DEFAULT_PITCH_MAX)
    bipod__validateTimer  = BIPOD_WAIT_BEFORE_VALIDATE


def trace_bipod_attached_ri(pos)
  var riDesc = RendInstDesc()
  var norm : float3
  var matId = PHYSMAT_INVALID
  let traceDir = float3(0, -1, 0) 
  var minHeight = 1.0
  let res = traceray_normalized(pos, traceDir, minHeight, matId, norm, ETF_RI, riDesc, -1)
  if res && riDesc.isValid
    return int(riDesc.riExtraHandle)
  return -1








[es(tag=server, track=bipod__enabled)]
def human_bipod_attached_to_ri_es(evt : Event; bipod__enabled : bool; bipod__placePos : float3; var bipod__attachedToRi : int&)
  if !bipod__enabled
    bipod__attachedToRi = -1
    return

  bipod__attachedToRi = trace_bipod_attached_ri(bipod__placePos)
