require ecs
require math.base
require DngHuman
require %game.events

require %appGame.wt_events
require HumanPhys
require DagorMath
require Dacoll
require WTPhysActor
require Unit
require net

def is_in_air(human_phys__inAirTime : float)
  return human_phys__inAirTime != 0.

def was_in_air(human_phys__previousInAirTime : float; human_phys__inAirTimeThreshold : float)
  return human_phys__previousInAirTime > human_phys__inAirTimeThreshold

[es(track=beh_tree__enabled, on_appear)]
def human_phys_set_simpified(evt : Event;
                             beh_tree__enabled : bool;
                             var human_net_phys__isSimplifiedQueryWalkPosition : bool&;
                             var human_net_phys__isSimplifiedPhys : bool&;
                             var human_weap__infiniteAmmoHolders : bool?;
                             devSoldier : Tag const?)
  let isAi = beh_tree__enabled || devSoldier != null
  human_net_phys__isSimplifiedPhys = isAi
  human_net_phys__isSimplifiedQueryWalkPosition = isAi
  if human_weap__infiniteAmmoHolders != null
    *human_weap__infiniteAmmoHolders = isAi

[es(on_appear, track=(human_phys__botFrictionGroundCoeffWalk, human_phys__botFrictionGroundCoeffRun, human_phys__botFrictionGroundCoeffSprint,
  human_phys__botAccelerationWalk, human_phys__botAccelerationRun, human_phys__botAccelerationSprint))]
def human_phys_save_default_accelerations(evt : Event;
                                          human_net_phys : HumanActor;
                                          human_phys__botFrictionGroundCoeffWalk : float;
                                          human_phys__botFrictionGroundCoeffRun : float;
                                          human_phys__botFrictionGroundCoeffSprint : float;
                                          human_phys__botAccelerationWalk : float;
                                          human_phys__botAccelerationRun : float;
                                          human_phys__botAccelerationSprint : float;
                                          var human_phys__botFricitonByState : FloatList;
                                          var human_phys__botAccelerationByState : FloatList;
                                          var human_phys__fricitonByStateDef : FloatList;
                                          var human_phys__accelerationByStateDef : FloatList)
  let statesCount = int(HUMoveState.EMS_NUM)
  resize(human_phys__fricitonByStateDef, statesCount)
  resize(human_phys__botFricitonByState, statesCount)
  resize(human_phys__accelerationByStateDef, statesCount)
  resize(human_phys__botAccelerationByState, statesCount)
  for i in 0..statesCount
    human_phys__fricitonByStateDef[i] = human_net_phys.phys.fricitonByState[i]
    human_phys__botFricitonByState[i] = human_net_phys.phys.fricitonByState[i]
    human_phys__accelerationByStateDef[i] = human_net_phys.phys.accelerationByState[i]
    human_phys__botAccelerationByState[i] = human_net_phys.phys.accelerationByState[i]

  if human_phys__botFrictionGroundCoeffWalk >= 0.
    human_phys__botFricitonByState[int(HUMoveState.EMS_WALK)] = human_phys__botFrictionGroundCoeffWalk
  if human_phys__botFrictionGroundCoeffRun >= 0.
    human_phys__botFricitonByState[int(HUMoveState.EMS_RUN)] = human_phys__botFrictionGroundCoeffRun
  if human_phys__botFrictionGroundCoeffSprint >= 0.
    human_phys__botFricitonByState[int(HUMoveState.EMS_SPRINT)] = human_phys__botFrictionGroundCoeffSprint

  if human_phys__botAccelerationWalk >= 0.
    human_phys__botAccelerationByState[int(HUMoveState.EMS_WALK)] = human_phys__botAccelerationWalk
  if human_phys__botAccelerationRun >= 0.
    human_phys__botAccelerationByState[int(HUMoveState.EMS_RUN)] = human_phys__botAccelerationRun
  if human_phys__botAccelerationSprint >= 0.
    human_phys__botAccelerationByState[int(HUMoveState.EMS_SPRINT)] = human_phys__botAccelerationSprint

[es(on_appear, track=(human_phys__botFricitonByState, human_phys__botAccelerationByState, beh_tree__enabled),
  after=human_phys_save_default_accelerations)]
