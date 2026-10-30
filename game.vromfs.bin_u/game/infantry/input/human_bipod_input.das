require ecs
require app
require net
require DagorMath
require DagorMathUtils
require math.base
require math.ang
require Dacoll

require %appGame.wt_events
require %appGame.infantry.es.bipod_common
require WTInput
require DngHuman
require %game.events
require %game.input.input_events
require DagorDataBlock
require hud

let
  BIPOD_BODY_DIR_CLAMP_MOVE_EXTRA_ANGLE = 10.
  BIPOD_MIN_MOVING_BODY_DIR_YAW_DELTA   = 0.2
  BIPOD_AIM_BODY_DIR_DEVIATION_X        = 0.5


def private next_mount_point(from_point : int; skip_point : int; mount_points_num : int) : int
  let next = (from_point + 1) % mount_points_num
  return next == skip_point ? (next + 1) % mount_points_num : next


def private set_mounted_point(gun_eid : EntityId; mount_point : int)
  query(gun_eid) <| $ [es] (var gun__curMountPoint : int&)
    gun__curMountPoint = mount_point


def private try_mount_bipod(eid : EntityId; mount_point : int) : bool
  var mounted = false
  query(eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                        human__aimTm : float3x4;
                        human_input__aimAngle : float2;
                        human_net_phys : HumanActor;
                        human_cam__calculatedOffset : DPoint3 const?;
                        human_cam__offsetMult : float = 1.0;
                        var human_input__standState : int&;
                        var bipod__standStateOnMount : int&;
                        var bipod__placeable : bool&;
                        var bipod__placeCrawl : bool&;
                        var bipod__placePos : float3&;
                        var bipod__placeHeight : float&;
                        var bipod__placeOffset : float3&;
                        var bipod__placeNormal : float3&;
                        var bipod__placeYawLimit : float&;
                        var bipod__placeRecoilMult : float&;
                        var bipod__placeIsRest : bool&;
                        var bipod__enabled : bool&;
                        var bipod__validateTimer : float&;
                        var bipod__isCrawl : bool&;
                        var bipod__anchorPos : float3&;
                        var bipod__anchorDir : float3&;
                        var bipod__anchorHeight : float&;
                        var bipod__anchorOffset : float3&;
                        var bipod__anchorNormal : float3&;
                        var bipod__anchorYawLimit : float2&;
                        var bipod__recoilMult : float&;
                        var bipod__isRest : bool&;
                        var bipod__pitchLimit : float2&;
                        var bipod__prevAngle : float2&;
                        var bipod__lastValidAngle : float2&;
                        var bipod__offsetMult : float&)
    let saved_placeable       = bipod__placeable
    let saved_placeCrawl      = bipod__placeCrawl
    let saved_placePos        = bipod__placePos
    let saved_placeHeight     = bipod__placeHeight
    let saved_placeOffset     = bipod__placeOffset
    let saved_placeNormal     = bipod__placeNormal
    let saved_placeYawLimit   = bipod__placeYawLimit
    let saved_placeRecoilMult = bipod__placeRecoilMult
    let saved_placeIsRest     = bipod__placeIsRest

    let isRemount = bipod__enabled
    solve_bipod_placing(eid, true, mount_point)

    if isRemount && !bipod__placeable
      return

    if saved_placeable && !bipod__placeable
      bipod__placeable       = saved_placeable
      bipod__placeCrawl      = saved_placeCrawl
      bipod__placePos        = saved_placePos
      bipod__placeHeight     = saved_placeHeight
      bipod__placeOffset     = saved_placeOffset
      bipod__placeNormal     = saved_placeNormal
      bipod__placeYawLimit   = saved_placeYawLimit
      bipod__placeRecoilMult = saved_placeRecoilMult
      bipod__placeIsRest     = saved_placeIsRest

    if !bipod__placeable
      return

    let isCrawl = human_input__standState == int(HumanPhysControlType.HCT_CRAWL)
    if isCrawl != bipod__placeCrawl
      return

    bipod__enabled        = true
    bipod__isCrawl        = bipod__placeCrawl
    bipod__recoilMult     = bipod__placeRecoilMult
    bipod__isRest         = bipod__placeIsRest
    bipod__anchorPos      = bipod__placePos
    bipod__anchorDir      = calc_anchor_dir(bipod__isCrawl, bipod__placeNormal, human__aimTm)
    bipod__lastValidAngle = dir_to_angles(bipod__anchorDir)
    bipod__anchorHeight   = bipod__placeHeight
    bipod__anchorOffset   = bipod__placeOffset
    bipod__anchorNormal   = bipod__isCrawl ? bipod__placeNormal : float3(0.0, 1.0, 0.0)
    bipod__anchorYawLimit = float2(-bipod__placeYawLimit, bipod__placeYawLimit)

    var humanTm, gunTm : float3x4
    location_toTM(human_net_phys.phys.previousState.location, humanTm)
    calc_gun_tm(gunTm, human_net_phys, humanTm, 0.)

    if human_cam__calculatedOffset != null
      gunTm[3] += float3(*human_cam__calculatedOffset * human_cam__offsetMult)

    let rotateRadius = length(inverse(humanTm) * gunTm * bipod__anchorOffset)
    bipod__offsetMult = safediv(BIPOD_MIN_INIT_RADIUS, clamp(rotateRadius, BIPOD_MIN_INIT_RADIUS, BIPOD_MAX_INIT_RADIUS))
    if bipod__isCrawl
      bipod__anchorYawLimit *= bipod__offsetMult

    bipod__pitchLimit     = float2(BIPOD_DEFAULT_PITCH_MIN, BIPOD_DEFAULT_PITCH_MAX)
    bipod__validateTimer  = BIPOD_WAIT_BEFORE_VALIDATE

    if !isRemount
      bipod__standStateOnMount = human_input__standState
      if human_input__standState == int(HumanPhysControlType.HCT_CROUCH)
        human_input__standState = 0

    bipod__prevAngle  = human_input__aimAngle
    set_mounted_point(human_weap__currentGunEid, get_int(eid, "bipod__placeMountPoint") ?? -1)
    mounted = true
  return mounted


