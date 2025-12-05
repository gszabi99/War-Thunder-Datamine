require ecs
require app
require AnimV20
require math.base
require DngHumanAnim
require DngHuman
require WTPhysActor
require PhysVars
require PhysDecl
require HumanPhys
require HumanAnim
require DagorMath
require DngWeapon
require DagorRandom
require DagorSystem
require ecs.soa_template
require ecs.safe
require CollRes
require DagorMathUtils

require %appGame.wt_events
require %game.events


[es(on_appear, before=anim_phys_init_es)]
def init_human_anim_vars(evt : Event;
                         var phys_vars : PhysVars;
                         var human_anim__gunPitchVarId : int&;
                         var human_anim__persCourseVarId : int&;
                         var human_anim__changeWeaponVarId : int&;
                         var human_anim__changeDirVarId : int&;
                         var human_anim__reloadVarId : int&;
                         var human_anim__headRollVarId : int&;
                         var human_anim__headPitchVarId : int&;
                         var human_anim__headYawVarId : int&;
                         var human_anim__leanVarId : int&;
                         var human_anim__standHeightVarId : int&;
                         var human_anim__climbProgressVarId : int&;
                         var human_anim__ladderProgressVarId : int&;
                         var human_anim__vehicleSelectedVarId : int&;
                         var human_anim__seatTypeVarId : int&;
                         var human_anim__healItemSelectedVarId : int&;
                         var human_anim__hitPartsSelectedVarId : int&;
                         var human_anim__weaponYawVarId : int&;
                         var human_anim__weaponPitchVarId : int&;
                         var human_anim__weaponRollVarId : int&;
                         var human_anim__weaponOffsFwdVarId : int&;
                         var human_anim__weaponOffsUpVarId : int&;
                         var human_anim__weaponOffsLeftVarId : int&;
                         var human_anim__vertSpeedVarId : int&;
                         var human_anim__horizontalSpeedVarId : int&;
                         var human_anim__selectedWeaponVarId : int&)
  human_anim__gunPitchVarId = phys_vars |> registerVar("aim_pitch", 0.f)
  human_anim__persCourseVarId = phys_vars |> registerVar("pers_course", 0.f)
  human_anim__changeWeaponVarId = phys_vars |> registerVar("changeweapon_progress", 0.f)
  human_anim__changeDirVarId = phys_vars |> registerVar("changeweapon_dir", 1.f)
  human_anim__reloadVarId = phys_vars |> registerVar("reload_progress", 0.f)
  human_anim__headRollVarId = phys_vars |> registerVar("head_roll", 0.f)
  human_anim__headPitchVarId = phys_vars |> registerVar("head_pitch", 0.f)
  human_anim__headYawVarId = phys_vars |> registerVar("head_yaw", 0.f)
  human_anim__leanVarId = phys_vars |> registerVar("torso_lean", 0.f)
  human_anim__standHeightVarId = phys_vars |> registerVar("stand_height", 1.f)
  human_anim__climbProgressVarId = phys_vars |> registerVar("climb_progress", 0.f)
  human_anim__ladderProgressVarId = phys_vars |> registerVar("ladder_progress", 0.f)
  human_anim__vehicleSelectedVarId = phys_vars |> registerVar("vehicle_selected", 0.f)
  human_anim__seatTypeVarId = phys_vars |> registerVar("seat_type", 0.f)
  human_anim__healItemSelectedVarId = phys_vars |> registerVar("heal_item_selected", 0.f)
  human_anim__hitPartsSelectedVarId = phys_vars |> registerVar("hit_parts_selected", 0.f)
  human_anim__weaponYawVarId = phys_vars |> registerVar("recoil_yaw", 0.f)
  human_anim__weaponPitchVarId = phys_vars |> registerVar("recoil_pitch", 0.f)
  human_anim__weaponRollVarId = phys_vars |> registerVar("recoil_roll", 0.f)
  human_anim__weaponOffsFwdVarId = phys_vars |> registerVar("recoil_offset_along", 0.f)
  human_anim__weaponOffsUpVarId = phys_vars |> registerVar("recoil_offset_up", 0.f)
  human_anim__weaponOffsLeftVarId = phys_vars |> registerVar("recoil_offset_across", 0.f)
  human_anim__vertSpeedVarId = phys_vars |> registerVar("vert_speed", 0.f)
  human_anim__selectedWeaponVarId = phys_vars |> registerVar("weapon_selected", 0.0)
  human_anim__horizontalSpeedVarId = phys_vars |> registerVar("horizontal_speed", 0.0)


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

def calc_shoot_pitch(actor : HumanActor;
                     eid : EntityId;
                     at_time : float;
                     tm : float3x4;
                     var pitch : float&;
                     is_hero : bool)
  assume phys = actor.phys
  let interpK = get_phys_interpk_clamped(phys, at_time)
  let prevGun = dir_to_quat(phys.previousState.gunDir)
  let curGun = dir_to_quat(phys.currentState.gunDir)
  var interpGun = slerp(prevGun, curGun, interpK)
  let gun = get_human_gun(eid)
  var shootTm : float3x4
  make_tm(interpGun, shootTm)
  var shootDir = shootTm[0]
  let requiredNetRole = uint(NetRole.URF_LOCAL_CONTROL)
  if (uint(actor.role) & requiredNetRole) != 0u
    if gun != null && is_hero
      human_gun_get_shoot_tm(*gun, phys, at_time, shootTm)
      shootDir = shootTm[0]
      interpGun = DagorMath::quat(shootTm)
    elif get_human_gun_eid(eid) |> get_bool("gun__melee") ?? false
      shootDir = phys.producedCT.wishLookDir

  let y = dot(tm[1], shootDir)
  let x = dot(tm[0], shootDir)
  
  pitch = atan2(y, x < 0f ? 0f : x)

[es(tag=gameClient, REQUIRE_NOT=animchar__actOnDemand, no_order)]
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
                       human_anim__headYawVarId : int;
                       human_anim__headRollVarId : int;
                       human_anim__headPitchVarId : int;
                       var phys_vars : PhysVars;
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

  phys_vars |> setVar(human_anim__headRollVarId, rad_to_deg(headRoll))
  phys_vars |> setVar(human_anim__headPitchVarId, rad_to_deg(headPitch))
  phys_vars |> setVar(human_anim__headYawVarId, newHeadYawVar)

