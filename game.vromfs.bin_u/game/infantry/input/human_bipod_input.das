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
require DagorSystem
require DagorDataBlock
require hud

let
  BIPOD_BODY_DIR_CLAMP_MOVE_EXTRA_ANGLE = 10.
  BIPOD_MIN_MOVING_BODY_DIR_YAW_DELTA   = 0.2
  BIPOD_AIM_BODY_DIR_DEVIATION_X        = 0.5

[es(tag=input, REQUIRE=hero, before=human_common_input_action_triggered_es)]
def human_bipod_input_reset_es(evt : EventOnKeyDown;
                               var bipod__enabled : bool&;
                               var bipod__placeable : bool&;
                               input__enabled : bool = true)
  if !input__enabled
    return

  let action = int(evt.eventId)
  if action ==  int(ShortcutEventId.ID_HUMAN_JUMP) || action ==  int(ShortcutEventId.ID_HUMAN_MELEE) || action ==  int(ShortcutEventId.ID_HUMAN_CRAWL)
    bipod__enabled = false
    bipod__placeable = false

[es(tag=input, after=human_common_input_action_triggered_es)]
def human_bipod_input_action_triggered_es(evt : EventOnKeyDown;
                                          eid : EntityId;
                                          input__enabled : bool = true;
                                          
                                          human__aimTm : float3x4;
                                          human_input__aimAngle : float2;
                                          human_net_phys : HumanActor;
                                          human_cam__calculatedOffset : DPoint3 const?;
                                          human_cam__offsetMult : float = 1.0;
                                          var human_input__standState : int&;
                                          var bipod__placeable : bool&;
                                          var bipod__placeCrawl : bool&;
                                          var bipod__placePos : float3&;
                                          var bipod__placeHeight : float&;
                                          var bipod__placeOffset : float3&;
                                          var bipod__placeNormal : float3&;
                                          var bipod__placeYawLimit : float&;
                                          var bipod__placeRecoilMult : float&;
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
                                          var bipod__pitchLimit : float2&;
                                          var bipod__prevAngle : float2&;
                                          var bipod__lastValidAngle : float2&;
                                          var bipod__offsetMult : float&)
  if !input__enabled || int(evt.eventId) != int(ShortcutEventId.ID_HUMAN_BIPODTOGGLE)
    return

  if bipod__enabled
    bipod__enabled = false
    return

  let saved_placeable       = bipod__placeable
  let saved_placeCrawl      = bipod__placeCrawl
  let saved_placePos        = bipod__placePos
  let saved_placeHeight     = bipod__placeHeight
  let saved_placeOffset     = bipod__placeOffset
  let saved_placeNormal     = bipod__placeNormal
  let saved_placeYawLimit   = bipod__placeYawLimit
  let saved_placeRecoilMult = bipod__placeRecoilMult

  solve_bipod_placing(eid, true)

  if saved_placeable && !bipod__placeable
    bipod__placeable       = saved_placeable
    bipod__placeCrawl      = saved_placeCrawl
    bipod__placePos        = saved_placePos
    bipod__placeHeight     = saved_placeHeight
    bipod__placeOffset     = saved_placeOffset
    bipod__placeNormal     = saved_placeNormal
    bipod__placeYawLimit   = saved_placeYawLimit
    bipod__placeRecoilMult = saved_placeRecoilMult

  if !bipod__placeable
    return

  let isCrawl = human_input__standState == int(HumanPhysControlType.HCT_CRAWL)
  if isCrawl != bipod__placeCrawl
    return

  bipod__enabled        = true
  bipod__isCrawl        = bipod__placeCrawl
  bipod__recoilMult     = bipod__placeRecoilMult
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

  if human_input__standState == int(HumanPhysControlType.HCT_CROUCH)
    human_input__standState = 0

  bipod__prevAngle  = human_input__aimAngle

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
def human_bipod_reset_aim_es(evt : Event; bipod__enabled : bool; var human_net_phys : HumanActor)
  if !bipod__enabled
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, false)

[es(tag=input, track=(isDowned, isAlive))]
def human_bipod_reset_on_death_es(evt : Event; isDowned, isAlive : bool; var bipod__enabled : bool&; var bipod__placeable : bool&)
  if isDowned || !isAlive
    bipod__enabled = false
    bipod__placeable = false

[es(tag=netClient, REQUIRE=hero, track=bipod__enabled)]
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
                             bipod__recoilMult : float)
  send_net_event(eid, RequestBipodPlacing(enabled        = bipod__enabled,
                                            isCrawl        = bipod__isCrawl,
                                            anchorPos      = bipod__anchorPos,
                                            anchorDir      = bipod__anchorDir,
                                            anchorHeight   = bipod__anchorHeight,
                                            anchorOffset   = bipod__anchorOffset,
                                            anchorNormal   = bipod__anchorNormal,
                                            anchorYawLimit = bipod__anchorYawLimit,
                                            recoilMult     = bipod__recoilMult))


[es(tag=input, REQUIRE=controlledHero)]
def gun_bipod_mandatory_show_hint(evt : EventOnKeyDown;
                                  input__enabled : bool = true;
                                  human_weap__canOperate : bool)
  if !input__enabled || human_weap__canOperate
    return

  let action = int(evt.eventId)
  if action == int(ShortcutEventId.ID_HUMAN_SHOOT) || action == int(ShortcutEventId.ID_HUMAN_RELOAD) || action == int(ShortcutEventId.ID_HUMAN_AIM)
    using() <| $(var eventData : DataBlock)
      hud_notify_script("hint:gun_needs_bipod", eventData)