def private reset_bipod_scan_results(eid : EntityId)
  query(eid) <| $ [es] (var bipod__placeable : bool&;
                        var bipod__scanMountPoint : int&;
                        var bipod__availableMountPoints : int&)
    bipod__placeable = false
    bipod__scanMountPoint = -1
    bipod__availableMountPoints = 0


def private remount_bipod_on_next_mount_point(eid : EntityId; gun_eid : EntityId)
  var mountPointsNum = 0
  var candidate = -1
  query(gun_eid) <| $ [es] (@shared_comp gun__mountPoints : Array; gun__curMountPoint : int)
    mountPointsNum = length(gun__mountPoints)
    candidate = gun__curMountPoint
  for _i in range(1, mountPointsNum)
    candidate = next_mount_point(candidate, -1, mountPointsNum)
    if try_mount_bipod(eid, candidate)
      reset_bipod_scan_results(eid)
      return


[es(tag=input, REQUIRE=hero, before=human_common_input_action_triggered_es)]
def human_bipod_input_reset_es(evt : EventOnKeyDown;
                               var bipod__enabled : bool&;
                               var bipod__placeable : bool&;
                               var bipod__standStateOnMount : int&;
                               input__enabled : bool = true)
  if !input__enabled
    return

  let action = int(evt.eventId)
  if action == int(ShortcutEventId.ID_HUMAN_JUMP) || action == int(ShortcutEventId.ID_HUMAN_MELEE) || action == int(ShortcutEventId.ID_HUMAN_CRAWL) || action == int(ShortcutEventId.ID_HUMAN_CROUCH)
    bipod__enabled = false
    bipod__placeable = false
    if action == int(ShortcutEventId.ID_HUMAN_JUMP) || action == int(ShortcutEventId.ID_HUMAN_CRAWL)
      bipod__standStateOnMount = 0