def human_phys_bot_accelerations(evt : Event;
                                 beh_tree__enabled : bool;
                                 human_phys__botFricitonByState : FloatList;
                                 human_phys__botAccelerationByState : FloatList;
                                 human_phys__fricitonByStateDef : FloatList;
                                 human_phys__accelerationByStateDef : FloatList;
                                 var human_net_phys : HumanActor)
  let statesCount = int(HUMoveState.EMS_NUM)
  for i in 0..statesCount
    human_net_phys.phys.fricitonByState[i] = beh_tree__enabled ? human_phys__botFricitonByState[i] : human_phys__fricitonByStateDef[i]
    human_net_phys.phys.accelerationByState[i] = beh_tree__enabled ? human_phys__botAccelerationByState[i] : human_phys__accelerationByStateDef[i]

[es]
def human_phys_set_in_air_time(update : CmdPostPhysUpdate;
                               human_net_phys : HumanActor;
                               var human_phys__previousInAirTime : float&;
                               var human_phys__inAirTime : float&;
                               isInVehicle : bool = false)
  assume currentState = human_net_phys.phys.currentState
  human_phys__previousInAirTime = human_phys__inAirTime
  let isInAir = (int(currentState.isInAirHistory) & 1) != 0 && (int(currentState.states) & int(StateFlag.ST_SWIM)) == 0 && !isInVehicle
  human_phys__inAirTime = isInAir ? (human_phys__inAirTime + update.dt) : 0.f

[es]
def human_anim_keep_jump_start_time(update : CmdPostPhysUpdate;
                                    human_net_phys : HumanActor;
                                    var human_phys__jumpStartTime : float&)
  assume jumpStartTime = human_net_phys.phys.currentState.jumpStartTime
  if jumpStartTime > 0.
    human_phys__jumpStartTime = jumpStartTime

[es(after=human_phys_set_in_air_time)]
def human_phys_in_air_long(update : CmdPostPhysUpdate;
                           human_phys__afterJumpDampingTime : float;
                           human_phys__previousInAirTime : float;
                           human_phys__inAirTime : float;
                           human_phys__inAirTimeThreshold : float;
                           human_phys__inAirSpeedThreshold : float;
                           var human_phys__isInAirLong : bool&;
                           var human_net_phys : HumanActor&;
                           var human_phys__jumpEndTime : float&)
  assume currentState = human_net_phys.phys.currentState

  let wasInAir = was_in_air(human_phys__previousInAirTime, human_phys__inAirTimeThreshold)
  let isInAir = is_in_air(human_phys__inAirTime)

  if isInAir && wasInAir
    human_phys__isInAirLong = abs(currentState.velocity.y) > human_phys__inAirSpeedThreshold
  if !isInAir && human_phys__isInAirLong
    let physTime = float(update.tick) * update.dt
    human_phys__jumpEndTime = physTime
    human_phys__isInAirLong = false
    currentState.afterJumpDampingEndTime = human_phys__jumpEndTime + human_phys__afterJumpDampingTime

