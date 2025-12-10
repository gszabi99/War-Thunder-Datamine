require ecs
require ecs.common
require app
require net
require math.base
require Grid
require GridCollision
require CollisionTraces
require WTInput
require DngHuman
require MPlayer
require DagorMath
require DagorMathUtils
require DagorDriver3D
require math.base
require %game.events
require %game.input.input_events
require %game.player_events
require %appGame.wt_events
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.human_use_object_common
require %appGame.infantry.es.camera_common
require Unit
require DagorSystem
require DagorDataBlock
require hud
require HumanPhys
require DaWeapons
require DngWeapon
require AnimV20
require GeomNodeTree


let DEFAULT_VERT_LOOK_ANGLE_LIMIT_DEG = float2(-72.0, 87.0)
let DEFAULT_VERT_LOOK_ANGLE_LIMIT_RAD = deg_to_rad(DEFAULT_VERT_LOOK_ANGLE_LIMIT_DEG)

let DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD = 0.7
let DEFAULT_RESET_SPRINT_MOVE_THRESHOLD = -0.1

let MOVE_THRESHOLD = 0.1f

def is_shoot_dir_blocked(actor : HumanActor)
  let isDowned = actor.phys.currentState |> human_phys_state_get_is_downed()
  let revivingCount = 0
  return isDowned && revivingCount > 0

def update_look_dir(var human_net_phys : HumanActor&;
                    var aim_angle : float2&;
                    var prev_root_direction : float3&;
                    var prev_vert_direction : float3&;
                    aim_offset : float2;
                    vert_look_angle_limit : float2;
                    persp_wk : float;
                    ax : double = 0.0lf;
                    ay : double = 0.0lf;
                    lx : float = 0.0;
                    ly : float = 0.0;
                    rotation_speed : float = -1.;
                    dt : float = 0.)

  let vertLookAngleLimit = float2(max(vert_look_angle_limit.x, -SAFE_HALF_PI),
                                  min(vert_look_angle_limit.y, SAFE_HALF_PI))
  let aimAngleUnbounded = aim_angle + float2(ax, ay) * safeinv(persp_wk)
  aim_angle.x = norm_s_ang(
    rotation_speed >= 0.
      ? move_to(aim_angle.x, renorm_ang(aimAngleUnbounded.x, aim_angle.x), dt, rotation_speed)
      : aimAngleUnbounded.x)
  aim_angle.y = clamp(aimAngleUnbounded.y, vertLookAngleLimit.x, vertLookAngleLimit.y)

  var lookAngle = aim_angle + float2(lx, ly)
  lookAngle.y = clamp(lookAngle.y, vertLookAngleLimit.x, vertLookAngleLimit.y)

  let curVertDirection = human_net_phys.phys.currentState.vertDirection
  let prevVertDirection = human_net_phys.phys.previousState.vertDirection
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, get_sync_time())

  
  let rotationBetweenStates = quat_rotation_arc(prevVertDirection, curVertDirection)
  let identQuat = quat(0.f, 0.f, 0.f, 1.f)
  let interpQuat = slerp(identQuat, rotationBetweenStates, interpK)
  let instantVertDirection = interpQuat * prevVertDirection

  let vertRotation = quat_rotation_arc(prev_vert_direction, instantVertDirection)
  prev_root_direction = vertRotation * prev_root_direction
  prev_vert_direction = instantVertDirection

  
  if !is_shoot_dir_blocked(human_net_phys)
    let shootAngle = aim_angle + aim_offset
    let dir = basis_aware_angles_to_dir(shootAngle, prev_vert_direction, prev_root_direction)
    human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(dir)

  
  let lookDir = basis_aware_angles_to_dir(lookAngle, prev_vert_direction, prev_root_direction)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_look_dir(lookDir)

  
  let rawAngleDir = basis_aware_angles_to_dir(aim_angle, prev_vert_direction, prev_root_direction)
  prev_root_direction = get_some_normal(prev_vert_direction)
  aim_angle = basis_aware_dir_to_angles(rawAngleDir, prev_vert_direction, prev_root_direction)


[es(after=(human_input_es), REQUIRE=(controlledHero, human_weap), REQUIRE_NOT=menuSoldier)]
def human_weap_update_shoot_dir_es(info : UpdateStageUpdateInput;
                                   human_weap__gunAngleTau : float;
                                   human_weap__crawlClampVertAngleRad : float2;
                                   human_weap__clampVertAngleRad : float2;
                                   human_weap__aimInertia : float2;
                                   human_weap__mortarMode : bool = false;
                                   isDowned : bool = false;
                                   isAlive : bool = true;
                                   bipod__enabled : bool = false;
                                   human_weap__extraGunSpeedOnJump : float = 0.0;
                                   isReplayObserved : Tag const?;
                                   var human_net_phys : HumanActor;
                                   var human_weap__prevGunAngles : float2&;
                                   var human_weap__gunAngleSpeed : float2&)
  if !isAlive || isDowned || human_net_phys.phys.currentState |> human_phys_state_attachedToLadder
    return

  let dt = info.dt
  var atTime = info.curTime

  
  
  assume ct = (isReplayObserved == null && human_net_phys.isLocalControl) ? human_net_phys.phys.producedCT : human_net_phys.phys.appliedCT
  if ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !ct.haveUnenqueuedHctShoot
    atTime = floor(atTime / human_net_phys.phys.timeStep) * human_net_phys.phys.timeStep

  let isForReal = true
  let wishGunDir = ct.wishShootDir
  var gunDir = wishGunDir
  let gunAnglesOffset = human_weap__aimInertia
  var gunAngles = dir_to_angles(gunDir) + gunAnglesOffset
  gunAngles.y = clamp(gunAngles.y, -SAFE_HALF_PI, SAFE_HALF_PI)
  var gunSpeedAng = gunAngles - human_weap__prevGunAngles
  gunSpeedAng.x = norm_s_ang(gunSpeedAng.x)
  let isInAir = (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0
  if human_weap__extraGunSpeedOnJump > 0.0 && isInAir
    let humanVel = human_net_phys.phys.currentState.velocity
    let dir = human_net_phys.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM) ? 1.0 : -1.0
    let extraGunSpeedOnJump = human_weap__extraGunSpeedOnJump
    gunSpeedAng.y += dir * cvt(humanVel.y, -1.0, 1.0, -extraGunSpeedOnJump, extraGunSpeedOnJump)
  let gunSpeed = gunSpeedAng * safeinv(dt)
  human_weap__gunAngleSpeed = approach(human_weap__gunAngleSpeed, gunSpeed, dt, human_weap__gunAngleTau)
  human_weap__prevGunAngles = gunAngles

  assume phys = human_net_phys.phys
  if !human_weap__mortarMode && !bipod__enabled
    let vertLimits = phys.currentState.isCrawl ? human_weap__crawlClampVertAngleRad : human_weap__clampVertAngleRad
    apply_gun_angle_offsets(phys, atTime, vertLimits, gunAngles)
  gunDir = angles_to_dir(gunAngles)
  human_net_phys.phys.producedCT |> human_control_state_set_wish_shoot_dir(gunDir)