[es(on_appear, before=anim_phys_init_es)]
def init_to_crawl_transition_anim_id(evt : Event;
                                     animchar : AnimcharBaseComponent;
                                     human_anim__toCrawlTransitionAnim : string;
                                     human_anim__toCrawlTransitionVar : string;
                                     var phys_vars : PhysVars;
                                     var human_anim__toCrawlTransitionAnimId : int&;
                                     var human_anim__toCrawlTransitionVarId : int&)
  if animchar.animGraph != null
    human_anim__toCrawlTransitionAnimId = *animchar.animGraph |> anim_graph_getStateIdx(human_anim__toCrawlTransitionAnim)
    human_anim__toCrawlTransitionVarId = phys_vars |> registerVar(human_anim__toCrawlTransitionVar, 0.)

[es(on_appear)]
def init_bipod_anim_id(evt : Event;
                       human_anim__bipodVar : string;
                       var phys_vars : PhysVars;
                       var human_anim__bipodVarId : int&)
  human_anim__bipodVarId = phys_vars |> registerVar(human_anim__bipodVar, 0.)

[es(on_appear, before=anim_phys_init_es)]
def init_from_crawl_transition_anim_id(evt : Event;
                                       animchar : AnimcharBaseComponent;
                                       human_anim__fromCrawlTransitionAnim : string;
                                       human_anim__fromCrawlTransitionVar : string;
                                       var phys_vars : PhysVars;
                                       var human_anim__fromCrawlTransitionAnimId : int&;
                                       var human_anim__fromCrawlTransitionVarId : int&)
  if animchar.animGraph != null
    human_anim__fromCrawlTransitionAnimId = *animchar.animGraph |> anim_graph_getStateIdx(human_anim__fromCrawlTransitionAnim)
    human_anim__fromCrawlTransitionVarId = phys_vars |> registerVar(human_anim__fromCrawlTransitionVar, 0.)

[es(on_appear, before=anim_phys_init_es)]
def init_fast_crawl_ids(evt : Event;
                        animchar : AnimcharBaseComponent;
                        human_fast_prone_anim__state : string;
                        human_fast_prone_anim__progressVar : string;
                        var phys_vars : PhysVars;
                        var human_fast_prone_anim__stateId : int&;
                        var human_fast_prone_anim__progressVarId : int&)
  if animchar.animGraph != null
    human_fast_prone_anim__stateId = *animchar.animGraph |> anim_graph_getStateIdx(human_fast_prone_anim__state)
    human_fast_prone_anim__progressVarId = phys_vars |> registerVar(human_fast_prone_anim__progressVar, 0.)

[es(on_appear, before=anim_phys_init_es)]
def init_sprint_leap_ids(evt : Event;
                         animchar : AnimcharBaseComponent;
                         var phys_vars : PhysVars;
                         var human_sprint_leap_anim__progressVarId : int&;
                         var human_sprint_leap_anim__startStateId : int&;
                         var human_sprint_leap_anim__endStateId : int&;
                         var human_sprint_leap_anim__fallStateId : int&)
  human_sprint_leap_anim__progressVarId = phys_vars |> registerVar("sprint_leap_progress", 0.)
  human_sprint_leap_anim__startStateId = *animchar.animGraph |> anim_graph_getStateIdx("sprint_leap_start")
  human_sprint_leap_anim__endStateId = *animchar.animGraph |> anim_graph_getStateIdx("sprint_leap_end")
  human_sprint_leap_anim__fallStateId = *animchar.animGraph |> anim_graph_getStateIdx("sprint_leap_fall")

[es(on_appear)]
def human_init_stationary_gun_animation(evt : Event;
                                        animchar : AnimcharBaseComponent;
                                        var human_anim__stationaryGunAnimId : int&)
  let animGraph = animchar.animGraph
  if animGraph != null
    human_anim__stationaryGunAnimId = anim_graph_getStateIdx(*animGraph, "stationary_machine_gun_hold")

[es(tag=server, on_appear)]
def human_init_sprint_anim_variation_in_squad(evt : Event;
                                              human_anim__sprintVariationCount : int;
                                              squad_member__squad : EntityId = INVALID_ENTITY_ID;
                                              var human_anim__sprintVariation : int&)
  if human_anim__sprintVariationCount <= 0
    return
  let squadFound = query(squad_member__squad) <| $ [es] (var squad__sprintAnims : IntList&)
    if length(squad__sprintAnims) == 0
      for i in range(human_anim__sprintVariationCount)
        squad__sprintAnims |> push(i)
    let index = rnd_int(0, length(squad__sprintAnims) - 1)
    human_anim__sprintVariation = squad__sprintAnims[index]
    squad__sprintAnims |> erase(index)
  if !squadFound
    human_anim__sprintVariation = rnd_int(0, human_anim__sprintVariationCount - 1)

[es(on_appear, before=anim_phys_init_es)]
def human_init_sprint_animation_variation(evt : Event;
                                          human_anim__sprintVariation : int;
                                          var human_anim__sprintVariationVarId : int&;
                                          var phys_vars : PhysVars&)
  human_anim__sprintVariationVarId = phys_vars |> registerVar("anim_variation", float(human_anim__sprintVariation))

[es(track=human_anim__sprintVariation, after=human_init_sprint_animation_variation)]
def human_track_sprint_animation_variation(evt : Event;
                                           human_anim__sprintVariation : int;
                                           human_anim__sprintVariationVarId : int;
                                           var phys_vars : PhysVars&)
  phys_vars |> setVar(human_anim__sprintVariationVarId, float(human_anim__sprintVariation))