[es(after=human_phys_set_in_air_time)]
def human_phys_set_after_jump_damping(update : CmdPostPhysUpdate;
                                      human_phys__previousInAirTime : float;
                                      human_phys__inAirTime : float;
                                      human_phys__inAirTimeThreshold : float;
                                      human_phys__afterJumpDampingMinSpeedY : float;
                                      human_phys__afterJumpDampingMaxSpeedY : float;
                                      human_phys__afterJumpDampingMinHeight : float;
                                      human_phys__afterJumpDampingMaxHeight : float;
                                      var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  let isInAir = is_in_air(human_phys__inAirTime)
  let wasInAir = was_in_air(human_phys__previousInAirTime, human_phys__inAirTimeThreshold)

  if !wasInAir && isInAir
    currentState.afterJumpDampingHeight = 1.f

  if isInAir && currentState.velocity.y < human_phys__afterJumpDampingMinSpeedY
    currentState.afterJumpDampingHeight = min(
      currentState.afterJumpDampingHeight,
      cvt(currentState.velocity.y, human_phys__afterJumpDampingMinSpeedY, human_phys__afterJumpDampingMaxSpeedY,
                                   human_phys__afterJumpDampingMinHeight, human_phys__afterJumpDampingMaxHeight))


def update_friction(var human_net_phys : HumanActor&; human_phys__crawlTransitionFrictionMult)
  assume currentState = human_net_phys.phys.currentState
  let isGointToCrawl = (int(currentState.states) & int(StateFlag.ST_CRAWL)) != 0 && !currentState.isCrawl
  currentState.frictionMult = isGointToCrawl ? human_phys__crawlTransitionFrictionMult : 1.0

[es(tag=netClient, REQUIRE=hero)]
def human_phys_set_crawl_transition_friction_local(info : ParallelUpdateFrameDelayed;
                                                   human_phys__crawlTransitionFrictionMult : float;
                                                   var human_net_phys : HumanActor&)
  update_friction(human_net_phys, human_phys__crawlTransitionFrictionMult)

[es(tag=server)]
def human_phys_set_crawl_transition_friction(info : ParallelUpdateFrameDelayed;
                                             human_phys__crawlTransitionFrictionMult : float;
                                             var human_net_phys : HumanActor&)
  update_friction(human_net_phys, human_phys__crawlTransitionFrictionMult)

[es(after=keep_human_net_phys_cur_state_es)]
def keep_human_net_phys_zoom_render_state_es(info : UpdateStageInfoAct;
                                             human_net_phys__isZooming : bool;
                                             var human_net_phys__isZoomingRenderData : bool&)
  human_net_phys__isZoomingRenderData = human_net_phys__isZooming

[es(no_order, REQUIRE_NOT=deadEntity)]
def keep_human_net_phys_cur_state_es(info : ParallelUpdateFrameDelayed;
                                     human_net_phys : HumanActor;
                                     var human_net_phys__curMoveState : int&;
                                     var human_net_phys__isHoldBreath : bool&;
                                     var human_net_phys__isSwimming : bool&;
                                     var human_net_phys__isUnderwater : bool&;
                                     var human_net_phys__isAiming : bool&;
                                     var human_net_phys__isOnGround : bool&;
                                     var human_net_phys__isCrawl : bool&;
                                     var human_net_phys__isCrouch : bool&;
                                     var human_net_phys__deltaVelIgnoreAmount : float&;
                                     var human_net_phys__aimPosition : float&;
                                     var human_net_phys__standState : int&;
                                     var human_net_phys__isInAir : bool&;
                                     var human_net_phys__velocity : float3&;
                                     var human_net_phys__locationPos : DPoint3&;
                                     var human_net_phys__isHctAim : bool&;
                                     var human_net_phys__isHctShoot : bool&;
                                     var human_net_phys__isHoldGunModeBit : bool&;
                                     var human_net_phys__maxStamina : float&;
                                     var human_net_phys__maxStaminaMult : float&;
                                     var human_net_phys__staminaBoostMult : float&;
                                     var human_net_phys__isZooming : bool&;
                                     var human_net_phys__torsoContactMatId : int&;
                                     var human_net_phys__isCrawlingMove : bool&;
                                     var human_net_phys__isLadderQuickMovingDown : bool&)
  assume currentState = human_net_phys.phys.currentState

  human_net_phys__curMoveState = int(currentState.moveState)
  human_net_phys__isHoldBreath = is_hold_breath(currentState)
  human_net_phys__isSwimming = human_phys_state_get_is_swimming(currentState)
  human_net_phys__isUnderwater = human_phys_state_get_is_underwater(currentState)
  human_net_phys__isAiming = currentState.isAiming
  human_net_phys__isCrawl = currentState.isCrawl
  human_net_phys__isCrouch = currentState.isCrouch
  human_net_phys__isOnGround = (uint(currentState.states) & uint(StateFlag.ST_ON_GROUND)) != 0u
  human_net_phys__deltaVelIgnoreAmount = currentState.deltaVelIgnoreAmount
  human_net_phys__velocity = currentState.velocity
  human_net_phys__aimPosition = currentState.aimPosition
  human_net_phys__standState = int(currentState.standState)
  human_net_phys__isInAir = (uint(currentState.isInAirHistory) & 1u) != 0u && (uint(currentState.states) & uint(StateFlag.ST_SWIM)) == 0u
  human_net_phys__locationPos = currentState.location.P
  human_net_phys__isHctAim = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_AIM)
  human_net_phys__isHctShoot = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_SHOOT)
  human_net_phys__isHoldGunModeBit = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType.HCT_HOLD_GUN_MODE)
  human_net_phys__maxStamina = human_net_phys.phys.maxStamina
  human_net_phys__maxStaminaMult = human_net_phys.phys.currentState.maxStaminaMult
  human_net_phys__staminaBoostMult = human_net_phys.phys.currentState.staminaBoostMult
  human_net_phys__isZooming = human_net_phys.phys.currentState.isZooming
  human_net_phys__torsoContactMatId = human_net_phys.phys.currentState.torsoContactMatId
  human_net_phys__isCrawlingMove = currentState.standState == HUStandState.ESS_CRAWL && currentState.moveState != HUMoveState.EMS_STAND
  human_net_phys__isLadderQuickMovingDown = human_phys_state_get_isLadderQuickMovingDown(human_net_phys.phys.currentState)