def update_walk_dir(var actor : HumanActor&;
                    move = 0.lf;
                    strafe = 0.lf)
  actor.phys.producedCT |> human_control_state_set_walk_dir(float2(move, -strafe))

def apply_inertia(input_inertia : float;
                  var input_accum : float2&;
                  var ax : double&;
                  var ay : double&)
  let input = float2(ax, ay)
  let newInput = input * (1.0 - input_inertia)
  let accumulatedInput = input_accum * (1.0 - input_inertia)
  input_accum *= input_inertia
  input_accum += input - newInput
  ax = double(newInput.x + accumulatedInput.x)
  ay = double(newInput.y + accumulatedInput.y)

def fix_changed_hero_input(dt : float;
                           var human_input__hasValidState : bool&;
                           var human_input__standState : int&;
                           var human_net_phys : HumanActor&;
                           var aim_angle : float2&;
                           var human_input__lookAngle : float2&;
                           var human_input__aimInputAccum : float2&;
                           var human_input__moveInputAccum : float2&;
                           var human_net_phys__prevRootDir : float3&;
                           var human_net_phys__prevVertDir : float3&;
                           isTpsView : bool;
                           human_input__aimInputInertia : float;
                           human_input__moveInputInertia : float;
                           human_input__lookAngleTau : float;
                           human_input__perspWk : float;
                           human_input__forceLookMode : bool;
                           human_input__blockLookModeCounter : int;
                           aim_offset : float2&;
                           human_input__resetSprintMovementThreshold : float = DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD;
                           human_input__resetSprintMoveThreshold : float = DEFAULT_RESET_SPRINT_MOVE_THRESHOLD)
  assume phys = human_net_phys.phys
  assume ct = phys.producedCT
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_JUMP, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_RELOAD, false)
  ct |> human_control_state_set_throw_state(false, HumanControlThrowSlot.HCTS_SLOT0)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_THROW_BACK, false)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, false)

  let isCrouch = phys.previousState.isCrouch
  let isCrawl = phys.previousState.isCrawl
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
  ct |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)

  if isCrawl
    human_input__standState = int(HumanPhysControlType.HCT_CRAWL)
  elif isCrouch
    human_input__standState = int(HumanPhysControlType.HCT_CROUCH)
  else
    human_input__standState = 0

  update_movement(dt,
                  human_input__perspWk,
                  human_input__forceLookMode,
                  human_input__blockLookModeCounter,
                  aim_offset,
                  true, true, float2(0.5, 0.5),
                  DEFAULT_VERT_LOOK_ANGLE_LIMIT_RAD, -1.0, 1.0, 1.0,
                  human_input__resetSprintMovementThreshold,
                  human_input__resetSprintMoveThreshold,
                  human_input__lookAngleTau,
                  human_input__aimInputInertia,
                  human_input__moveInputInertia,
                  isTpsView,
                  human_net_phys, aim_angle,
                  human_input__lookAngle,
                  human_input__aimInputAccum,
                  human_input__moveInputAccum,
                  human_net_phys__prevRootDir,
                  human_net_phys__prevVertDir)
  human_input__hasValidState = true

def set_ct_controlbit(var human_net_phys : HumanActor&;
                      state : HumanPhysControlType;
                      action : ShortcutEventId)
  
  let value = is_shortcut_down(action)
  human_net_phys.phys.producedCT |> human_control_state_set_control_bit(state, value)