[es(on_appear)]
def init_human_idle_upper_anim_state(evt : Event;
                                     eid : EntityId;
                                     animchar : AnimcharBaseComponent;
                                     human_anim__idleUpperState : string;
                                     var human_anim__idleUpperStateId : int&)
  if empty(human_anim__idleUpperState)
    return
  human_anim__idleUpperStateId = anim_graph_getStateIdx(*animchar.animGraph, human_anim__idleUpperState)
  if human_anim__idleUpperStateId < 0
    logerr("anim state {human_anim__idleUpperState} not found for {getEntityTemplateName(eid)}")

[es(tag=server, on_appear, track=agent_dangers__hasTraceableDangers)]
def human_anim_idling_state(evt : Event; agent_dangers__hasTraceableDangers : bool; var human_anim__isIdling : bool&)
  human_anim__isIdling = !agent_dangers__hasTraceableDangers

[es(REQUIRE_NOT=(animchar__actOnDemand, menuSoldier), after=human_weap_update_es, parallel_for=1)]
def human_anim_es(info : ParallelUpdateFrameDelayed;
                  ragdoll : PhysRagdoll const?;
                  human_anim__climbHeights : Array;
                  dm_parts__hitPartsAnimationId : Array const?;
                  human_net_phys__climbToPos : float3 = float3();
                  transform : float3x4;
                  human_net_phys : HumanActor;
                  human_phys__jumpEndTime : float;
                  eid : EntityId;
                  isAlive : bool = true; 
                  stunTimer : float = -1.; 
                  human_anim__gunPitchVarId : int;
                  human_anim__leanVarId : int;
                  human_anim__standHeightVarId : int;
                  human_anim__hitPartsSelectedVarId : int;
                  human_anim__persCourseVarId : int;
                  human_anim__changeDirVarId : int;
                  human_anim__reloadVarId : int;
                  human_anim__changeWeaponVarId : int;
                  human_anim__healItemSelectedVarId : int;
                  human_anim__climbProgressVarId : int;
                  human_anim__vehicleSelectedVarId : int;
                  human_anim__seatTypeVarId : int;
                  human_anim__vertSpeedVarId : int;
                  human_anim__bipodVarId : int;
                  hitpoints__lastHitNodeId : int = -1;
                  human_inventory__entityToUse : EntityId = INVALID_ENTITY_ID;
                  human_inventory__targetToUse : EntityId = INVALID_ENTITY_ID;
                  human_inventory__entityUseEnd : float = -1.0;
                  human_anim__vehicleSelected : EntityId = INVALID_ENTITY_ID;
                  human_net_phys__isClimbing : bool = false;
                  human_weap__reloadAtTime : float = -1.0;
                  human_weap__reloadStartTime : float = -1.0;
                  human_weap__isReloading : bool = false;
                  human_weap__inspectStartTime : float = -1.0;
                  human_weap__inspectEndTime : float = -1.0;
                  human_weap__weapModActivateStartTime : float = -1.0;
                  human_weap__weapModActivateFinishTime : float = -1.0;
                  human_vehicle__isHoldingGunPassenger : bool = false;
                  isGunner : bool = false;
                  isInVehicle : bool = false;
                  human_weap__throwMode : bool = false;
                  human_weap__radioMode : bool = false;
                  human_weap__mortarMode : bool = false;
                  human_attached_gun__attachedGunEid : EntityId = INVALID_ENTITY_ID;
                  human_anim__stationaryGunAnimId : int = -1;
                  animchar__scale : float = 1.0;
                  human_anim__airSpeedMult : float = 0.05;
                  human_anim__jumpTransitionTime : float = 2.0;
                  human_anim__jumpVertSpeedTransitionOffset : float = -10.0;
                  human_anim__vertVelVisc : float = 0.2;
                  human_anim__considerFwdStopped : float = 0.1;
                  human_anim__considerFallingCoef : float = 2.0;
                  human_anim__jumpUpperStateId : int = -1;
                  burning__isPuttingOut : bool = false;
                  burning__animPutOutEnum : int = -1;
                  bipod__enabled : bool = false;
                  human_vehicle_anim__upperId : int = -1;
                  human_vehicle_anim__lowerId : int = -1;
                  human_vehicle_anim__fireReadyUpperId : int = -1;
                  human_vehicle_anim__fireReadyLowerId : int = -1;
                  human_vehicle_anim__healUpperId : int = -1;
                  human_vehicle_anim__healLowerId : int = -1;
                  human_vehicle_anim__maxStandHeight : float = 1.;
                  human_anim__crawlThreshold : float = -0.1;
                  human_anim__toCrawlTransitionAnimId : int;
                  human_anim__toCrawlTransitionVarId : int;
                  human_anim__fromCrawlTransitionAnimId : int;
                  human_anim__fromCrawlTransitionVarId : int;
                  human_anim__idleUpperStateId : int = -1;
                  human_anim__localWalkDirVarId : int;
                  human_anim__rootRotateVarId : int;
                  human_anim__horizontalSpeedVarId : int;
                  human_anim__horizontalVelocityViscosity : float = 0.2;
                  human_death_anim__selectedDeathAnimStateId : int;
                  human_melee_charge__isActive : bool = false;
                  human_melee_charge__animUpperStateId : int = -1;
                  human_melee_charge__animProgressVarId : int = -1;
                  human_melee_charge__animProgress : float = 0.0;
                  human_fast_prone__inProgress : bool;
                  human_sprint_leap__isLeaping : bool;
                  animchar__updatable : bool;
                  animchar__visible : bool = false;
                  animchar__accumDt = -1.f;
                  animchar__dtThreshold = 0.f;
                  human_anim__jumpStartStateRange : float2;
                  human_anim__jumpEndStateRange : float2;
                  human_phys__jumpStartTime : float;
                  human_phys__beforeJumpDelay : float;
                  human_phys__beforeJumpCrouchHeight : float;
                  human_phys__afterJumpCrouchHeight : float;
                  human_anim__heightViscosity : float = 0.1;
                  human_anim__bipodHeightViscosity : float = 0.01;
                  var human_anim__standInPlaceTimer : float&;
                  human_anim__standInPlaceWaitTime : float = 0.5;
                  human_anim__rootRotateViscosity : float = 0.05;
                  human_anim__rootRotateBackViscosity : float = 0.9;
                  human_anim__rootRotateToSideViscosity : float = 0.9;
                  human_anim__localWalkDirClampAngle : float = 170.0;
                  human_anim__localWalkDirDeltaThresholdAngle : float = 180.0;
                  human_anim__isIdling : bool = false;
                  beh_tree__enabled : bool = false;
                  var human_anim__previousHeight : float&;
                  var human_anim : HumanAnimCtx;
                  var phys_vars : PhysVars;
                  var animchar__animSpeed : float&;
                  var human_anim__jumpTimer : float&;
                  controlledHero : Tag const?) 
  if !animchar__updatable || (!animchar__visible && ((animchar__accumDt + info.dt) < animchar__dtThreshold))
    return

  var pitch : float
  calc_shoot_pitch(human_net_phys, eid, info.curTime, transform, pitch, controlledHero != null)

  let dt = info.dt
  let curTime = get_sync_time()

  var animHitPartId = 0
  if dm_parts__hitPartsAnimationId != null && hitpoints__lastHitNodeId > -1
    animHitPartId = (hitpoints__lastHitNodeId < length(*dm_parts__hitPartsAnimationId) ?
      get_int((*dm_parts__hitPartsAnimationId)[hitpoints__lastHitNodeId]) ?? 0 : 0)

  let unitTm = transform
  assume phys = human_net_phys.phys

  let interpK = get_phys_interpk_clamped(phys, curTime)

  let rootDir = get_some_normal(phys.currentState.vertDirection)
  let sideDir = normalize(cross(rootDir, phys.currentState.vertDirection))

  let prevRootDir = get_some_normal(phys.previousState.vertDirection)
  let prevSideDir = normalize(cross(prevRootDir, phys.previousState.vertDirection))


  
  var bodyDir3d = relative_2d_dir_to_absolute_3d_dir(phys.currentState.bodyOrientDir, rootDir, sideDir)
  let prevBodyDir3d = relative_2d_dir_to_absolute_3d_dir(phys.previousState.bodyOrientDir, prevRootDir, prevSideDir)
  bodyDir3d = lerp(prevBodyDir3d, bodyDir3d, float3(interpK))

  var walkDir3d = relative_2d_dir_to_absolute_3d_dir(phys.currentState.walkDir, rootDir, sideDir)
  let prevWalkDir3d = relative_2d_dir_to_absolute_3d_dir(phys.previousState.walkDir, prevRootDir, prevSideDir)
  walkDir3d = lerp(prevWalkDir3d, walkDir3d, float3(interpK))

  let velDelta = lerp(phys.previousState.velocity - phys.previousState.standingVelocity,
                      phys.currentState.velocity - phys.currentState.standingVelocity, float3(interpK))
  var spd = length(velDelta.xz)
  var isClimbing = human_net_phys__isClimbing
  var animHeight = lerp(phys.previousState.height, phys.currentState.height, interpK)

  if human_phys__beforeJumpDelay > 0.f && phys.currentState.jumpStartTime >= 0. && curTime > phys.currentState.jumpStartTime
    animHeight = curTime < phys.currentState.jumpStartTime + human_phys__beforeJumpDelay ? human_phys__beforeJumpCrouchHeight : 1.
  if curTime < phys.currentState.afterJumpDampingEndTime
    animHeight = min(animHeight, human_phys__afterJumpCrouchHeight)

  animHeight = approach(human_anim__previousHeight, animHeight, dt, bipod__enabled ? human_anim__bipodHeightViscosity : human_anim__heightViscosity)

  phys_vars |> setVar(human_anim__gunPitchVarId, rad_to_deg(pitch))

  phys_vars |> setVar(human_anim__bipodVarId, bipod__enabled ? 1. : 0.)
  phys_vars |> setVar(human_anim__leanVarId, lerp(phys.previousState.leanPosition, phys.currentState.leanPosition, interpK))
  phys_vars |> setVar(human_anim__standHeightVarId, clamp(animHeight, 0., 1.))
  phys_vars |> setVar(human_anim__hitPartsSelectedVarId, float(animHitPartId))

  let up = unitTm[1]
  var dir = unitTm[0]
  dir = normalize(dir - up * dot(dir, up))
  
  let bodyAngles = basis_aware_dir_to_angles(bodyDir3d, up, dir)
  let walkAngles = basis_aware_dir_to_angles(walkDir3d, up, dir)
  phys_vars |> setVar(human_anim__persCourseVarId, .0)

  let isSwimming = human_phys_state_get_is_swimming(human_net_phys.phys.currentState)
  if (int(human_net_phys.phys.currentState.isInAirHistory) & 1) != 0 && !isSwimming && !isClimbing
    human_anim__jumpTimer += info.dt
    spd *= cvt(human_anim__jumpTimer, 0.0, human_anim__jumpTransitionTime * 0.5, 1.0, human_anim__airSpeedMult)
  else
    human_anim__jumpTimer = 0.0

  let standState = phys.currentState.standState

  let statePos = (bipod__enabled &&
                 standState != HUStandState.ESS_CRAWL ? HumanStatePos.E_BIPOD :
                 standState == HUStandState.ESS_STAND ? HumanStatePos.E_STAND :
                 standState == HUStandState.ESS_DOWNED ? HumanStatePos.E_DOWNED :
                 standState == HUStandState.ESS_CROUCH ? HumanStatePos.E_CROUCH :
                 standState == HUStandState.ESS_CRAWL ? HumanStatePos.E_CRAWL :
                 standState == HUStandState.ESS_SWIM ? HumanStatePos.E_SWIM :
                 standState == HUStandState.ESS_SWIM_UNDERWATER ? HumanStatePos.E_SWIM_UNDERWATER :  HumanStatePos.E_STAND)

  var stateMove = (phys.currentState.moveState == HUMoveState.EMS_SPRINT ? HumanStateMove.E_SPRINT :
                   phys.currentState.moveState == HUMoveState.EMS_WALK ? HumanStateMove.E_MOVE :
                   phys.currentState.moveState == HUMoveState.EMS_RUN ? HumanStateMove.E_RUN :
                   phys.currentState.moveState == HUMoveState.EMS_ROTATE_LEFT ? HumanStateMove.E_ROTATE_LEFT :
                   phys.currentState.moveState == HUMoveState.EMS_ROTATE_RIGHT ? HumanStateMove.E_ROTATE_RIGHT :
                   HumanStateMove.E_STILL)

  let isStandingState = (stateMove == HumanStateMove.E_ROTATE_LEFT ||
                         stateMove == HumanStateMove.E_ROTATE_RIGHT ||
                         stateMove == HumanStateMove.E_STILL)
  human_anim__standInPlaceTimer = isStandingState ? (human_anim__standInPlaceTimer + info.dt) : 0.0
  let standingInPlace = human_anim__standInPlaceTimer >= human_anim__standInPlaceWaitTime

  let localWalkDirFrom = standingInPlace ? -rad_to_deg(bodyAngles.x) : -rad_to_deg(walkAngles.x) + rad_to_deg(bodyAngles.x)
  let prevLocalWalkDir = phys_vars |> getVar(human_anim__localWalkDirVarId)
  var localWalkDir = clamp(norm_s_ang_deg(localWalkDirFrom), -human_anim__localWalkDirClampAngle, human_anim__localWalkDirClampAngle)
  if abs(prevLocalWalkDir - localWalkDir) > human_anim__localWalkDirDeltaThresholdAngle
    localWalkDir = sign(prevLocalWalkDir) * human_anim__localWalkDirClampAngle
  phys_vars |> setVar(human_anim__localWalkDirVarId, localWalkDir)

  let prevRootRotate = phys_vars |> getVar(human_anim__rootRotateVarId)
  if statePos == HumanStatePos.E_CRAWL
    let rootRotate = standingInPlace ? localWalkDirFrom : approach(prevRootRotate, 0.0, dt, human_anim__rootRotateViscosity)
    phys_vars |> setVar(human_anim__rootRotateVarId, rootRotate)
  else
    let rootRotateVisc = standingInPlace ? human_anim__rootRotateToSideViscosity : human_anim__rootRotateBackViscosity
    let rootRotate = approach(prevRootRotate, standingInPlace ? localWalkDirFrom : 0.0, dt, rootRotateVisc)
    phys_vars |> setVar(human_anim__rootRotateVarId, rootRotate)

  var stateUpperBody = HumanStateUpperBody.E_READY
  let effectiveCurSlot = phys.currentState.weapEquipState.effectiveCurSlot
  let isChangingWeapon = (phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ||
                          phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING ||
                          phys.previousState.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING ||
                          phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED)
  if human_weap__throwMode
    stateUpperBody = (effectiveCurSlot == HUWeaponSlots.EWS_GRENADE ? HumanStateUpperBody.E_THROW
                                                                    : HumanStateUpperBody.E_FAST_THROW)
  elif phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED
    let reload = (curTime >= human_weap__reloadStartTime &&
                  curTime <= human_weap__reloadAtTime) || human_weap__isReloading
    let inspect = (curTime >= human_weap__inspectStartTime &&
                   curTime <= human_weap__inspectEndTime)
    let weapModActivate = (curTime >= human_weap__weapModActivateStartTime &&
                           curTime <= human_weap__weapModActivateFinishTime)
    stateUpperBody = ((reload || inspect || weapModActivate) ? HumanStateUpperBody.E_RELOAD :
                      human_phys_isAiming(phys) ? HumanStateUpperBody.E_AIM : HumanStateUpperBody.E_READY)
  elif isChangingWeapon
    stateUpperBody = HumanStateUpperBody.E_CHANGE

    assume prevState = phys.previousState.weapEquipState
    assume curState = phys.currentState.weapEquipState
    let progress = lerp(prevState.progress, curState.progress, interpK)
    phys_vars |> setVar(human_anim__changeWeaponVarId, progress)
    phys_vars |> setVar(human_anim__changeDirVarId, prevState.curState == HUWeaponEquipState.EES_EQUIPING ? 1.0 : -1.0)

  elif phys.currentState.weapEquipState.curState == HUWeaponEquipState.EES_DOWN
    let reload = phys_vars |> getVar(human_anim__reloadVarId)
    stateUpperBody = reload > 0.0 ? HumanStateUpperBody.E_READY : HumanStateUpperBody.E_DOWN

  if human_inventory__entityToUse != INVALID_ENTITY_ID && info.curTime < human_inventory__entityUseEnd
    query(human_inventory__entityToUse) <| $ [es] (item__healAnimEnumValue : int;
                                                   item__healTargetAnimEnumValue : int)
      stateUpperBody = HumanStateUpperBody.E_HEAL
      let isTarget = human_inventory__targetToUse != INVALID_ENTITY_ID && human_inventory__targetToUse != eid
      let healEnum = (isTarget && item__healTargetAnimEnumValue > -1
                      ? item__healTargetAnimEnumValue : item__healAnimEnumValue)
      phys_vars |> setVar(human_anim__healItemSelectedVarId, float(healEnum))

  if burning__isPuttingOut
    stateUpperBody = HumanStateUpperBody.E_PUT_OUT_FIRE
    phys_vars |> setVar(human_anim__healItemSelectedVarId, float(burning__animPutOutEnum))

  if human_weap__radioMode
    stateUpperBody = HumanStateUpperBody.E_USE_RADIO

  if human_weap__mortarMode
    stateUpperBody = HumanStateUpperBody.E_USE_MORTAR

  if isClimbing
    let posHt = human_net_phys__climbToPos.y - unitTm[3].y
    var startPt = float2(0.0, 1.0)
    var endPt = float2(0.0, 1.0)
    for attr in human_anim__climbHeights
      let ht = get_Point2(attr) ?? float2()
      if posHt > ht.x
        startPt = ht
        endPt = ht
      else
        endPt = ht
        break
    let climbProgress = cvt(posHt, startPt.x, endPt.x, startPt.y, endPt.y)
    if climbProgress == 1.0
      isClimbing = false
      stateMove = HumanStateMove.E_MOVE
    phys_vars |> setVar(human_anim__climbProgressVarId, climbProgress)

  query(human_anim__vehicleSelected) <| $ [es] (vehicle_seats__seatEids : EidList;
                                                vehicle_seats__enumVarId : int = -1)
    if vehicle_seats__enumVarId >= 0
      phys_vars |> setVar(human_anim__vehicleSelectedVarId, float(vehicle_seats__enumVarId))
    for seatEid in vehicle_seats__seatEids
      query(seatEid) <| $ [es] (seat__ownerEid : EntityId;
                                seat__enumVarId : int)
        if eid == seat__ownerEid && seat__enumVarId >= 0
          phys_vars |> setVar(human_anim__seatTypeVarId, float(seat__enumVarId))

  var state_flags = uint(HumanAnimStateFlags.None)
  if ragdoll == null && !isAlive
    state_flags |= uint(HumanAnimStateFlags.Dead)
  if stunTimer >= 0.0
    state_flags |= uint(HumanAnimStateFlags.Attacked)
  if isGunner
    state_flags |= uint(HumanAnimStateFlags.Gunner)
  if isClimbing
    state_flags |= uint(HumanAnimStateFlags.Climbing)

  
  let moveVThres = 0.01
  var moveV = float3(phys.currentState.location.P - phys.previousState.location.P)
  let moveVlen = length(moveV)
  moveV = moveVlen > moveVThres ? moveV * safeinv(moveVlen) : float3()
  let fwdV = phys.currentState.location.fwd
  let fwdStopped = dot(moveV, fwdV) < human_anim__considerFwdStopped
  let isOnGround = (uint(phys.currentState.states) & uint(StateFlag.ST_ON_GROUND)) != 0u
  let isClimbingCurrentState = human_phys_state_get_isClimbing(phys.currentState)
  let inJumping = (!isOnGround && !isClimbingCurrentState &&
                  (statePos != HumanStatePos.E_SWIM && statePos != HumanStatePos.E_SWIM_UNDERWATER))
  let inLongJump = human_anim__jumpTimer > human_anim__jumpTransitionTime
  let walkSpeed = phys |> human_phys_getWalkSpeed(HUStandState.ESS_STAND, HUMoveState.EMS_WALK)
  let isFalling = phys.currentState.velocity.y < -walkSpeed * human_anim__considerFallingCoef
  let jumpFromStand = inJumping && fwdStopped && !isFalling
  let vertSpeed = phys.currentState.velocity.y + (jumpFromStand ? 0.0 :
                                                  cvt(human_anim__jumpTimer,
                                                      human_anim__jumpTransitionTime,
                                                      human_anim__jumpTransitionTime * 2.0,
                                                      human_anim__jumpVertSpeedTransitionOffset,
                                                      0.0))
  let prevVertSpeedVar = phys_vars |> getVar(human_anim__vertSpeedVarId)
  let newVertSpeedVar = approach(prevVertSpeedVar, vertSpeed, dt, human_anim__vertVelVisc)
  phys_vars |> setVar(human_anim__vertSpeedVarId, newVertSpeedVar)
  let stateJump = (jumpFromStand || inLongJump) ? StateJump.E_FROM_STAND : inJumping ? StateJump.E_NOT_JUMP : StateJump.E_NOT_JUMP

  let prevHorzSpeedVar = phys_vars |> getVar(human_anim__horizontalSpeedVarId)
  let newHorzSpeedVar = approach(prevHorzSpeedVar, length(float3(phys.currentState.velocity.x, 0.0, phys.currentState.velocity.z)), dt, human_anim__horizontalVelocityViscosity)
  phys_vars |> setVar(human_anim__horizontalSpeedVarId, newHorzSpeedVar)

  var state = HumanAnimStateResult(-1, -1)
  if isInVehicle
    let isHealing = stateUpperBody == HumanStateUpperBody.E_HEAL
    let throwModeUpperState = effectiveCurSlot == HUWeaponSlots.EWS_GRENADE ? human_anim.animState.upperState.throwGrenade : human_anim.animState.upperState.fastThrow
    let upperVehicleState = ((isHealing && human_vehicle_anim__healUpperId >= 0) ? human_vehicle_anim__healUpperId
      : human_vehicle__isHoldingGunPassenger && human_weap__throwMode ? throwModeUpperState
      : human_vehicle__isHoldingGunPassenger && isChangingWeapon ? human_anim.animState.upperState.changeWeapon
      : human_vehicle__isHoldingGunPassenger ? human_vehicle_anim__fireReadyUpperId
      : human_vehicle_anim__upperId)
    let lowerVehicleState = ((isHealing && human_vehicle_anim__healLowerId >= 0) ? human_vehicle_anim__healLowerId
      : human_vehicle__isHoldingGunPassenger ? human_vehicle_anim__fireReadyLowerId
      : human_vehicle_anim__lowerId)
    state = HumanAnimStateResult(upperVehicleState, lowerVehicleState)
    if phys.currentState.height > human_vehicle_anim__maxStandHeight
      phys_vars |> setVar(human_anim__standHeightVarId, human_vehicle_anim__maxStandHeight)
  elif !isAlive && human_death_anim__selectedDeathAnimStateId >= 0
    state = HumanAnimStateResult(human_death_anim__selectedDeathAnimStateId, human_death_anim__selectedDeathAnimStateId)
  else
    state = human_anim.animState |> updateState(statePos, stateMove, stateJump, stateUpperBody, state_flags)
    if (human_anim__idleUpperStateId >= 0 && beh_tree__enabled && human_anim__isIdling
        && stateUpperBody == HumanStateUpperBody.E_READY
        && stateMove == HumanStateMove.E_STILL
        && (statePos == HumanStatePos.E_STAND || statePos == HumanStatePos.E_CROUCH))
      state.upper = human_anim__idleUpperStateId

    if human_anim__jumpUpperStateId > 0 && ((curTime > human_phys__jumpStartTime + human_anim__jumpStartStateRange.x && curTime < human_phys__jumpStartTime + human_anim__jumpStartStateRange.y) ||
                                            (curTime > human_phys__jumpEndTime + human_anim__jumpEndStateRange.x && curTime < human_phys__jumpEndTime + human_anim__jumpEndStateRange.y))
      state.upper = human_anim__jumpUpperStateId

    let isToCrawlTransition = animHeight < human_anim__previousHeight && phys.currentState.height < human_anim__crawlThreshold && phys.currentState.height > -1.
    let isFromCrawlTransition = animHeight > human_anim__previousHeight && phys.currentState.height < human_anim__crawlThreshold
    if human_anim__toCrawlTransitionAnimId >= 0 && isToCrawlTransition
      state.upper = human_anim__toCrawlTransitionAnimId
      state.lower = human_anim__toCrawlTransitionAnimId
      if human_anim__toCrawlTransitionVarId >= 0
        setVar(phys_vars, human_anim__toCrawlTransitionVarId, cvt(animHeight, 0., -1., 0., 1.))
    if human_anim__fromCrawlTransitionAnimId >= 0 && isFromCrawlTransition
      state.upper = human_anim__fromCrawlTransitionAnimId
      state.lower = human_anim__fromCrawlTransitionAnimId
      if human_anim__fromCrawlTransitionVarId >= 0
        setVar(phys_vars, human_anim__fromCrawlTransitionVarId, cvt(animHeight, 0., -1., 1., 0.))
    if human_melee_charge__isActive && human_melee_charge__animUpperStateId >= 0
      state.upper = human_melee_charge__animUpperStateId
      if human_melee_charge__animProgressVarId >= 0
        setVar(phys_vars, human_melee_charge__animProgressVarId, human_melee_charge__animProgress)

    if human_fast_prone__inProgress
      query(eid) <| $ [es] (human_fast_prone__startTime : float;
                            human_fast_prone_anim__duration : float;
                            human_fast_prone_anim__stateId : int;
                            human_fast_prone_anim__progressVarId : int)
        if curTime > human_fast_prone__startTime && curTime < (human_fast_prone__startTime + human_fast_prone_anim__duration)
          state.upper = human_fast_prone_anim__stateId
          state.lower = human_fast_prone_anim__stateId
          let progress = safediv(curTime - human_fast_prone__startTime, human_fast_prone_anim__duration)
          setVar(phys_vars, human_fast_prone_anim__progressVarId, progress)

    if human_sprint_leap__isLeaping
      query(eid) <| $ [es] (human_sprint_leap__isFalling : bool;
                            human_sprint_leap_anim__progressVarId : int;
                            human_sprint_leap_anim__startStateId : int;
                            human_sprint_leap_anim__endStateId : int;
                            human_sprint_leap_anim__fallStateId : int;
                            human_sprint_leap_anim__startStateStartedAtTime : float;
                            human_sprint_leap_anim__startStateDuration : float;
                            human_sprint_leap_anim__endStateStartedAtTime : float;
                            human_sprint_leap_anim__endStateDuration : float)
        if curTime > human_sprint_leap_anim__endStateStartedAtTime && curTime < (human_sprint_leap_anim__endStateStartedAtTime + human_sprint_leap_anim__endStateDuration)
          state.upper = human_sprint_leap_anim__endStateId
          state.lower = human_sprint_leap_anim__endStateId

          let progress = safediv(curTime - human_sprint_leap_anim__endStateStartedAtTime, human_sprint_leap_anim__endStateDuration)
          setVar(phys_vars, human_sprint_leap_anim__progressVarId, progress)

        elif curTime > human_sprint_leap_anim__startStateStartedAtTime && curTime < (human_sprint_leap_anim__startStateStartedAtTime + human_sprint_leap_anim__startStateDuration)
          state.upper = human_sprint_leap_anim__startStateId
          state.lower = human_sprint_leap_anim__startStateId

          let progress = safediv(curTime - human_sprint_leap_anim__startStateStartedAtTime, human_sprint_leap_anim__startStateDuration)
          setVar(phys_vars, human_sprint_leap_anim__progressVarId, progress)

        elif human_sprint_leap__isFalling
          state.upper = human_sprint_leap_anim__fallStateId
          state.lower = human_sprint_leap_anim__fallStateId

  send_change_anim_state_event(eid, "lower", ecs_hash("lower"), state.lower)
  send_change_anim_state_event(eid, "upper", ecs_hash("upper"), state.upper)

  if !!human_attached_gun__attachedGunEid && human_anim__stationaryGunAnimId >= 0
    send_change_anim_state_event(eid, "lower", ecs_hash("lower"), human_anim__stationaryGunAnimId)
    send_change_anim_state_event(eid, "upper", ecs_hash("upper"), human_anim__stationaryGunAnimId)
  animchar__animSpeed = spd * safeinv(animchar__scale)
  human_anim__previousHeight = animHeight