[es(tag=input, REQUIRE=hero)]
def change_bipod_selected_mount_point(evt : EventOnKeyDown;
                                      eid : EntityId;
                                      bipod__enabled : bool;
                                      human_weap__currentGunEid : EntityId)
  if bipod__enabled && int(evt.eventId) == int(ShortcutEventId.ID_HUMAN_CHANGE_BIPOD_MOUNT_POINT)
    remount_bipod_on_next_mount_point(eid, human_weap__currentGunEid)


[es(tag=input, REQUIRE=hero, after=human_common_input_action_triggered_es)]
def human_bipod_input_action_triggered_es(evt : EventOnKeyDown;
                                          eid : EntityId;
                                          input__enabled : bool = true;
                                          var bipod__enabled : bool&)
  if !input__enabled || int(evt.eventId) != int(ShortcutEventId.ID_HUMAN_BIPODTOGGLE)
    return

  if bipod__enabled
    bipod__enabled = false
    return

  try_mount_bipod(eid, -1)

[es(tag=input, REQUIRE=hero, before=start_async_phys_sim_es)]
def human_bipod_scan_mount_points_es(info : ParallelUpdateFrameDelayed;
                                     eid : EntityId;
                                     bipod__enabled : bool;
                                     bipod__checkPlacingInterval : float;
                                     human_weap__currentGunEid : EntityId;
                                     var bipod__nextCheckPlacingAtTime : float&;
                                     bipod__solveForPos : float3;
                                     bipod__solveForDir : float3;
                                     var bipod__scanForPos : float3&;
                                     var bipod__scanForDir : float3&;
                                     var bipod__scanMountPoint : int&;
                                     var bipod__availableMountPoints : int&)
  if !bipod__enabled
    return

  if bipod__nextCheckPlacingAtTime > 0.0 && bipod__nextCheckPlacingAtTime >= info.curTime
    return
  bipod__nextCheckPlacingAtTime = info.curTime + bipod__checkPlacingInterval

  var mountPointsNum = 0
  var curMountPoint = -1
  query(human_weap__currentGunEid) <| $ [es] (@shared_comp gun__mountPoints : Array; gun__curMountPoint : int)
    mountPointsNum = length(gun__mountPoints)
    curMountPoint = gun__curMountPoint
  if mountPointsNum < 2 || curMountPoint < 0 || curMountPoint >= mountPointsNum
    bipod__availableMountPoints = 0
    return

  if bipod__scanMountPoint < 0 || bipod__scanMountPoint == curMountPoint
    bipod__scanMountPoint = next_mount_point(curMountPoint, curMountPoint, mountPointsNum)

  let wasIdle = is_bipod_solver_idle(eid)
  solve_bipod_placing(eid, false, bipod__scanMountPoint)
  if is_bipod_context_moved(bipod__solveForPos, bipod__solveForDir, bipod__scanForPos, bipod__scanForDir)
    bipod__availableMountPoints = 0
    bipod__scanForPos = bipod__solveForPos
    bipod__scanForDir = bipod__solveForDir
  if wasIdle || !is_bipod_solver_idle(eid)
    return

  let scannedBit = 1 << bipod__scanMountPoint
  let isPlaceable = get_bool(eid, "bipod__placeable") ?? false
  bipod__availableMountPoints = isPlaceable ? (bipod__availableMountPoints | scannedBit) : (bipod__availableMountPoints & ~scannedBit)
  bipod__scanMountPoint = next_mount_point(bipod__scanMountPoint, curMountPoint, mountPointsNum)


[es(tag=input, REQUIRE=hero, before=start_async_phys_sim_es)] 
def human_bipod_check_es(info : ParallelUpdateFrameDelayed;
                         eid : EntityId;
                         bipod__enabled : bool;
                         bipod__checkPlacingInterval : float;
                         var bipod__nextCheckPlacingAtTime : float&)
  if bipod__enabled
    return

  if bipod__nextCheckPlacingAtTime > 0.0 && bipod__nextCheckPlacingAtTime >= info.curTime
    return
  bipod__nextCheckPlacingAtTime = info.curTime + bipod__checkPlacingInterval

  solve_bipod_placing(eid, false)