def update_movement(dt : float;
                    human_input__perspWk : float;
                    human_input__forceLookMode : bool;
                    human_input__blockLookModeCounter : int;
                    aim_offset : float2&;
                    need_update_look_dir : bool = true;
                    need_update_walk_dir : bool = true;
                    look_axis_value_clamp : float2 = float2(0.5, 0.5);
                    vert_look_angle_limit = DEFAULT_VERT_LOOK_ANGLE_LIMIT_RAD;
                    rotation_speed : float;
                    human_input__aimingSensMult : float = 1.0;
                    human_input__concussionSensMult : float = 1.0;
                    human_input__resetSprintMovementThreshold : float = DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD;
                    human_input__resetSprintMoveThreshold : float = DEFAULT_RESET_SPRINT_MOVE_THRESHOLD;
                    human_input__lookAngleTau : float = 0.;
                    human_input__aimInputInertia : float;
                    human_input__moveInputInertia : float;
                    isTpsView : bool;
                    var actor : HumanActor&;
                    var aim_angle : float2&;
                    var human_input__lookAngle : float2&;
                    var human_input__aimInputAccum : float2&;
                    var human_input__moveInputAccum : float2&;
                    var human_net_phys__prevRootDir : float3&;
                    var human_net_phys__prevVertDir : float3&)
  if need_update_look_dir
    var mouseAngles = get_mouse_axes_delta()
    
    
    
    mouseAngles.y *= 0.5

    let asAim = mouseAngles
    let asLook = mouseAngles
    var asLookBActive = false
    if isTpsView
      asLookBActive = is_shortcut_down(ShortcutEventId.ID_HUMAN_LOOK) 
    let isInMenu = get_is_in_menu()
    var ax = !asLookBActive && !isInMenu ? clamp(double(asAim.x), -1.0lf, 1.0lf) : 0.0lf
    var ay = !asLookBActive && !isInMenu ? clamp(double(asAim.y), -1.0lf, 1.0lf) : 0.0lf

    
    var sensMult = 1.0lf
    let isZoomView = actor.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_ZOOM_VIEW)
    let isAim = actor.phys.appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)

    
    let humanAiming = 0.65
    let humanTpsCam = 1.0
    let humanFpsCam = 1.0
    let isTps = false
    if isZoomView || isAim
      sensMult = double(humanAiming * human_input__aimingSensMult * human_input__concussionSensMult)
    elif isTps
      sensMult = double(humanTpsCam * human_input__concussionSensMult)
    else
      sensMult = double(humanFpsCam * human_input__concussionSensMult)

    ax *= sensMult
    ay *= sensMult

    apply_inertia(human_input__aimInputInertia, human_input__aimInputAccum, ax, ay)

    
    let prevLookAngle = human_input__lookAngle
    var shouldResetLookAngle = false
    if (asLookBActive || human_input__forceLookMode) && human_input__blockLookModeCounter <= 0
      if actor.phys |> human_phys_isAiming() && !human_input__forceLookMode
        ax += double(asLook.x)
        ay += double(asLook.y)
        shouldResetLookAngle = true
      else
        let lookDelta = human_input__forceLookMode && !asLookBActive ? float2(ax, ay) : float2(asLook.x, asLook.y)
        
        if human_input__forceLookMode
          ax = 0.0lf
          ay = 0.0lf
        if !isTpsView
          human_input__lookAngle.x = clamp(prevLookAngle.x + lookDelta.x,
                                            -look_axis_value_clamp.x,
                                            look_axis_value_clamp.x)
          human_input__lookAngle.y = clamp(prevLookAngle.y + lookDelta.y,
                                            -look_axis_value_clamp.y,
                                            look_axis_value_clamp.y)
        else
          human_input__lookAngle = float2(prevLookAngle.x + lookDelta.x, prevLookAngle.y + lookDelta.y)
    else
      shouldResetLookAngle = true
    if shouldResetLookAngle
      human_input__lookAngle.x = approach(prevLookAngle.x, 0., dt, human_input__lookAngleTau)
      human_input__lookAngle.y = approach(prevLookAngle.y, 0., dt, human_input__lookAngleTau)
    update_look_dir(actor,
                    aim_angle,
                    human_net_phys__prevRootDir,
                    human_net_phys__prevVertDir,
                    aim_offset,
                    vert_look_angle_limit,
                    human_input__perspWk,
                    ax * double(PI),
                    ay * double(PI),
                    human_input__lookAngle.x * PI,
                    human_input__lookAngle.y * PI,
                    rotation_speed,
                    dt)

  if need_update_look_dir && !need_update_walk_dir
    return

  var strafe = 0.0lf
  var move = 0.0lf
  if need_update_walk_dir
    let isInMenu = get_is_in_menu()
    move = !isInMenu ? clamp(double(get_axis_value(Axis.AXIS_HUMAN_WALK, true)), -1.0lf, 1.0lf) : 0.lf
    strafe = !isInMenu ? clamp(double(get_axis_value(Axis.AXIS_HUMAN_STRAFE, true)), -1.0lf, 1.0lf) : 0.lf
    apply_inertia(human_input__moveInputInertia, human_input__moveInputAccum, move, strafe)

  update_walk_dir(actor, move, strafe)

def input_double_sprint(var phys : HumanPhys&; activated : bool)
  if phys.producedCT.isAltAttackState
    return
  if activated
    phys.producedCT |> human_control_state_setAltAttackState(true)
  else
    phys.producedCT |> human_control_state_setAltAttackState(false)

[es(tag=input, REQUIRE=controlledHero)]
def human_double_sprint_input_es(evt : EventOnKeyDown;
                                 var human_input__sprintHoldReset : bool&;
                                 var human_input__sprintLastPressing : float&;
                                 var human_input__sprintLastLastPressingTime : float&)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_SPRINT)
    human_input__sprintLastLastPressingTime = human_input__sprintLastPressing
    human_input__sprintLastPressing = get_sync_time()
    human_input__sprintHoldReset = false

[es(tag=input, REQUIRE=(controlledHero, human))]
def human_reset_dead_cooldown_input_es(evt : EventOnKeyDown;
                                       eid : EntityId)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_NEXT_AFTER_DEATH)
    send_net_event(eid, EventResetDeathCooldown())

[es(tag=input, REQUIRE=controlledHero)]
def human_weap_mod_toggle_input_es(evt : EventOnKeyDown;
                                   human_net_phys : HumanActor;
                                   eid : EntityId)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_WEAP_MOD_TOGGLE)
    sendEvent(eid, CmdWeapModToggle(slotId = int(human_net_phys.phys.producedCT.chosenWeapon)))

