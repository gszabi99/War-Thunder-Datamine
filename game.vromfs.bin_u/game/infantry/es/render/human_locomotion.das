require ecs
require math.base
require DagorMath
require DngHuman
require %game.events

[es(tag=gameClient, after=(after_net_phys_sync, mm_calculate_root_offset_es), before=before_animchar_update_sync)]
def human_locomotion_es(info : ParallelUpdateFrameDelayed;
                        eid : EntityId;
                        human_net_phys : HumanActor;
                        locomotionParams : float4;
                        locomotionFactor : float;
                        locomotionVelFactorMod : float;
                        locomotion__walkMult : float;
                        locomotion__runMult : float;
                        locomotion__sprintMult : float;
                        var transform : float3x4&;
                        var prevLocoVel : float3&;
                        var prevLocoAcc : float3&;
                        var prevLocoQuat : float4&)
  var isInCockpitCam = false
  query() <| $ [es] (isHeroCockpitCam : bool; camera__target : EntityId; camera__active : bool)
    if camera__active && camera__target == eid
      isInCockpitCam = isHeroCockpitCam
  if isInCockpitCam
    return
  let interpK = get_phys_interpk_clamped(human_net_phys.phys, info.curTime)
  var vel = lerp(human_net_phys.phys.previousState.velocity, human_net_phys.phys.currentState.velocity, interpK)
  var acc = lerp(human_net_phys.phys.previousState.acceleration, human_net_phys.phys.currentState.acceleration, interpK)
  var locoMoveMult = 0.f
  if human_net_phys.phys.currentState.moveState == HUMoveState.EMS_WALK
    locoMoveMult = locomotion__walkMult
  elif human_net_phys.phys.currentState.moveState == HUMoveState.EMS_RUN
    locoMoveMult = locomotion__runMult
  elif human_net_phys.phys.currentState.moveState == HUMoveState.EMS_SPRINT
    locoMoveMult = locomotion__sprintMult
  vel *= locoMoveMult
  acc *= locoMoveMult

  vel = approach(prevLocoVel, vel, info.dt, locomotionParams.x)
  acc = approach(prevLocoAcc, acc, info.dt, locomotionParams.y)

  let isOnGround = (uint(human_net_phys.phys.currentState.states) & uint(StateFlag.ST_ON_GROUND)) != 0u
  var qDefl = quat(0f, 0f, 0f, 1f)

  var locoFactor = locomotionFactor
  if locomotionVelFactorMod >= 0.0f
    locoFactor *= clamp(length_sq(vel) * locomotionVelFactorMod, 0.f, 1.f);
  if isOnGround && locoFactor > 0f
    let lim = locomotionParams.w * DEG_TO_RAD
    let axis = float3(dot(transform[2], acc), 0.f, dot(-transform[0], acc)) 
    qDefl = quat(normalize(axis), clamp(length(axis) * locoFactor, -lim, lim))

  qDefl = normalize(approach(quat(prevLocoQuat), qDefl, info.dt, locomotionParams.z));
  if abs(float4(qDefl).w) < 1f
    var qtm : float3x4
    make_tm(qDefl, qtm)
    transform = transform * qtm

  prevLocoVel = vel
  prevLocoAcc = acc
  prevLocoQuat = float4(qDefl)