[es(tag=input, REQUIRE=hero, after=human_input_es)]
def bipod_restore_stance_es(evt : UpdateStageUpdateInput;
                            bipod__enabled : bool;
                            var bipod__standStateOnMount : int&;
                            var human_input__standState : int&)
  if bipod__enabled || bipod__standStateOnMount == 0
    return
  if human_input__standState == 0
    human_input__standState = bipod__standStateOnMount
  bipod__standStateOnMount = 0


[es(tag=input, REQUIRE=hero, after=human_input_es)]
def bipod_input_es(evt : UpdateStageUpdateInput;
                   bipod__enabled : bool;
                   bipod__isCrawl : bool;
                   bipod__validateTimer : float;
                   human_weap__isReloading : bool;
                   var human_input__standState : int&;
                   var human_net_phys : HumanActor&)
  if !bipod__enabled || bipod__validateTimer > 0. || human_weap__isReloading
    return

  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, true)
  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, false)
  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, false)
  if bipod__isCrawl
    human_input__standState = int(HumanPhysControlType.HCT_CRAWL)
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, true)

[es(tag=input, REQUIRE=hero, after=human_input_es)]
def bipod_ads_focus_input_es(evt : UpdateStageUpdateInput;
                             bipod__enabled : bool;
                             human_weap__currentGunEid : EntityId;
                             human_input__forceAim : bool = false;
                             input__enabled : bool = true;
                             var bipod__adsFocused : bool&)
  let isAimBlockedByGun = !(get_bool(human_weap__currentGunEid, "gun__canAim") ?? true)
  let aim = (is_shortcut_down(ShortcutEventId.ID_HUMAN_AIM) || human_input__forceAim) && !isAimBlockedByGun
  let focused = input__enabled && bipod__enabled && aim
  if bipod__adsFocused != focused
    bipod__adsFocused = focused

def is_bipod_aim_angle_collide(soldier_eid : EntityId)
  var angleCollide = false
  query(soldier_eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                                bipod__anchorDir : float3;
                                bipod__anchorHeight : float;
                                bipod__anchorPos : float3;
                                human_input__aimAngle : float2;
                                bipod__anchorOffset : float3)
    let shootDir = angles_to_dir(human_input__aimAngle)
    let bipodDir = normalize(float3(shootDir.x, 0., shootDir.z))
    let bipodAngle = dir_to_angles(bipod__anchorDir)

    var rotationPos = bipod__anchorPos
    rotationPos += float3(0., bipod__anchorHeight, 0.) * cos(human_input__aimAngle.y)
    rotationPos -= float3(bipodDir.x, 0., bipodDir.z) * sin(human_input__aimAngle.y) * bipod__anchorHeight
    var weaponTm = IDENT_TM
    weaponTm[0] = shootDir
    weaponTm[1] = normalize(cross(normalize(cross(weaponTm[0], float3(0f, 1f, 0f))), weaponTm[0]))
    weaponTm[2] = normalize(cross(weaponTm[0], weaponTm[1]))
    weaponTm[3] = rotationPos - weaponTm * bipod__anchorOffset

    let barrelTipOffset = get_Point3(human_weap__currentGunEid, "gun__barrelTipOffset") ?? float3(0.5, 0., 0.)
    var traceOffset = float3(0., 0.03, BIPOD_TRACE_YAW_OFFSET * sign(norm_s_ang(human_input__aimAngle.x - bipodAngle.x)))
    traceOffset = rotate(weaponTm, traceOffset)

    let toPos = weaponTm * barrelTipOffset + traceOffset
    var fromPos = weaponTm[3] + traceOffset
    let dir = normalize(toPos - fromPos)
    fromPos -= dir * BIPOD_TRACE_BACK_OFFSET

    var t = length(fromPos - toPos)
    var norm : float3

    if !traceray_normalized(fromPos, dir, t, norm)
      angleCollide = false
    else
      angleCollide = true
  return angleCollide