[es(on_appear, before=anim_phys_init_es)]
def init_human_anim_params(evt : Event;
                           animchar : AnimcharBaseComponent;
                           human_anim__localWalkDirVar : string;
                           human_anim__rootRotateVar : string;
                           var phys_vars : PhysVars;
                           var human_anim__localWalkDirVarId : int&;
                           var human_anim__rootRotateVarId : int&)
  if animchar.animGraph != null
    human_anim__localWalkDirVarId = phys_vars |> registerVar(human_anim__localWalkDirVar, 0.)
    human_anim__rootRotateVarId = phys_vars |> registerVar(human_anim__rootRotateVar, 0.)

[es(tag=(server, net), REQUIRE=human_net_phys, REQUIRE_NOT=ragdoll, track=isAlive)]
def human_anim_disable_anim_updates_for_deadmen_server_es(evt : Event;
                                                          isAlive : bool;
                                                          var animchar__updatable : bool&)
  animchar__updatable = isAlive

[es(on_appear, before=anim_phys_init_es)]
def human_anim_set_animchar_params_es(event : Event;
                                      animcharParams : Object;
                                      var phys_vars : PhysVars)
  var params : array<int>
  var values : array<float>
  for item in animcharParams
    let k = phys_vars |> registerVar(item.key, 0.0)
    params |> push(k)
    let v = get_float(item.value) ?? 0.0
    values |> push(v)
  for i in iter_range(animcharParams)
    phys_vars |> setVar(params[i], values[i])