[es(tag=input, REQUIRE=(controlledHero, human))]
def human_input_change_zoom_to_next_down_es(evt : EventOnKeyDown;
                                            input__enabled : bool = true;
                                            var human_input__changeZoomLastPressTime : float&)
  let isAim = is_shortcut_down(ShortcutEventId.ID_HUMAN_AIM)

  if input__enabled && isAim && evt.eventId == int(ShortcutEventId.ID_HUMAN_NEXT_ZOOM)
    human_input__changeZoomLastPressTime = get_sync_time()


[es(tag=input, REQUIRE=(controlledHero, human))]
def human_input_change_zoom_to_next_up_es(evt : EventOnKeyUp;
                                          eid : EntityId;
                                          input__enabled : bool = true;
                                          human_input__changeZoomLastPressTime : float;
                                          human_input__changeZoomFastPressThres : float)
  let isAim = is_shortcut_down(ShortcutEventId.ID_HUMAN_AIM)

  if input__enabled && isAim && evt.eventId == int(ShortcutEventId.ID_HUMAN_NEXT_ZOOM)
    if get_sync_time() - human_input__changeZoomLastPressTime < human_input__changeZoomFastPressThres
      sendEvent(eid, NextVariableZoomGunScope())


[es(tag=input, after=human_input_es, REQUIRE=watchedByPlr)]
def human_input_aim_second_scope_es(info : UpdateStageUpdateInput;
                                    
                                    human_weap__currentGunModEids : EidList;
                                    var human_weap__currentScope : EntityId&)
  human_weap__currentScope = INVALID_ENTITY_ID
  let secondScope = false
  if secondScope
    for gunMod in human_weap__currentGunModEids
      query(gunMod) <| $ [es(REQUIRE=secondScope)] (eid : EntityId)
        human_weap__currentScope = eid
  else
    for gunMod in human_weap__currentGunModEids
      query(gunMod) <| $ [es(REQUIRE_NOT=secondScope, REQUIRE=gunScope)] (eid : EntityId)
        human_weap__currentScope = eid

[es(on_disappear, REQUIRE=human_input__aimSecondScope)]
def set_current_scope_on_input_disappear(evt : Event;
                                         human_weap__currentGunModEids : EidList;
                                         var human_weap__currentScope : EntityId&)
  human_weap__currentScope = INVALID_ENTITY_ID
  for gunMod in human_weap__currentGunModEids
    query(gunMod) <| $ [es(REQUIRE_NOT=secondScope, REQUIRE=gunScope)] (eid : EntityId)
      human_weap__currentScope = eid


[es(tag=input, REQUIRE=controlledHero, REQUIRE_NOT=deadEntity)]
def human_use_object_input(evt : EventOnKeyDown;
                           eid : EntityId;
                           transform : float3x4;
                           isDowned : bool = false;
                           human_use_object__selectedObject : EntityId;
                           human_use_object__thresholdDist : float = 12.f)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_USE) && !isDowned
    human_try_use_object(eid, transform[3], human_use_object__thresholdDist, human_use_object__selectedObject)

def input_melee(cur_time : float;
                is_gamepad : bool;
                humanInputMeleeAction : ShortcutEventId; 
                human_input__canShoot : bool;
                main_attack_is_melee : bool;
                inputShootAction : ShortcutEventId; 
                is_sprinting : bool;
                human_melee_charge__targetFound : bool;
                human_melee_charge__longPressTime : float;
                human_input__wishMelee : bool;
                var phys : HumanPhys&;
                var human_melee_charge__activateAtTime : float&;
                var human_input__meleeInputStartTime : float&;
                var human_melee_charge__lastMeleeButtonState : bool&;
                var human_melee_charge__forceEnabled : bool&)
  var isMeleeButtonPressed = is_shortcut_down(humanInputMeleeAction) 
  if main_attack_is_melee && human_input__canShoot 
    isMeleeButtonPressed ||= is_shortcut_down(inputShootAction)

  let isMeleeChargingInput = (isMeleeButtonPressed || human_melee_charge__forceEnabled) && is_sprinting && !human_input__wishMelee
  if isMeleeChargingInput && human_melee_charge__activateAtTime < 0.
    human_melee_charge__activateAtTime = cur_time + human_melee_charge__longPressTime
  elif !isMeleeChargingInput
    human_melee_charge__activateAtTime = -1.0

  let isMeleeCharge = human_melee_charge__activateAtTime > 0.0 && cur_time > human_melee_charge__activateAtTime

  if is_gamepad && isMeleeCharge
    if isMeleeButtonPressed && !human_melee_charge__lastMeleeButtonState
      human_melee_charge__forceEnabled = false
  else
    human_melee_charge__forceEnabled = false

  human_melee_charge__lastMeleeButtonState = isMeleeButtonPressed
  if isMeleeCharge
    human_melee_charge__forceEnabled = is_gamepad
    human_input__meleeInputStartTime = -1.0
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, true)
    phys.producedCT |> human_control_state_setAltAttackState(true)
  else
    phys.producedCT |> human_control_state_setAltAttackState(false)
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, human_input__wishMelee)

  if human_melee_charge__targetFound && isMeleeCharge
    phys.producedCT |> human_control_state_setAltAttackState(false)
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_MELEE, false)

[es(tag=input, on_appear, after=human_save_tm, on_event=(EventUnitRespawn, EventUnitSpawned), REQUIRE=controlledHero)]
def human_input_appear_es(evt : Event;
                          transform : float3x4;
                          var human_input__aimAngle : float2&;
                          var human_input__forceSprintAction : bool&)
  human_input__aimAngle = dir_to_angles(transform[0])
  human_input__forceSprintAction = false