[es(tag=input, REQUIRE=hero, after=human_input_es)]
def bipod_clamp_aim_angles_es(evt : UpdateStageUpdateInput;
                              eid : EntityId;
                              human_weap__currentGunEid : EntityId;
                              bipod__enabled : bool;
                              bipod__anchorDir : float3;
                              bipod__anchorYawLimit : float2;
                              bipod__pitchLimit : float2;
                              bipod__crawlLimit : float2;
                              bipod__isCrawl : bool;
                              bipod__bodyDirClampAngles : float4 = float4(-8, 10, -85, 85);
                              bipod__bodyDirClampAnglesCrawl : float4 = float4(-10, 10, -85, 85);
                              bipod__validateTimer : float;
                              bipod__offsetMult : float;
                              var bipod__lastValidAngle : float2&;
                              var human_net_phys : HumanActor&;
                              var human_input__aimAngle : float2&;
                              var bipod__prevAngle : float2&)
  if !bipod__enabled
    return

  var yawCoef = BIPOD_ANGLE_AIMING_COEF
  var pitchCoef = BIPOD_ANGLE_AIMING_COEF
  query(human_weap__currentGunEid) <| $ [es] (gun__bipodYawSensitivity : float = BIPOD_ANGLE_AIMING_COEF; gun__bipodPitchSensitivity : float = BIPOD_ANGLE_AIMING_COEF)
    yawCoef = gun__bipodYawSensitivity
    pitchCoef = gun__bipodPitchSensitivity

  let yawDeltaMax   = evt.dt * (bipod__isCrawl ? BIPOD_MAX_YAW_PER_SECOND_CRAWL : BIPOD_MAX_YAW_PER_SECOND)
  let pitchDeltaMax = BIPOD_MAX_PITCH_PER_SECOND * evt.dt
  let yawDelta   = clamp(norm_s_ang(human_input__aimAngle.x - bipod__prevAngle.x) * yawCoef, -yawDeltaMax, yawDeltaMax)
  let pitchDelta = clamp(norm_s_ang(human_input__aimAngle.y - bipod__prevAngle.y) * pitchCoef, -pitchDeltaMax, pitchDeltaMax)
  human_input__aimAngle.x = norm_ang(bipod__prevAngle.x + yawDelta)
  human_input__aimAngle.y = norm_s_ang(bipod__prevAngle.y + pitchDelta)
  let anchorAngles = dir_to_angles(bipod__anchorDir)
  let center = norm_ang(anchorAngles.x)

  let limit  = norm_ang(float2(center + bipod__anchorYawLimit.x, center + bipod__anchorYawLimit.y))
  human_input__aimAngle.x = norm_s_ang(clamp_ang(human_input__aimAngle.x, limit))

  if bipod__isCrawl
    let minPitch = anchorAngles.y + deg_to_rad(bipod__crawlLimit.x)
    let maxPitch = anchorAngles.y + deg_to_rad(bipod__crawlLimit.y)
    human_input__aimAngle.y = clamp(human_input__aimAngle.y, minPitch, maxPitch)
  else
    human_input__aimAngle.y = clamp(human_input__aimAngle.y, deg_to_rad(bipod__pitchLimit.x), deg_to_rad(bipod__pitchLimit.y))

  if bipod__validateTimer > 0.0
    human_input__aimAngle.y = approach(human_input__aimAngle.y, 0.0, evt.dt, human_input__aimAngle.y < 0.0 ? 0.1 : 0.9)
  else
    let bodyDir = float3(human_net_phys.phys.currentState.bodyOrientDir.x, 0., human_net_phys.phys.currentState.bodyOrientDir.y)
    var clampAngles = bipod__isCrawl ? bipod__bodyDirClampAnglesCrawl : bipod__bodyDirClampAngles
    clampAngles[0] -= BIPOD_BODY_DIR_CLAMP_MOVE_EXTRA_ANGLE * bipod__offsetMult
    clampAngles[1] += BIPOD_BODY_DIR_CLAMP_MOVE_EXTRA_ANGLE * bipod__offsetMult
    let clampedAngles = clamp_angles_by_dir(human_input__aimAngle, clampAngles, bodyDir)
    if angle(clampedAngles, human_input__aimAngle) <= PI / 2.
      human_input__aimAngle = approach(human_input__aimAngle, clampedAngles, evt.dt, 0.001)
    let aimBodyDirDeviation = abs(norm_s_ang(human_input__aimAngle.x - dir_to_angles(bodyDir).x))
    if is_bipod_aim_angle_collide(eid) || aimBodyDirDeviation > BIPOD_AIM_BODY_DIR_DEVIATION_X
      human_input__aimAngle = approach(bipod__prevAngle, bipod__lastValidAngle, evt.dt, 0.1)
    else
      bipod__lastValidAngle = human_input__aimAngle

  bipod__prevAngle = human_input__aimAngle

  let aimDir = angles_to_dir(human_input__aimAngle)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(aimDir)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(aimDir)


