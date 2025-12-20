require ecs
require app
require math.base
require AnimV20
require DngHuman
require DagorMath
require MotionMatching
require %game.events


[es(tag=gameClient, after=after_net_phys_sync, before=mm_trajectory_prediction)]
def motion_matching_set_wish_speed(act : ParallelUpdateFrameDelayed;
                                   human_net_phys : HumanActor;
                                   var mm_trajectory__wishLinearVelocity : float3&)
  assume phys = human_net_phys.phys
  assume currentState = phys.currentState
  if phys.currentState.isWishToMove
    var wishMoveState = currentState.moveState
    let reduceToWalk = human_phys_state_get_reduceToWalk(currentState)
    let isAiming = currentState.isAiming
    let walkDotOrient = phys.appliedCT.walkDir.x
    let walkDotOrientThreshold = 0.64f 
    let isDowned = human_phys_state_get_is_downed(currentState)
    let ableToRun = (!reduceToWalk && !isAiming && !(abs(currentState.leanPosition) > FLT_EPSILON) && !isDowned &&
                     walkDotOrient >= walkDotOrientThreshold)
    if phys.currentState.moveState == HUMoveState.EMS_WALK && ableToRun
      wishMoveState = HUMoveState.EMS_RUN
    var wishSpeed = phys |> human_phys_getWalkSpeed(phys.currentState.standState, wishMoveState)
    let useMoveSpeedMult = (phys.currentState.standState != HUStandState.ESS_CROUCH &&
                            phys.currentState.standState != HUStandState.ESS_CRAWL &&
                            phys.currentState.standState != HUStandState.ESS_DOWNED)
    wishSpeed *= useMoveSpeedMult ? phys.currentState.moveSpeedMult : phys.currentState.crawlCrouchSpeedMult
    if phys.currentState.moveState == HUMoveState.EMS_SPRINT
      wishSpeed *= phys.currentState.sprintSpeedMult
      if phys.currentState.sprintLerpSpeedMult != 1.f
        let runSpeed = phys |> human_phys_getWalkSpeed(phys.currentState.standState, HUMoveState.EMS_RUN) * phys.currentState.moveSpeedMult
        wishSpeed = lerp(runSpeed, wishSpeed, phys.currentState.sprintLerpSpeedMult)
    let bodyDir = float3(phys.currentState.bodyOrientDir.x, 0.0, phys.currentState.bodyOrientDir.y)
    
    
    let velDir = phys.currentState.moveState == HUMoveState.EMS_SPRINT ? bodyDir : normalize(phys.currentState.velocity)
    mm_trajectory__wishLinearVelocity = velDir * wishSpeed
  else
    mm_trajectory__wishLinearVelocity = float3(0f)

[es(tag=gameClient, REQUIRE=mm_trajectory__customUpdate, after=mm_update_root_orientation_es,
    before=(mm_calculate_root_offset_es, mm_trajectory_track_history))]
def motion_matching_update_trajectory(act : ParallelUpdateFrameDelayed;
                                      human_net_phys : HumanActor;
                                      animchar : AnimcharBaseComponent;
                                      mm_trajectory__linearVelocityViscosity : float;
                                      mm_trajectory__angularVelocityViscosity : float;
                                      var motion_matching__controller : MotionMatchingController;
                                      var mm_trajectory__prevPosition : float3&;
                                      var mm_trajectory__prevRotation : float4&;
                                      var mm_trajectory__currPosition : float3&;
                                      var mm_trajectory__currRotation : float4&;
                                      var mm_trajectory__linearVelocity : float3&;
                                      var mm_trajectory__angularVelocity : float3&;
                                      var mm_trajectory__wishRotation : float4&;
                                      var mm_trajectory__historyPositions : Point3List)
  assume curState = human_net_phys.phys.currentState
  
  mm_trajectory__prevPosition = mm_trajectory__currPosition
  var animcharTm : float3x4
  animchar |> animchar_get_tm(animcharTm)
  mm_trajectory__currPosition = animcharTm[3]
  let curVelocity = (mm_trajectory__currPosition - mm_trajectory__prevPosition) / (act.dt + 0.00001f) - curState.standingVelocity
  mm_trajectory__linearVelocity = approach(mm_trajectory__linearVelocity, curVelocity, act.dt, mm_trajectory__linearVelocityViscosity)

  for historyPos in mm_trajectory__historyPositions
    historyPos += curState.standingVelocity * act.dt

  
  mm_trajectory__prevRotation = mm_trajectory__currRotation
  mm_trajectory__currRotation = motion_matching__controller.rootRotation
  let q = quat(mm_trajectory__currRotation) * inverse(quat(mm_trajectory__prevRotation))
  var angles : float3
  quat_to_euler(q, angles.x, angles.y, angles.z)
  let currAngVelocity = float3(0f, safediv(angles.x, act.dt), 0f)
  mm_trajectory__angularVelocity = approach(mm_trajectory__angularVelocity, currAngVelocity, act.dt,
    mm_trajectory__angularVelocityViscosity)

  if curState.moveState == HUMoveState.EMS_ROTATE_LEFT || curState.moveState == HUMoveState.EMS_ROTATE_RIGHT
    mm_trajectory__wishRotation = math::quat(animcharTm)
  else
    let bodyDir = float3(curState.bodyOrientDir.x, 0.0, curState.bodyOrientDir.y)
    mm_trajectory__wishRotation = quat_from_unit_arc(MotionMatching::FORWARD_DIRECTION.xyz, bodyDir)

  if (curState.moveState == HUMoveState.EMS_ROTATE_LEFT ||
      curState.moveState == HUMoveState.EMS_ROTATE_RIGHT ||
      curState.moveState == HUMoveState.EMS_STAND)
    motion_matching__controller.rootAdjustmentRot = false
  else
    motion_matching__controller.rootAdjustmentRot = true

  if curState.moveState == HUMoveState.EMS_SPRINT
    
    
    motion_matching__controller.rootClampingMaxAngle = 0f
  else
    motion_matching__controller.rootClampingMaxAngle = PI * 0.6f

[es(tag=gameClient, on_appear, track=human_anim__isFpv)]
def motion_matching_init_root_parameters(evt : Event;
                                         human_anim__isFpv : bool;
                                         var motion_matching__controller : MotionMatchingController)
  motion_matching__controller.rootSynchronization = false
  motion_matching__controller.rootAdjustmentPos = true
  motion_matching__controller.rootAdjustmentVelocityRatio = -1f
  motion_matching__controller.rootAdjustmentRot = true
  motion_matching__controller.rootAdjustmentRotHalfLife = 0.1f
  motion_matching__controller.rootAdjustmentAngVelocityRatio = -1f
  motion_matching__controller.rootClamping = true
  motion_matching__controller.rootClampingMaxDistance = human_anim__isFpv ? 0f : 0.15f