[es(tag=input, REQUIRE=(human, hero))]
def human_sprint_is_hold_mode_trigger(evt : EventOnKeyDown;
                                      var human_input__forceSprintAction : bool&)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_SPRINT)
    let joyParams = get_current_joy_param()
    if joyParams != null && !joyParams.holdFastSprintForHuman
      human_input__forceSprintAction = !human_input__forceSprintAction

[es(tag=input, REQUIRE=controlledHero, REQUIRE_NOT=menuSoldier)]
def human_input_enable_assist_es(info : UpdateStageUpdateInput;
                                 eid : EntityId;
                                 var aim_assist__enabled : bool&)
  let mouseAxis = length(get_mouse_axes_delta())
  if mouseAxis > 0.f
    let assistValBefore = aim_assist__enabled
    if get_axis_value(Axis.AXIS_HUMAN_MOUSE_AIM_X, false) != 0.f || get_axis_value(Axis.AXIS_HUMAN_MOUSE_AIM_Y, false) != 0.f
      aim_assist__enabled = true
    else
      aim_assist__enabled = false
    if aim_assist__enabled != assistValBefore
      if aim_assist__enabled
        print("Aim assist was enabled for {eid}")
      else
        print("Aim assist was disabled for {eid} because {mouseAxis} > 0 but axis value is empty")