[es(after=before_net_phys_sync, before=after_net_phys_sync)]
def human_phys_save_weap_state_es(info : ParallelUpdateFrameDelayed;
                                  human_net_phys : HumanActor;
                                  var human_net_phys__weapEquipCurState : int&;
                                  var human_net_phys__weapEquipNextSlot : int&)
  human_net_phys__weapEquipCurState = int(human_net_phys.phys.currentState.weapEquipState.curState)
  human_net_phys__weapEquipNextSlot = int(human_net_phys.phys.currentState.weapEquipState.nextSlot)

[es]
def reset_delayed_jump_in_transition_to_crawl(update : CmdPostPhysUpdate;
                                              human_phys__crawlThreshold : float;
                                              var human_net_phys : HumanActor)
  assume currentState = human_net_phys.phys.currentState
  if currentState.height < human_phys__crawlThreshold
    currentState.jumpStartTime = -1.

[es(after=sprint_leap_es, REQUIRE=human__canFastProne)]
def fast_crawl_es(evt : CmdPostPhysUpdate;
                  human_net_phys : HumanActor;
                  human_net_phys__isCrawl : bool;
                  human_net_phys__isCrouch : bool;
                  human_net_phys__isOnGround : bool;
                  human_net_phys__attachedToLadder : bool;
                  human_sprint_leap__isLeaping : bool;
                  human_fast_prone_anim__duration : float;
                  var human_fast_prone__inProgress : bool&;
                  var human_fast_prone__startTime : float&)
  assume appliedCT = human_net_phys.phys.appliedCT
  let curTime = float(evt.tick) * evt.dt
  if !human_fast_prone__inProgress
    let isCrawlPressed = is_control_bit_set(appliedCT, HumanPhysControlType.HCT_CRAWL)
    let willFastCrawl = isCrawlPressed && !human_sprint_leap__isLeaping && human_net_phys__isOnGround && !human_net_phys__attachedToLadder && !human_net_phys__isCrawl && !human_net_phys__isCrouch
    if willFastCrawl
      human_fast_prone__inProgress = true
      human_fast_prone__startTime = curTime
    else
      return

  if human_fast_prone__inProgress && curTime > human_fast_prone__startTime + human_fast_prone_anim__duration
    human_fast_prone__inProgress = false

