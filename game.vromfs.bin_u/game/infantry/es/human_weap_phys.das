require ecs
require DagorMath
require DngHuman
require %game.events

def reset_human_aim_zoom(var human_net_phys : HumanActor; var camera__magnification : float&)
  human_net_phys.phys.currentState.aimPosition = 0.f
  human_net_phys.phys.currentState.zoomPosition = 0.f
  human_net_phys.phys.previousState.aimPosition = 0.f
  human_net_phys.phys.previousState.zoomPosition = 0.f
  camera__magnification = 1.f

[es(before=after_net_phys_sync, after=before_net_phys_sync)]
def human_weap_phys_es(
                       info : ParallelUpdateFrameDelayed;
                       human_weap__reloadAtTime : float;
                       human_weap__inspectEndTime : float;
                       human_weap__isReloading : bool;
                       human_weap__weapModActivateStartTime : float;
                       human_weap__blockAiming : bool;
                       boltActionProgress : float;
                       isGunManualLoadMode : bool;
                       var human_net_phys : HumanActor;
                       human_weap__staminaCanAim : bool = true;
                       human_weap__currentGunEid : EntityId = INVALID_ENTITY_ID;
                       human__lockZoom = false;
                       human_attached_gun__isAttached = false;
                       isDowned = false;
                       action__running = false)

  assume ct = human_net_phys.phys.currentState
  let reloading = (info.curTime <= human_weap__reloadAtTime ||
                  human_weap__weapModActivateStartTime > 0.0f ||
                  human_weap__isReloading ||
                  human_weap__inspectEndTime > info.curTime)
  let standState = ct.standState
  let isCrawling = ct.moveState != HUMoveState.EMS_STAND && ct.isCrawl
  let isShootingStandState = standState == HUStandState.ESS_STAND || standState == HUStandState.ESS_CROUCH || standState == HUStandState.ESS_CRAWL
  let isBoltActionInProgress = isGunManualLoadMode ? boltActionProgress > 0.f && boltActionProgress < 1.f : false
  let isChangingWeapon = ct.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPING || ct.weapEquipState.curState == HUWeaponEquipState.EES_HOLSTERING

  let canAimReloading = has(human_weap__currentGunEid, "gun__canAimReloading")
  let canZoomReloading = has(human_weap__currentGunEid, "gun__canZoomReloading")
  let canZoomInBoltAction = has(human_weap__currentGunEid, "gun__canZoomInBoltAction")

  human_phys_state_set_can_aim(ct,
    (!reloading || human_attached_gun__isAttached || canAimReloading) &&
    (ct.weapEquipState.curState == HUWeaponEquipState.EES_EQUIPED) &&
    !isBoltActionInProgress &&
    human_weap__staminaCanAim &&
    !isDowned && !human_weap__blockAiming && !human__lockZoom && !isCrawling && isShootingStandState)

  human_phys_state_set_can_zoom(ct,
    (!reloading || human_attached_gun__isAttached || canZoomReloading) &&
    !isDowned && !human_weap__blockAiming && !human__lockZoom &&
    (!isBoltActionInProgress || canZoomInBoltAction)
    && !action__running && isShootingStandState && !isChangingWeapon)

[es(track=human_anim__vehicleSelected, REQUIRE=human_anim__vehicleSelected)]
def human_weap_zoom_reset_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)

[es(track=human__lockZoom, REQUIRE=human__lockZoom)]
def human_weap_lock_zoom_reset_es(evt : Event; var human_net_phys : HumanActor; var camera__magnification : float&)
  reset_human_aim_zoom(human_net_phys, camera__magnification)





[es(on_appear, REQUIRE=attachedToParent)]
def init_human_weapon_len_es(evt : Event;
                             eid : EntityId;
                             gun__owner : EntityId;
                             gun__length : float = 0f)
  query(gun__owner) <| $ [es] (human_weap__gunEids : EidList; var human_net_phys : HumanActor&)
    var slotId = -1
    for i in iter_range(human_weap__gunEids)
      if human_weap__gunEids[i] == eid
        slotId = i
        break

    if slotId < 0
      return

    human_net_phys.phys |> human_phys_setWeaponLen(gun__length, slotId)


[es]
def human_weap_update_backoff_gun_dynamic_offset(evt : ParallelUpdateFrameDelayed;
                                                 human_weap__currentGunEid : EntityId;
                                                 human_weap__gunMaxBackoff : float;
                                                 human_net_phys : HumanActor)
  assume currentState = human_net_phys.phys.currentState

  query(human_weap__currentGunEid) <| $ [es] (gun_dynamic_position__maxOffset : float3;
                                              var gun_dynamic_position__offset : float3&)
    let backoffProgress = cvt(currentState.gunBackoffAmount, 0.0, human_weap__gunMaxBackoff, 0.0, 1.0)
    gun_dynamic_position__offset = gun_dynamic_position__maxOffset * backoffProgress