[es(tag=input, REQUIRE=controlledHero, REQUIRE_NOT=menuSoldier)]
def human_input_es(info : UpdateStageUpdateInput;
                   bipod__enabled : bool = false;
                   human_input__lastWeaponChangeInput : float;
                   human_input__aimAngleOffset : float2&;
                   human_weap__throwMode : bool;
                   human_input__forceLookMode : bool;
                   human_weap__currentGunEid : EntityId;
                   human_input__aimInputInertia : float;
                   human_input__moveInputInertia : float;
                   human_input__lookDirClamp : float2 = float2(90.f, 90.f);
                   human_input__currentVertLookAngleLimit : float2;
                   
                   human_input__perspWk : float;
                   human_input__aimingSensMult : float = 1.0f;
                   human_input__concussionSensMult : float = 1.0;
                   human_input__crawlingReject : bool = true;
                   camera_input__disabled : bool = false;
                   human_input__resetSprintMovementThreshold : float = DEFAULT_RESET_SPRINT_MOVEMENT_THRESHOLD;
                   human_input__resetSprintMoveThreshold : float = DEFAULT_RESET_SPRINT_MOVE_THRESHOLD;
                   human_input__sprintMoveThreshold : float = 0.7;
                   human_input__crawlToAnyTransitionHeight : float = -0.9;
                   human_input__crawlToCrouchTransitionHeight : float = -0.4;
                   human_input__lookAngleTau : float = 0.;
                   human_input__canShoot : bool = true;
                   human_input__forceAim : bool = false;
                   human_input__blockLookModeCounter : int = 0;
                   human_input__wishMelee : bool;
                   human_melee_charge__targetFound : bool = false;
                   human_melee_charge__longPressTime : float = 0.2;
                   human_input__sprintLastPressing : float;
                   human_input__sprintLastLastPressingTime : float;
                   human_input__doubleClickPeriod : float;
                   double_sprint__isActive : bool = false;
                   double_sprint__rotationSpeed : float = -1.;
                   double_sprint__rotationRestorationSpeed : float = 5.;
                   double_sprint__rotationMaxSpeed : float = 6.28;
                   double_sprint__rotationSpeedThreshold : float = 0.9;
                   human_fast_prone__inProgress : bool;
                   human_sprint_leap__isLeaping : bool;
                   isTpsView : bool = false;
                   human_input__holdBreathLastPressingTime : float;
                   human_input__holdBreathLongPressThres : float;
                   human_input__forceSprintAction : bool = false;
                   var human_input__sprintHoldReset : bool&;
                   var human_input__currentRotationSpeed : float&;
                   var human_melee_charge__forceEnabled : bool&;
                   var human_melee_charge__activateAtTime : float&;
                   var human_input__meleeInputStartTime : float&;
                   var human_melee_charge__lastMeleeButtonState : bool&;
                   var human_input__hasValidState : bool&;
                   var human_input__standState : int&;
                   var human_input__aimAngle : float2&;
                   var human_input__oldAimAngle : float2&;
                   var human_input__lastShootInput : float&;
                   var human_net_phys : HumanActor&;
                   var human_input__lookAngle : float2&;
                   var human_input__aimInputAccum : float2&;
                   var human_input__moveInputAccum : float2&;
                   var human_net_phys__prevRootDir : float3&;
                   var human_net_phys__prevVertDir : float3&)
  if camera_input__disabled
    return
  assume phys = human_net_phys.phys
  human_input__oldAimAngle = human_input__aimAngle

  if !human_input__hasValidState
    fix_changed_hero_input(info.dt,
                           human_input__hasValidState,
                           human_input__standState,
                           human_net_phys,
                           human_input__aimAngle, human_input__lookAngle,
                           human_input__aimInputAccum,
                           human_input__moveInputAccum,
                           human_net_phys__prevRootDir,
                           human_net_phys__prevVertDir,
                           isTpsView,
                           human_input__aimInputInertia,
                           human_input__moveInputInertia,
                           human_input__lookAngleTau,
                           human_input__perspWk,
                           human_input__forceLookMode,
                           human_input__blockLookModeCounter,
                           human_input__aimAngleOffset,
                           human_input__resetSprintMovementThreshold,
                           human_input__resetSprintMoveThreshold)

  var shouldUpdateWalkDir = true

  let isAimBlockedByGun = !(get_bool(human_weap__currentGunEid, "gun__canAim") ?? true)
  var aim = (is_shortcut_down(ShortcutEventId.ID_HUMAN_AIM) || human_input__forceAim) && !isAimBlockedByGun

  var crawl = (human_input__standState == int(HumanPhysControlType.HCT_CRAWL))
  var crouch = (human_input__standState == int(HumanPhysControlType.HCT_CROUCH))

  
  let crawlToAnyTransitionHeight = human_input__crawlToAnyTransitionHeight
  let crawlToCrouchTransitionHeight = human_input__crawlToCrouchTransitionHeight

  
  
  let isCrawlHeight = phys.currentState.height <= crawlToAnyTransitionHeight
  let isBelowCrawlToCrouchHeight = phys.currentState.height <= crawlToCrouchTransitionHeight
  let transitionFromCrawlToCrouch = (crouch && isBelowCrawlToCrouchHeight)
  if (human_input__crawlingReject &&
     (isCrawlHeight || transitionFromCrawlToCrouch || crawl))
    shouldUpdateWalkDir = false
    phys.producedCT |> human_control_state_set_walk_dir(float2(0, 0))

  
  let shouldUpdateLookDir = true
  if double_sprint__isActive
    human_input__currentRotationSpeed = double_sprint__rotationSpeed
  else
    human_input__currentRotationSpeed *= 1. + info.dt * double_sprint__rotationRestorationSpeed
    human_input__currentRotationSpeed = clamp(human_input__currentRotationSpeed, double_sprint__rotationSpeed, double_sprint__rotationMaxSpeed)
  let rotationSpeed = human_input__currentRotationSpeed > double_sprint__rotationMaxSpeed * double_sprint__rotationSpeedThreshold ? -1. : human_input__currentRotationSpeed

  update_movement(info.dt,
                  human_input__perspWk,
                  human_input__forceLookMode,
                  human_input__blockLookModeCounter,
                  human_input__aimAngleOffset,
                  shouldUpdateLookDir, shouldUpdateWalkDir, human_input__lookDirClamp / 180.f,
                  deg_to_rad(human_input__currentVertLookAngleLimit), rotationSpeed,
                  human_input__aimingSensMult,
                  human_input__concussionSensMult,
                  human_input__resetSprintMovementThreshold,
                  human_input__resetSprintMoveThreshold,
                  human_input__lookAngleTau,
                  human_input__aimInputInertia,
                  human_input__moveInputInertia,
                  isTpsView,
                  human_net_phys, human_input__aimAngle,
                  human_input__lookAngle,
                  human_input__aimInputAccum,
                  human_input__moveInputAccum,
                  human_net_phys__prevRootDir,
                  human_net_phys__prevVertDir)

  let leanX = bipod__enabled ? 0.f : get_axis_value(Axis.AXIS_HUMAN_LEAN, true)
  phys.producedCT |> human_control_state_set_lean_position(leanX)

  let isSprintAction = human_input__forceSprintAction || is_shortcut_down(ShortcutEventId.ID_HUMAN_SPRINT)
  let isDoubleSprintAction = is_shortcut_down(ShortcutEventId.ID_HUMAN_SPRINT) && (human_input__sprintLastPressing - human_input__sprintLastLastPressingTime < human_input__doubleClickPeriod)
  let isSprintingMove = get_axis_value(Axis.AXIS_HUMAN_WALK, true) > human_input__sprintMoveThreshold
  let isSprinting = isSprintAction && isSprintingMove || isDoubleSprintAction

  var sprint = isSprinting && !aim && !human_input__sprintHoldReset

  let mainAttackIsMelee = get_bool(human_weap__currentGunEid, "gun__melee") ?? false
  if is_shortcut_down(ShortcutEventId.ID_HUMAN_SHOOT) && human_input__canShoot
    let isShootBlocked = info.curTime - human_input__lastWeaponChangeInput < 0.1
    let shoot = is_shortcut_down(ShortcutEventId.ID_HUMAN_SHOOT) || phys.producedCT.haveUnenqueuedHctShoot
    let shootFlag = (shoot && !isShootBlocked)
    if shootFlag != phys.producedCT.lastEnqueuedHctShoot
      phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, shootFlag)
    if shootFlag && !mainAttackIsMelee
      human_input__lastShootInput = info.curTime
      
      sprint = false
      phys.producedCT.haveUnenqueuedHctShoot = true
  else
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SHOOT, false)

  let isLadderQuickMoving = false 

  
  if aim && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT)
    sprint = false

  
  if sprint && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_AIM)
    aim = false

  if human_weap__throwMode
    aim = false

  
  if (crawl || crouch) && phys.producedCT |> is_control_bit_set(HumanPhysControlType.HCT_SPRINT)
    human_input__sprintHoldReset = true
    sprint = false

  if sprint
    if !aim
      human_input__standState = 0
      crawl = false
      crouch = false

  if sprint && !(crouch || crawl)
    aim = false

  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_AIM, aim)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, crawl)
  phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, crouch)

  if !human_fast_prone__inProgress && !human_sprint_leap__isLeaping
    human_net_phys |> set_ct_controlbit(HumanPhysControlType.HCT_JUMP, ShortcutEventId.ID_HUMAN_JUMP)

  
  

  let humanInputMeleeAction : ShortcutEventId  = ShortcutEventId.ID_HUMAN_SHOOT_MELEE
  let inputShootAction : ShortcutEventId = ShortcutEventId.ID_HUMAN_SHOOT
  input_melee(info.curTime, false , humanInputMeleeAction , human_input__canShoot, mainAttackIsMelee, inputShootAction , isSprinting,
              human_melee_charge__targetFound, human_melee_charge__longPressTime, human_input__wishMelee,
              phys, human_melee_charge__activateAtTime, human_input__meleeInputStartTime, human_melee_charge__lastMeleeButtonState,
              human_melee_charge__forceEnabled)
  phys.producedCT |> human_control_state_setAltAttackState(false)
  input_double_sprint(phys, isDoubleSprintAction)

  if aim
    let longPressIsActive = info.curTime - human_input__holdBreathLastPressingTime > human_input__holdBreathLongPressThres
    let isHoldBreathPressed = is_shortcut_down(ShortcutEventId.ID_HUMAN_HOLD_BREATH) && longPressIsActive
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, isHoldBreathPressed)
  else
    phys.producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_SPRINT, sprint || isLadderQuickMoving)

  human_net_phys |> set_ct_controlbit(HumanPhysControlType.HCT_ZOOM_VIEW, ShortcutEventId.ID_HUMAN_ZOOM)

  
  
  