[soa_template]
struct HumanDeathAnim
  human_death_anim__animStateIds : int
  human_death_anim__collNodeIds : int
  human_death_anim__allowRagdoll : bool
  human_death_anim__ragdollPowerTime : float

[soa_es, es(on_appear, tag=gameClient)]
def human_death_anim_init(evt : Event;
                          animchar : AnimcharBaseComponent;
                          collres : CollisionResource;
                          @shared_comp human_death_anim__anims : Array;
                          human_death_anim__defaultDeathState : string;
                          human_death_anim__ragdollPowerDefaultTime : float;
                          var humanDeathAnim : HumanDeathAnim_SOA&;
                          var human_death_anim__defaultDeathStateId : int&)
  let defaultStateId = *animchar.animGraph |> anim_graph_getStateIdx(human_death_anim__defaultDeathState)
  if defaultStateId < 0 && !empty(human_death_anim__defaultDeathState) 
    logerr("Death animation default state '{human_death_anim__defaultDeathState}' not found")
    return
  human_death_anim__defaultDeathStateId = defaultStateId

  let deathAnimsCount = length(human_death_anim__anims)
  humanDeathAnim |> clear()
  humanDeathAnim |> reserve(deathAnimsCount)
  for anim in human_death_anim__anims
    var animObject = anim |> get_ecs_object()
    if animObject == null
      continue

    let stateName = animObject?["state"] ?as string
    let collNodeName = animObject?["coll_node"] ?as string
    let allowRagdoll = animObject?["allow_ragdoll"] ?? true
    let ragdollPowerTime = animObject?["ragdoll_power_time"] ?? human_death_anim__ragdollPowerDefaultTime
    if stateName == null || collNodeName == null
      logerr("Death animation object is missing 'state' or 'coll_node' field")
      continue

    let stateId = *animchar.animGraph |> anim_graph_getStateIdx("{*stateName}")
    if stateId < 0
      logerr("Death animation anim state '{*stateName}' not found")
      continue
    let collNodeId = collres_get_node_index_by_name(collres, "{*collNodeName}")
    if collNodeId < 0
      logerr("Death animation coll node '{*collNodeName}' not found")
      continue

    humanDeathAnim |> push() <| HumanDeathAnim(
      human_death_anim__animStateIds = stateId,
      human_death_anim__collNodeIds = collNodeId,
      human_death_anim__allowRagdoll = allowRagdoll,
      human_death_anim__ragdollPowerTime = ragdollPowerTime)

