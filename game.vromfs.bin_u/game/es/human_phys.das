require ecs
require app
require math.base
require DngHuman
require %game.events
require HumanPhys
require DagorMath
require Dacoll



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

[es]
def human_phys_set_in_air_time(update : CmdPostPhysUpdate;
                               human_net_phys : HumanActor;
                               var human_phys__previousInAirTime : float&;
                               var human_phys__inAirTime : float&;
                               isInVehicle : bool = false)
  assume currentState = human_net_phys.phys.currentState
  human_phys__previousInAirTime = human_phys__inAirTime
  let isInAir = (int(currentState.isInAirHistory) & 1) != 0 && (int(currentState.states) & int(StateFlag ST_SWIM)) == 0 && !isInVehicle
  human_phys__inAirTime = isInAir ? (human_phys__inAirTime + update.dt) : 0.f

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
  let isGointToCrawl = (int(currentState.states) & int(StateFlag ST_CRAWL)) != 0 && !currentState.isCrawl
  currentState.frictionMult = isGointToCrawl ? human_phys__crawlTransitionFrictionMult : 1.0

[es(tag=netClient, before=human_phys_es, REQUIRE=hero)]
def human_phys_set_crawl_transition_friction_local(info : ParallelUpdateFrameDelayed;
                                                   human_phys__crawlTransitionFrictionMult : float;
                                                   var human_net_phys : HumanActor&)
  update_friction(human_net_phys, human_phys__crawlTransitionFrictionMult)

[es(tag=server, before=human_phys_es)]
def human_phys_set_crawl_transition_friction(info : ParallelUpdateFrameDelayed;
                                             human_phys__crawlTransitionFrictionMult : float;
                                             var human_net_phys : HumanActor&)
  update_friction(human_net_phys, human_phys__crawlTransitionFrictionMult)

[es(after=keep_human_net_phys_cur_state_es)]
def keep_human_net_phys_zoom_render_state_es(info : UpdateStageInfoAct;
                                             human_net_phys__isZooming : bool;
                                             var human_net_phys__isZoomingRenderData : bool&)
  human_net_phys__isZoomingRenderData = human_net_phys__isZooming

[es(after=human_phys_es)]
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
  human_net_phys__isOnGround = (uint(currentState.states) & uint(StateFlag ST_ON_GROUND)) != 0u
  human_net_phys__deltaVelIgnoreAmount = currentState.deltaVelIgnoreAmount
  human_net_phys__velocity = currentState.velocity
  human_net_phys__aimPosition = currentState.aimPosition
  human_net_phys__standState = int(currentState.standState)
  human_net_phys__isInAir = (uint(currentState.isInAirHistory) & 1u) != 0u && (uint(currentState.states) & uint(StateFlag ST_SWIM)) == 0u
  human_net_phys__locationPos = currentState.location.P
  human_net_phys__isHctAim = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType HCT_AIM)
  human_net_phys__isHctShoot = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType HCT_SHOOT)
  human_net_phys__isHoldGunModeBit = is_control_bit_set(human_net_phys.phys.appliedCT, HumanPhysControlType HCT_HOLD_GUN_MODE)
  human_net_phys__maxStamina = human_net_phys.phys.maxStamina
  human_net_phys__maxStaminaMult = human_net_phys.phys.currentState.maxStaminaMult
  human_net_phys__staminaBoostMult = human_net_phys.phys.currentState.staminaBoostMult
  human_net_phys__isZooming = human_net_phys.phys.currentState.isZooming
  human_net_phys__torsoContactMatId = human_net_phys.phys.currentState.torsoContactMatId
  human_net_phys__isCrawlingMove = currentState.standState == HUStandState ESS_CRAWL && currentState.moveState != HUMoveState EMS_STAND
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
    let isCrawlPressed = is_control_bit_set(appliedCT, HumanPhysControlType HCT_CRAWL)
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

  if !human_sprint_leap__isLeaping
    let sprintVelocity = currentState.velocity.xz
    let wasSprinting = (int(previousState.states) & int(StateFlag ST_SPRINT)) != 0
    let isSprinting = (int(currentState.states) & int(StateFlag ST_SPRINT)) != 0
    let velocityHighEnough = length_sq(sprintVelocity) > square(human_sprint_leap__speedThreshold)
    let isCrawlPressed = is_control_bit_set(appliedCT, HumanPhysControlType HCT_CRAWL)

    let willSprintLeap = velocityHighEnough && isCrawlPressed && human_net_phys__isOnGround && !isSprinting && wasSprinting && !human_net_phys__attachedToLadder && currentState.stamina > 0.0 && !human_net_phys__isCrawl

    if willSprintLeap
      human_sprint_leap__isLeaping = true
      human_net_phys__isOnGround = false

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
    var rayMatId : int
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