[es(tag=input, REQUIRE=controlledHero)]
def human_hold_breath_long_press_input_down_es(evt : EventOnKeyDown;
                                               var human_input__holdBreathLastPressingTime : float&)
  if evt.eventId == int(ShortcutEventId.ID_HUMAN_HOLD_BREATH)
    human_input__holdBreathLastPressingTime = get_sync_time()


[es(tag=input, REQUIRE=controlledHero, after=human_input_es)]
def human_input_aim_in_crawling_es(info : UpdateStageUpdateInput;
                                   human_input__standState : int;
                                   var human_net_phys : HumanActor&;
                                   var human_input__wishMove : bool&;
                                   var human_input__wishAim : bool&;
                                   var human_input__crawlingReject : bool&)
  if human_input__standState != int(HumanPhysControlType.HCT_CRAWL)
    human_input__wishAim = false
    human_input__wishMove = false
    human_input__crawlingReject = false
    return

  let isAim = is_shortcut_down(ShortcutEventId.ID_HUMAN_AIM)
  let moveStateY = get_axis_value(Axis.AXIS_HUMAN_WALK, true)
  let moveStateX = get_axis_value(Axis.AXIS_HUMAN_STRAFE, true)
  let isMove = moveStateX > MOVE_THRESHOLD || moveStateX < -MOVE_THRESHOLD || moveStateY > MOVE_THRESHOLD || moveStateY < -MOVE_THRESHOLD

  if isMove && isAim && (human_input__wishMove || human_input__wishAim)
    if human_input__wishAim
      human_input__crawlingReject = true
    elif human_input__wishMove
      human_input__crawlingReject = false
    human_input__wishMove = false
    human_input__wishAim = false

  elif !isMove
    human_input__wishMove = true

  elif !isAim
    human_input__wishAim = true
    human_input__crawlingReject = false

  if isMove && !human_input__crawlingReject && isAim
    human_net_phys.phys.producedCT |> human_control_state_set_control_bit((HumanPhysControlType.HCT_ZOOM_VIEW), false)


[es(tag=input, no_order, REQUIRE=controlledHero)]
def human_input_persp_es(info : UpdateStageInfoAct;
                         camera_input__disabled : bool = false;
                         var human_input__perspWk : float&)
  if camera_input__disabled
    return
  get_Driver3dPerspective() <| $(pers : Driver3dPerspective#)
    human_input__perspWk = pers.wk

[es(tag=input, REQUIRE=controlledHero)]
def human_common_input_action_triggered_es(evt : EventOnKeyDown;
                                           human_net_phys : HumanActor;
                                           var human_input__meleeInputStartTime : float&;
                                           var human_input__standState : int&;
                                           human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                                           human_fast_prone__inProgress : bool;
                                           human_sprint_leap__isLeaping : bool;
                                           isInVehicle : bool = false;
                                           bipod__enabled : bool = false)
  assume ct = human_net_phys.phys.producedCT
  let atTime = get_sync_time()
  let action = evt.eventId
  if action == int(ShortcutEventId.ID_HUMAN_JUMP)
    if (human_net_phys.phys.canJump) && !human_fast_prone__inProgress && !human_sprint_leap__isLeaping
      human_input__standState = 0
  elif action == int(ShortcutEventId.ID_HUMAN_SHOOT_MELEE) || (action == int(ShortcutEventId.ID_HUMAN_SHOOT) && get_bool(human_weap__currentGunEid, "gun__melee") ?? false)
    if !isInVehicle && !bipod__enabled && !human_fast_prone__inProgress && !human_sprint_leap__isLeaping && !is_control_bit_set(ct, HumanPhysControlType.HCT_THROW_BACK)
      human_input__meleeInputStartTime = atTime
  elif action == int(ShortcutEventId.ID_HUMAN_CRAWL)
    if !isInVehicle && !bipod__enabled && !human_fast_prone__inProgress && !human_sprint_leap__isLeaping
      human_input__standState = human_input__standState == int(HumanPhysControlType.HCT_CRAWL) ? 0 : int(HumanPhysControlType.HCT_CRAWL)
  elif action == int(ShortcutEventId.ID_HUMAN_CROUCH)
    if !isInVehicle && !bipod__enabled && !human_fast_prone__inProgress && !human_sprint_leap__isLeaping
      human_input__standState = human_input__standState == int(HumanPhysControlType.HCT_CROUCH) ? 0 : int(HumanPhysControlType.HCT_CROUCH)

[es(tag=input, after=human_weap_post_phys_es)]
def reset_melee_action_es(evt : CmdPostPhysUpdate;
                          var human_input__wishMelee : bool&)
  human_input__wishMelee = false

[es(tag=input, REQUIRE=hero)]
def human_common_input_action_terminated_es(evt : EventOnKeyUp;
                                            
                                            input__enabled : bool = true;
                                            human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                                            
                                            
                                            var human_input__wishMelee : bool&;
                                            
                                            var human_input__meleeInputStartTime : float&)
  let action = evt.eventId
  if !input__enabled
    return
  
  
  
  elif action == int(ShortcutEventId.ID_HUMAN_SHOOT_MELEE) || (action == int(ShortcutEventId.ID_HUMAN_SHOOT) && get_bool(human_weap__currentGunEid, "gun__melee") ?? false)
    human_input__wishMelee = human_input__meleeInputStartTime > 0.0
    human_input__meleeInputStartTime = -1.0

[es(tag=input, REQUIRE=controlledHero)]
def human_crew__vehicle_input_es(evt : EventOnKeyDown; eid : EntityId; ownedByPlr : EntityId)
  var player = player_get_by_eid(ownedByPlr)
  if player == null
    return
  if evt.eventId == int(ShortcutEventId.ID_CREW_LEAVE_VEHICLE)
    player_crew_get(*player) <| $(crew)
      var switch_requested = false
      for u in crew
        if u.inVehicle.eid == eid
          sendEvent(u.unit.eid, CmdRequestUnitCrewLeaveVehicle())
          print("LEAVE VEHICLE {eid}->{u.unit.eid}")
          if !switch_requested
            switch_requested = true
            sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = u.unit.eid))
  if evt.eventId == int(ShortcutEventId.ID_CREW_ENTER_VEHICLE)
    let crew_member_idx = player_find_crew_member_idx(*player, eid)
    if crew_member_idx == -1
      return
    let cameraTm = get_active_camera_tm()
    let from = cameraTm[3]
    let dir = cameraTm[2]
    var t = 100.0f
    using() <| $(var intersections : IntersectedEntities)
      trace_entities_in_grid(ecs_hash("vehicles"), from, dir, t,  eid, intersections, SortIntersections.YES)
      for isect in intersections
        let unit = get_unit(isect.eid)
        if unit != null && unit.myPlayer == player
          sendEvent(eid, CmdRequestUnitCrewEnterVehicle(vehicleEid = isect.eid))
          sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = isect.eid))
          print("ENTER VEHICLE {eid}->{isect.eid}")
          break