[soa_es, es(on_event, tag=gameClient)]
def human_death_anim_select_on_death(evt : EventEntityDied;
                                     human_death_anim__defaultDeathStateId : int;
                                     human_death_anim__ragdollPowerDefaultTime : float;
                                     humanDeathAnim : HumanDeathAnim_SOA;
                                     var animchar : AnimcharBaseComponent&;
                                     var human_death_anim__selectedDeathAnimStateId : int&;
                                     var human_death_anim__ragdollPowerStartedAtTime : float&;
                                     var human_death_anim__ragdollPowerEndAtTime : float&;
                                     var ragdoll__isAllowed : bool&;
                                     var ragdoll : PhysRagdoll&)
  human_death_anim__selectedDeathAnimStateId = human_death_anim__defaultDeathStateId

  var ragdollPowerTime = human_death_anim__ragdollPowerDefaultTime

  for i in humanDeathAnim
    if i.human_death_anim__collNodeIds == evt.collNodeId
      human_death_anim__selectedDeathAnimStateId = i.human_death_anim__animStateIds
      ragdoll__isAllowed = i.human_death_anim__allowRagdoll

      ragdollPowerTime = i.human_death_anim__ragdollPowerTime
      break

  if ragdollPowerTime > 0.0
    human_death_anim__ragdollPowerStartedAtTime = get_sync_time()
    human_death_anim__ragdollPowerEndAtTime = get_sync_time() + ragdollPowerTime
    ragdoll |> ragdoll_setDriveBodiesToAnimchar(true)

  
  
  *animchar.animGraph |> anim_graph_enqueueState(*animchar.animState, human_death_anim__selectedDeathAnimStateId)