[es]
def sprint_leap_es(evt : CmdPostPhysUpdate;
                   human_net_phys__isCrawl : bool;
                   human_net_phys__attachedToLadder : bool;
                   human_sprint_leap__speedThreshold : float;
                   human_sprint_leap__acceleration : float;
                   human_sprint_leap__staminaDrain : float;
                   human_sprint_leap__traceStartHeight : float;
                   human_sprint_leap_anim__startStateDuration : float;
                   human_sprint_leap_anim__endStateDuration : float;
                   human_sprint_leap__traceLength : float;
                   human_sprint_leap__frictionlessDuration : float;
                   var human_sprint_leap__isAboutToHitGround : bool&;
                   var human_sprint_leap__isLeaping : bool&;
                   var human_sprint_leap__isFalling : bool&;
                   var human_sprint_leap__dampingStartTime : float&;
                   var human_sprint_leap_anim__startStateStartedAtTime : float&;
                   var human_sprint_leap_anim__endStateStartedAtTime : float&;
                   var human_net_phys__isOnGround : bool&;
                   var human_net_phys : HumanActor&)
  assume currentState = human_net_phys.phys.currentState
  assume previousState = human_net_phys.phys.previousState
  assume appliedCT = human_net_phys.phys.appliedCT

  let curTime = float(evt.tick) * evt.dt

  if curTime > human_sprint_leap_anim__startStateStartedAtTime + human_sprint_leap__frictionlessDuration
    human_net_phys.phys.isInSprintLeap = false

  if !human_sprint_leap__isLeaping
    let sprintVelocity = currentState.velocity.xz
    let wasSprinting = (int(previousState.states) & int(StateFlag.ST_SPRINT)) != 0
    let isSprinting = (int(currentState.states) & int(StateFlag.ST_SPRINT)) != 0
    let velocityHighEnough = length_sq(sprintVelocity) > square(human_sprint_leap__speedThreshold)
    let isCrawlPressed = is_control_bit_set(appliedCT, HumanPhysControlType.HCT_CRAWL)

    let willSprintLeap = velocityHighEnough && isCrawlPressed && human_net_phys__isOnGround && !isSprinting && wasSprinting && !human_net_phys__attachedToLadder && currentState.stamina > 0.0 && !human_net_phys__isCrawl

    if willSprintLeap
      human_sprint_leap__isLeaping = true
      human_net_phys__isOnGround = false
      human_net_phys.phys.isInSprintLeap = true

      let sprintDirection = normalize(float3(sprintVelocity.x, 0.0, sprintVelocity.y))
      currentState.velocity = currentState.velocity + sprintDirection * human_sprint_leap__acceleration * evt.dt
      currentState.stamina = max(currentState.stamina - human_sprint_leap__staminaDrain, 0.0)
      human_sprint_leap__dampingStartTime = curTime
      human_sprint_leap_anim__startStateStartedAtTime = curTime

  if !human_sprint_leap__isLeaping
    return

  let traceToStartFalling = !human_sprint_leap__isFalling && !human_sprint_leap__isAboutToHitGround && curTime > human_sprint_leap_anim__startStateStartedAtTime + human_sprint_leap_anim__startStateDuration
  if human_sprint_leap__isFalling || traceToStartFalling
    let from = float3(currentState.location.P) + float3(0.0, human_sprint_leap__traceStartHeight, 0.0)
    let dir = float3(0, -1, 0)
    var norm : float3
    var t = human_sprint_leap__traceLength
    var pmid : int
    var riDesc = RendInstDesc()
    let rayMatId : int
    if traceray_normalized(from, dir, t, pmid, norm, ETF_DEFAULT, riDesc, rayMatId)
      human_sprint_leap__isAboutToHitGround = true
      human_sprint_leap__isFalling = false
      human_sprint_leap_anim__endStateStartedAtTime = curTime
    else
      human_sprint_leap__isAboutToHitGround = false
      human_sprint_leap__isFalling = true

  if human_sprint_leap__isLeaping && human_sprint_leap__isAboutToHitGround && human_net_phys__isOnGround && curTime > human_sprint_leap_anim__endStateStartedAtTime + human_sprint_leap_anim__endStateDuration
    human_sprint_leap__isLeaping = false
    human_sprint_leap__isFalling = false
    human_sprint_leap__isAboutToHitGround = false

[es]
def save_data_on_post_phys_update_es(evt : CmdPostPhysUpdate;
                                     active : bool;
                                     human_net_phys : HumanActor;
                                     var human_net_phys__isClimbing : bool&;
                                     var human_net_phys__climbToPos : float3&;
                                     var human_net_phys__states : int&;
                                     var human_net_phys__aimDir : float3&;
                                     var human_weap__curGunSlot : int&;
                                     var human_net_phys__isFastClimbing : bool?;
                                     var human_net_phys__isClimbingOverObstacle : bool?;
                                     var human_net_phys__climbPosBehindObstacle : float3?)
  if !active
    return
  assume currentState = human_net_phys.phys.currentState

  human_net_phys__isClimbing = human_phys_state_get_isClimbing(currentState)
  human_net_phys__climbToPos = currentState.climbToPos
  human_net_phys__states = int(currentState.states)
  human_net_phys__aimDir = currentState.gunDir

  if human_net_phys__isFastClimbing != null
    *human_net_phys__isFastClimbing = human_phys_state_get_isFastClimbing(currentState)
  if human_net_phys__isClimbingOverObstacle != null
    *human_net_phys__isClimbingOverObstacle = human_phys_state_get_isClimbingOverObstacle(currentState)
  if human_net_phys__climbPosBehindObstacle != null
    *human_net_phys__climbPosBehindObstacle = currentState.climbPosBehindObstacle

  human_weap__curGunSlot = int(currentState.weapEquipState.curSlot)