def private hud_show_message(text : string; addKey : string = ""; addValue : auto(TT) = -1)
  using() <| $(var eventData : DataBlock)
    if addKey != ""
      set(eventData, addKey, addValue)
    hud_notify_script(text, eventData)


[es(tag=input, REQUIRE=controlledHero)]
def human_crew_input_es(evt : EventOnKeyDown;
                        eid : EntityId;
                        ownedByPlr : EntityId;
                        squad_member__squad : EntityId = INVALID_ENTITY_ID;
                        drone__owner : EntityId = INVALID_ENTITY_ID)
  if !squad_member__squad && !drone__owner
    return

  var player = player_get_by_eid(ownedByPlr)
  if player == null
    return

  var curSoldierEid = drone__owner == INVALID_ENTITY_ID ? eid : drone__owner
  var squad = squad_member__squad
  if squad == INVALID_ENTITY_ID
    query(drone__owner) <| $ [es] (squad_member__squad : EntityId)
      squad = squad_member__squad

  if evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_NEXT)
    query(squad) <| $ [es] (squad__allMembers : EidList)
      let count = length(squad__allMembers)
      if count > 1
        let curSoldierIndex = find_index(squad__allMembers, curSoldierEid)
        var soldierFound = false
        for i in range(1, count)
          if soldierFound
            break
          var nextSoldierIndex = (curSoldierIndex + i) % count
          let nextSoldier = squad__allMembers[nextSoldierIndex]
          query(nextSoldier) <| $ [es] (isAlive : bool; isInVehicle : bool)
            if isAlive && !isInVehicle
              sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = nextSoldier))
              print("SWITCH TO CREW {eid}->{nextSoldier}")
              soldierFound = true
    return

  var switchOnSoldierInd = -1
  if evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_ON_SOLDIER_1)
    switchOnSoldierInd = 0
  elif evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_ON_SOLDIER_2)
    switchOnSoldierInd = 1
  elif evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_ON_SOLDIER_3)
    switchOnSoldierInd = 2
  elif evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_ON_SOLDIER_4)
    switchOnSoldierInd = 3
  elif evt.eventId == int(ShortcutEventId.ID_CREW_SWITCH_CONTROL_ON_SOLDIER_5)
    switchOnSoldierInd = 4

  if switchOnSoldierInd < 0
    return

  query(squad) <| $ [es] (squad__allMembers : EidList)
    if switchOnSoldierInd >= length(squad__allMembers)
      hud_show_message("hint:soldier_switch_wrong_index", "numSoldiers", length(squad__allMembers))
      return
    let soldierToSwitch = squad__allMembers[switchOnSoldierInd]
    if soldierToSwitch == eid
      hud_show_message("hint:soldier_switch_already_under_control")
      return
    var canSwitch = false
    query(soldierToSwitch) <| $ [es] (isAlive : bool)
      canSwitch = isAlive
    if !canSwitch
      hud_show_message("hint:soldier_switch_not_active")
      return
    sendEvent(ownedByPlr, CmdRequestSwitchControlledUnit(toEid = soldierToSwitch))
    print("SWITCH TO CREW {eid}->{soldierToSwitch}")


[es(tag=input, after=human_input_es)]
def human_sprint_strafe(info : UpdateStageUpdateInput;
                        double_sprint__isActive : bool;
                        double_sprint__strafeSpeed : float;
                        var human_net_phys : HumanActor&;
                        var double_sprint__currentStrafe : float&)
  assume phys = human_net_phys.phys
  assume walkDir = phys.producedCT.walkDir

  if !double_sprint__isActive
    double_sprint__currentStrafe = walkDir.y
    return

  double_sprint__currentStrafe = move_to(double_sprint__currentStrafe, walkDir.y, info.dt, double_sprint__strafeSpeed)
  let newWalkDir = float2(walkDir.x, double_sprint__currentStrafe)
  phys.producedCT |> human_control_state_set_walk_dir(newWalkDir)