[es(tag=input, on_event=EventComponentsDisappear, REQUIRE=(hero, human_weap__currentGunEid), track=human_weap__currentGunEid)]
def human_bipod_reset_es(evt : Event; var bipod__enabled : bool&; var bipod__placeable : bool&)
  bipod__enabled = false
  bipod__placeable = false

[es(tag=input, track=bipod__enabled)]
def human_bipod_reset_aim_es(evt : Event; eid : EntityId; bipod__enabled : bool; var human_net_phys : HumanActor)
  if !bipod__enabled
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)
    reset_bipod_scan_results(eid)

[es(tag=input, track=(isDowned, isAlive))]
def human_bipod_reset_on_death_es(evt : Event; isDowned, isAlive : bool; var bipod__enabled : bool&; var bipod__placeable : bool&)
  if isDowned || !isAlive
    bipod__enabled = false
    bipod__placeable = false

[es(tag=netClient, REQUIRE=hero, track=(bipod__enabled, bipod__anchorPos))]
def human_request_placing_es(evt : Event;
                             eid : EntityId;
                             bipod__enabled : bool;
                             bipod__isCrawl : bool;
                             bipod__anchorPos : float3;
                             bipod__anchorDir : float3;
                             bipod__anchorHeight : float;
                             bipod__anchorOffset : float3;
                             bipod__anchorNormal : float3;
                             bipod__anchorYawLimit : float2;
                             bipod__recoilMult : float;
                             bipod__isRest : bool)
  send_net_event(eid, RequestBipodPlacing(enabled        = bipod__enabled,
                                            isCrawl        = bipod__isCrawl,
                                            anchorPos      = bipod__anchorPos,
                                            anchorDir      = bipod__anchorDir,
                                            anchorHeight   = bipod__anchorHeight,
                                            anchorOffset   = bipod__anchorOffset,
                                            anchorNormal   = bipod__anchorNormal,
                                            anchorYawLimit = bipod__anchorYawLimit,
                                            recoilMult     = bipod__recoilMult,
                                            mountIsRest    = bipod__isRest))


[es(tag=input, REQUIRE=controlledHero, REQUIRE_NOT=isReplayObserved)]
def gun_bipod_mandatory_show_hint(evt : EventOnKeyDown;
                                  input__enabled : bool = true;
                                  human_weap__canOperate : bool)
  if !input__enabled || human_weap__canOperate
    return

  let action = int(evt.eventId)
  if action == int(ShortcutEventId.ID_HUMAN_SHOOT) || action == int(ShortcutEventId.ID_HUMAN_RELOAD) || action == int(ShortcutEventId.ID_HUMAN_AIM)
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:gun_needs_bipod", eventData)