[es]
def human_phys_set_simplified_phys_es(evt : CmdPrePhysUpdate;
                                      human_net_phys__isSimplifiedPhys : bool;
                                      human_net_phys__isSimplifiedQueryWalkPosition : bool;
                                      var human_net_phys : HumanActor&)
  human_net_phys.phys.isSimplifiedPhys = human_net_phys__isSimplifiedPhys
  human_net_phys.phys.isSimplifiedQueryWalkPosition = human_net_phys__isSimplifiedQueryWalkPosition

[es(after=before_net_phys_sync )]
def human_pre_phys_ladder_update_es(evt : CmdPrePhysUpdate;
                                    unit__ref : UnitRef;
                                    possessedByPlr : EntityId;
                                    human_ladder__ladderTm : float3x4;
                                    human_ladder__numSteps : int;
                                    var human_net_phys : HumanActor&;
                                    var human_ladder__attached : bool&;
                                    beh_tree__enabled : bool = false;
                                    beh_tree__usingLadders : bool = false)
  let unitRoleMask = uint(unit__ref.unit.role)
  let isNetClient = !is_server()
  let isAuthority = (unitRoleMask & uint(NetRole.URF_AUTHORITY)) != 0u
  let isLocal = (unitRoleMask & uint(NetRole.URF_LOCAL_CONTROL)) != 0u
  if (isAuthority && !possessedByPlr && beh_tree__enabled && !beh_tree__usingLadders)
    human_ladder__attached = false
  if (isNetClient || isLocal || isAuthority)
    human_net_phys.phys.currentState.ladderTm = human_ladder__ladderTm
    human_phys_state_set_attachedToLadder(human_net_phys.phys.currentState, human_ladder__attached)
    human_net_phys.phys.currentState.ladderNumSteps = uint16(human_ladder__numSteps)

def stop_human_moving(var human_net_phys : HumanActor&)
  
  
  
  assume producedCT = human_net_phys.phys.producedCT
  assume currentState = human_net_phys.phys.currentState
  let isCrouch = (uint(currentState.states) & uint(StateFlag.ST_CROUCH)) != 0u
  let isCrawl = (uint(currentState.states) & uint(StateFlag.ST_CRAWL)) != 0u
  producedCT |> human_control_state_set_neutral_ctrl()
  producedCT |> human_control_state_set_walk_speed(0.f)
  producedCT |> human_control_state_set_wish_shoot_dir(currentState.gunDir)
  producedCT |> human_control_state_set_wish_look_dir(currentState.headDir)
  producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CROUCH, isCrouch)
  producedCT |> human_control_state_set_control_bit(HumanPhysControlType.HCT_CRAWL, isCrawl)
  producedCT |> set_chosen_weapon(currentState.weapEquipState.nextSlot)
  currentState.weapEquipState.curSlot = currentState.weapEquipState.nextSlot

[es(tag=gameClient, track=human__controlledDrone)]
def human_launch_drone_idle_control(evt : Event;
                                    human__controlledDrone : EntityId;
                                    var human_net_phys : HumanActor&)
  if human__controlledDrone != INVALID_ENTITY_ID
    stop_human_moving(human_net_phys)

[es(tag=(server, net), after=before_net_phys_sync)]
def human_pre_phys_idle_control(evt : CmdPrePhysUpdate;
                                unit__ref : UnitRef;
                                var human_net_phys__prevIsLocal : bool&;
                                var human_net_phys : HumanActor&)
  
  let unitRoleMask = uint(unit__ref.unit.role)
  let isAuthority = (unitRoleMask & uint(NetRole.URF_AUTHORITY)) != 0u
  let isLocal = (unitRoleMask & uint(NetRole.URF_LOCAL_CONTROL)) != 0u
  if isLocal && isAuthority && !human_net_phys__prevIsLocal
    stop_human_moving(human_net_phys)
  human_net_phys__prevIsLocal = isLocal
