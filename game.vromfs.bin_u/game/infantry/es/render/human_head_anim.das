require ecs
require AppTime
require math.base
require DagorMath
require DagorMathUtils
require DagorSystem
require DngHuman
require HumanPhys
require WTPhysActor
require PhysVars
require %game.events

def private calc_head_pitch_yaw(state : HumanPhysState)
  let localGunDir = inverse(state.location.O.quat) * state.gunDir
  let localHeadDir = inverse(state.location.O.quat) * state.headDir
  let yawPitch = float2(-atan2(localGunDir.z, localGunDir.x), atan2(localGunDir.y, length(localGunDir.xz)))
  return float2(-atan2(localHeadDir.z, localHeadDir.x) - yawPitch.x,
                 atan2(localHeadDir.y, length(localHeadDir.xz)) - yawPitch.y)

def calc_head_roll_pitch_yaw(actor : HumanActor;
                             at_time : float;
                             head_additional_roll : float;
                             head_additional_pitch : float;
                             head_additional_yaw : float;
                             var head_roll : float&;
                             var head_pitch : float&;
                             var head_yaw : float&)
  assume phys = actor.phys
  let interpK = get_phys_interpk_clamped(phys, at_time)
  let prevHead = calc_head_pitch_yaw(phys.previousState)
  let curHead = calc_head_pitch_yaw(phys.currentState)

  head_roll = clamp(deg_to_rad(head_additional_roll), deg_to_rad(-30.0), deg_to_rad(30.0))
  head_yaw = clamp(lerp(prevHead.x, curHead.x, interpK) + deg_to_rad(head_additional_yaw), deg_to_rad(-45.0), deg_to_rad(45.0))
  head_pitch = clamp(lerp(prevHead.y, curHead.y, interpK) + deg_to_rad(head_additional_pitch), deg_to_rad(-70.0), deg_to_rad(60.0))

[es(tag=gameClient, REQUIRE_NOT=animchar__actOnDemand, after=human_anim_fpv)]
def human_head_anim_es(info : ParallelUpdateFrameDelayed;
                       animchar__updatable : bool;
                       animchar__visible : bool = true;
                       human_net_phys : HumanActor;
                       human__controlledDrone : EntityId = INVALID_ENTITY_ID;
                       human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                       human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                       human_head_dir__interpolationSpeed : float;
                       prevLocoQuat : float4 = float4(0.0, 0.0, 0.0, 1.0);
                       human_anim__headYawRotVisc : float = 0.2;
                       human_anim__headRollInAim : float = 22.0;
                       human_anim__headRollSpeed : float = 7.0;
                       human_anim__headRollViscosity : float = 0.1;
                       human_anim__isFpv : bool = false;
                       human_anim__headYawVarId : int;
                       human_anim__headRollVarId : int;
                       human_anim__headPitchVarId : int;
                       human_head_dir__idleYaw : float = 0.0;
                       human_head_dir__idlePitch : float = 0.0;
                       var phys_vars : PhysVars;
                       var human_head_dir__aimRoll : float&;
                       var human_head_dir__prevAdditionalRoll : float&;
                       var human_head_dir__prevAdditionalPitch : float&;
                       var human_head_dir__prevAdditionalYaw : float&)
  if !animchar__updatable || !animchar__visible
    return

  var additionalHeadRoll = 0.0
  var additionalHeadPitch = 0.0
  var additionalHeadYaw = 0.0

  let currentGunEid = (human_weap__currentGunEid != INVALID_ENTITY_ID
                    ?  human_weap__currentGunEid
                    :  human_attached_gun__attachedGunEid)
  query(currentGunEid) <| $ [es] (gun__additionalHeadRoll : float = 0.0;
                                  gun__additionalHeadPitch : float = 0.0;
                                  gun__additionalHeadYaw : float = 0.0;
                                  gun__additionalHeadRollInCrawlMult : float = 1.0;
                                  gun__additionalHeadPitchInCrawlMult : float = 1.0;
                                  gun__additionalHeadYawInCrawlMult : float = 1.0)
    let isCrawl = human_net_phys.phys.currentState.isCrawl
    let rollMult = isCrawl ? gun__additionalHeadRollInCrawlMult : 1.0
    let pitchMult = isCrawl ? gun__additionalHeadPitchInCrawlMult : 1.0
    let yawMult = isCrawl ? gun__additionalHeadYawInCrawlMult : 1.0
    additionalHeadRoll = lerp(human_head_dir__prevAdditionalRoll, gun__additionalHeadRoll * rollMult, human_head_dir__interpolationSpeed)
    additionalHeadPitch = lerp(human_head_dir__prevAdditionalPitch, gun__additionalHeadPitch * pitchMult, human_head_dir__interpolationSpeed)
    additionalHeadYaw = lerp(human_head_dir__prevAdditionalYaw, gun__additionalHeadYaw * yawMult, human_head_dir__interpolationSpeed)
    human_head_dir__prevAdditionalRoll = additionalHeadRoll
    human_head_dir__prevAdditionalPitch = additionalHeadPitch
    human_head_dir__prevAdditionalYaw = additionalHeadYaw

  additionalHeadYaw += human_head_dir__idleYaw
  additionalHeadPitch += human_head_dir__idlePitch

  var headRoll : float
  var headPitch : float
  var headYaw : float

  if human__controlledDrone == INVALID_ENTITY_ID
    calc_head_roll_pitch_yaw(human_net_phys, info.curTime,
                            additionalHeadRoll, additionalHeadPitch, additionalHeadYaw,
                            headRoll, headPitch, headYaw)

    assume phys = human_net_phys.phys
    let interpK = get_phys_interpk_clamped(phys, get_sync_time())

    if phys.currentState.isAiming
      let breathOffset = lerp(phys.previousState.breathOffset, phys.currentState.breathOffset, float2(interpK))
      headYaw += breathOffset.x * 0.9
      headPitch += breathOffset.y * 0.9
      var hd : float
      var att : float
      var bank : float
      let q = quat(prevLocoQuat)
      quat_to_euler(q, hd, att, bank)
      headPitch += att
      headPitch = max(0.0, headPitch)

  let prevHeadYawVar = phys_vars |> getVar(human_anim__headYawVarId)
  let newHeadYawVar = approach(prevHeadYawVar, rad_to_deg(headYaw),
                               info.dt, human_anim__headYawRotVisc)

  assume phys = human_net_phys.phys
  assume state = phys.currentState
  let canApplyAimRoll = !human_anim__isFpv && human__controlledDrone == INVALID_ENTITY_ID
  let isAiming = human_phys_state_can_aim(state) && is_control_bit_set(phys.appliedCT, HumanPhysControlType.HCT_AIM)
  let aimRollTarget = isAiming ? human_anim__headRollInAim : 0.0
  let aimRollStep = move_to(human_head_dir__aimRoll, aimRollTarget, info.dt, human_anim__headRollSpeed)
  let aimRoll = approach(aimRollStep, aimRollTarget, info.dt, human_anim__headRollViscosity)
  human_head_dir__aimRoll = canApplyAimRoll ? aimRoll : 0.0
  phys_vars |> setVar(human_anim__headRollVarId, rad_to_deg(headRoll) + human_head_dir__aimRoll)
  phys_vars |> setVar(human_anim__headPitchVarId, rad_to_deg(headPitch))
  phys_vars |> setVar(human_anim__headYawVarId, newHeadYawVar)