[es(REQUIRE=deadEntity, no_order)]
def human_death_anim_update_ragdoll_power(info : ParallelUpdateFrameDelayed;
                                          human_anim__ragdollEnabled : bool;
                                          human_death_anim__ragdollPowerStartedAtTime : float;
                                          human_death_anim__ragdollPowerEndAtTime : float;
                                          human_death_anim__ragdollPowerKeys : FloatList;
                                          human_death_anim__ragdollPowerNotes : Point4List;
                                          var ragdoll : PhysRagdoll&)
  if !human_anim__ragdollEnabled || human_death_anim__ragdollPowerKeys |> length() == 0 || human_death_anim__ragdollPowerStartedAtTime < 0.0 || human_death_anim__ragdollPowerEndAtTime < 0.0
    return

  var physSys = ragdoll |> ragdoll_getPhysSys()
  if physSys == null
    return

  if human_death_anim__ragdollPowerKeys |> length() != human_death_anim__ragdollPowerNotes |> length()
    
    
    return

  let currentProgress = cvt(get_sync_time(), human_death_anim__ragdollPowerStartedAtTime, human_death_anim__ragdollPowerEndAtTime, 0.0, 1.0)

  var idx0 = 0
  var idx1 = 0
  for i in range(human_death_anim__ragdollPowerKeys |> length())
    if i == 0 
      continue

    idx0 = i - 1
    idx1 = i

    if currentProgress >= human_death_anim__ragdollPowerKeys[idx0] && currentProgress <= human_death_anim__ragdollPowerKeys[idx1]
      break

  let currentKeysPower = cvt(currentProgress, human_death_anim__ragdollPowerKeys[idx0], human_death_anim__ragdollPowerKeys[idx1], 0.0, 1.0)
  let currentPower = lerp(human_death_anim__ragdollPowerNotes[idx0], human_death_anim__ragdollPowerNotes[idx1], currentKeysPower)

  *physSys |> phys_system_instance_setJointsMotorSettings(currentPower.x, currentPower.y, currentPower.z, currentPower.w)
