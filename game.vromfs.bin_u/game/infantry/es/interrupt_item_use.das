require ecs
require app
require HumanPhys
require DngHuman
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.team_common
require math.base
require %appGame.infantry.es.inventory_common

def can_use_while_moving(eid : EntityId)
  return get_bool(eid, "item__canUseWhileMoving") ?? true

def human_inventory_interrupt_item_use_base(cur_time : float;
                                            eid : EntityId;
                                            human_inventory__entityToUse : EntityId;
                                            human_net_phys : HumanActor;
                                            ct : HumanControlState;
                                            human_weap__reloadFinishTime : float;
                                            human_weap__isReloading : bool;
                                            human_weap__weapModActivateStartTime : float;
                                            isInVehicle : bool;
                                            human_freefall__isFreefall : bool;
                                            burning__isBurning : bool;
                                            parachuteDeployed : Tag const?)
  assume currentState = human_net_phys.phys.currentState
  assume previousState = human_net_phys.phys.previousState
  let standing = currentState.moveState == HUMoveState.EMS_STAND
  let isStartAiming = currentState.zoomPosition > previousState.zoomPosition
  let isHctZoomViewBit = is_control_bit_set(ct, HumanPhysControlType.HCT_ZOOM_VIEW)
  var interruptsReloading = false
  var canUseWhileSwimming = false
  var canUseUnderWater = false
  var shouldIgnoreAim = false
  var shouldIgnoreLmb = false
  var stopUseWhileBurning = false
  var stopUseWhileJumping = false
  var stopUseWhileAiming = false
  query(human_inventory__entityToUse) <| $ [es] (item__interruptsReloading : Tag const?;
                                                 item__canUseWhileSwimmingStill : Tag const?;
                                                 item__canUseWhileSwimming : Tag const?;
                                                 item__canUseUnderWater : Tag const?;
                                                 item__ignoreAimInterrupt : Tag const?;
                                                 item__ignoreLmbInterrupt : Tag const?;
                                                 item__stopUseWhileBurning : Tag const?;
                                                 item__stopUseWhileJumping : Tag const?;
                                                 item__stopUseWhileAiming : Tag const?)
    interruptsReloading = item__interruptsReloading != null
    canUseWhileSwimming = (standing ? item__canUseWhileSwimmingStill : item__canUseWhileSwimming) != null
    canUseUnderWater = item__canUseUnderWater != null
    shouldIgnoreAim = item__ignoreAimInterrupt != null
    shouldIgnoreLmb = item__ignoreLmbInterrupt != null
    stopUseWhileBurning = item__stopUseWhileBurning != null
    stopUseWhileJumping = item__stopUseWhileJumping != null
    stopUseWhileAiming = item__stopUseWhileAiming != null

  if ((human_weap__reloadFinishTime > cur_time && !interruptsReloading)
      || currentState |> human_phys_state_get_isClimbing()
      || (currentState |> human_phys_state_get_is_swimming() && !canUseWhileSwimming)
      || (currentState |> human_phys_state_get_is_underwater() && !canUseUnderWater)
      || (isHctZoomViewBit && !isStartAiming && !shouldIgnoreAim)
      || (ct |> is_control_bit_set(HumanPhysControlType.HCT_SHOOT) && !shouldIgnoreLmb)
      || ct |> is_control_bit_set(HumanPhysControlType.HCT_MELEE)
      || ct |> is_control_bit_set(HumanPhysControlType.HCT_THROW)
      || human_weap__weapModActivateStartTime > 0.
      || (isInVehicle && currentState.isAiming)
      || human_freefall__isFreefall
      || parachuteDeployed != null
      || human_weap__isReloading
      || (stopUseWhileBurning && burning__isBurning)
      || (stopUseWhileJumping && ((uint(currentState.states) & uint(StateFlag.ST_JUMP)) != 0u))
      || (stopUseWhileAiming && isStartAiming && isHctZoomViewBit))
    sendEventImmediate(eid, EventInterruptItemUse())

def is_interrupted_by_moving(human_net_phys : HumanActor; human_inventory__entityToUse : EntityId)
  assume currentState = human_net_phys.phys.currentState
  assume appliedCT = human_net_phys.phys.appliedCT
  if currentState.moveState == HUMoveState.EMS_SPRINT && !currentState |> human_phys_state_stoppedSprint()
    return true

  let moving = appliedCT.walkSpeed > 0.
  if moving && currentState.isCrawl
    return true

  if (moving || appliedCT |> is_control_bit_set(HumanPhysControlType.HCT_JUMP)) && !can_use_while_moving(human_inventory__entityToUse)
    return true

  return false




def human_inventory_interrupt_item_use_server(cur_time : float;
                                              eid : EntityId;
                                              human_inventory__entityToUse : EntityId;
                                              human_net_phys : HumanActor;
                                              ct : HumanControlState;
                                              human_weap__reloadFinishTime : float;
                                              human_weap__isReloading : bool;
                                              human_weap__weapModActivateStartTime : float;
                                              isInVehicle : bool;
                                              human_freefall__isFreefall : bool;
                                              burning__isBurning : bool;
                                              parachuteDeployed : Tag const?)
  if is_interrupted_by_moving(human_net_phys, human_inventory__entityToUse)
    sendEventImmediate(eid, EventInterruptItemUse())
    return
  human_inventory_interrupt_item_use_base(cur_time, eid, human_inventory__entityToUse, human_net_phys, ct,
                                          human_weap__reloadFinishTime, human_weap__isReloading, human_weap__weapModActivateStartTime, isInVehicle,
                                          human_freefall__isFreefall, burning__isBurning, parachuteDeployed)



[es(tag=gameClient,  before=before_human_inventory_use_update)]
def human_inventory_interrupt_item_use_es(info : ParallelUpdateFrameDelayed;
                                          eid : EntityId;
                                          human_inventory__entityToUse : EntityId;
                                          human_net_phys : HumanActor;
                                          human_weap__reloadFinishTime : float;
                                          human_weap__isReloading : bool;
                                          human_weap__weapModActivateStartTime : float;
                                          isInVehicle : bool;
                                          burning__isBurning : bool;
                                          human_freefall__isFreefall : bool = false;
                                          parachuteDeployed : Tag const?)
  if !!human_inventory__entityToUse
    human_inventory_interrupt_item_use_base(info.curTime, eid, human_inventory__entityToUse, human_net_phys, human_net_phys.phys.producedCT,
                                            human_weap__reloadFinishTime, human_weap__isReloading, human_weap__weapModActivateStartTime, isInVehicle,
                                            human_freefall__isFreefall, burning__isBurning, parachuteDeployed)

[es(tag=server, before=human_weap_es)]
def human_inventory_interrupt_item_use_on_post_phys_es(evt : CmdPostPhysUpdate;
                                                       eid : EntityId;
                                                       human_inventory__entityToUse : EntityId;
                                                       human_net_phys : HumanActor;
                                                       human_weap__reloadFinishTime : float;
                                                       human_weap__isReloading : bool;
                                                       human_weap__weapModActivateStartTime : float;
                                                       isInVehicle : bool;
                                                       burning__isBurning : bool;
                                                       human_freefall__isFreefall : bool = false;
                                                       parachuteDeployed : Tag const?)
  if !!human_inventory__entityToUse
    human_inventory_interrupt_item_use_server(get_sync_time(), eid, human_inventory__entityToUse, human_net_phys,
                                              human_net_phys.phys.appliedCT, human_weap__reloadFinishTime, human_weap__isReloading,
                                              human_weap__weapModActivateStartTime, isInVehicle,
                                              human_freefall__isFreefall, burning__isBurning, parachuteDeployed)



[es(on_event=(EventEntityDied, EventInterruptItemUse), track=fortification_repair__active)]
def interrupt_item_use_es(evt : Event;
                          fortification_repair__active : bool;
                          var human_inventory__entityUseEnd : float&;
                          var human_inventory__entityUseStart : float&;
                          var human_inventory__entityToUse : EntityId&;
                          var human_inventory__targetToUse : EntityId&;
                          var human_inventory__savedUseProgress : float&;
                          var human_inventory__usePausedUntilTime : float&)
  if has(human_inventory__entityToUse, "item__useInterruptDisabled") && !fortification_repair__active
    return
  query(human_inventory__entityToUse) <| $ [es] (var item__ownerOnUseEffectEid : EntityId&)
    destroyEntity(item__ownerOnUseEffectEid)
    item__ownerOnUseEffectEid = INVALID_ENTITY_ID
  if human_inventory__targetToUse != INVALID_ENTITY_ID
    query(human_inventory__targetToUse) <| $ [es] (var hitpoints__revivingCount : int&)
      if hitpoints__revivingCount > 0
        hitpoints__revivingCount--
  human_inventory__entityUseEnd = -1.0
  human_inventory__entityUseStart = -1.0
  human_inventory__entityToUse = INVALID_ENTITY_ID
  human_inventory__targetToUse = INVALID_ENTITY_ID
  human_inventory__savedUseProgress = -1.0
  human_inventory__usePausedUntilTime = -1.0


[es(tag=gameClient, REQUIRE=hero)]
def human_inventory_interrupt_use_door_es(info : ParallelUpdateFrameDelayed;
                                          eid : EntityId;
                                          human__aimTm : float3x4;
                                          var human_inventory__selectedItem : EntityId&;
                                          var human_use_object__selectedObject : EntityId&;
                                          var human_use_object__lookAtSelected : bool&)
  if !human_inventory__selectedItem || !human_use_object__selectedObject || !can_pickup_item(human_inventory__selectedItem, eid)
    return

  query(human_use_object__selectedObject) <| $ [es(REQUIRE=isDoor)] (transform : float3x4)
    let aimDir = human__aimTm[0]
    let aimPos = human__aimTm[3]
    let doorWeight = length(transform[3] - aimPos) + (human_use_object__lookAtSelected ? -0.5f : 0.5f)
    let lootTm = get_TMatrix(human_inventory__selectedItem, "transform") ?? IDENT_TM
    let lootPos = lootTm[3]
    let lootWeight = length(lootPos - aimPos) + (1.f - dot(normalize(lootPos - aimPos), aimDir))
    if lootWeight <= doorWeight
      human_use_object__selectedObject = INVALID_ENTITY_ID
      human_use_object__lookAtSelected = false
    else
      human_inventory__selectedItem = INVALID_ENTITY_ID


[es(tag=gameClient, REQUIRE=hero)]
def human_inventory_interrupt_item_pickup_es(info : ParallelUpdateFrameDelayed;
                                             human_use_object__selectedObject : EntityId;
                                             var human_inventory__selectedItem : EntityId&;
                                             team aka self_team : int = TEAM_UNASSIGNED)
  var skipLoot = has(human_use_object__selectedObject, "vehicle_seats__seats")
  if !skipLoot
    query(human_use_object__selectedObject) <| $ [es] (team : int;
                                                       isDowned : bool)
      if !isDowned
        return
      skipLoot = is_teams_friendly(team, self_team)
  if (skipLoot)
    human_inventory__selectedItem = INVALID_ENTITY_ID


[es(tag=server, before=before_human_inventory_use_update)]
def temporary_interrupt_self_reviving_es(info : ParallelUpdateFrameDelayed;
                                         human_net_phys : HumanActor;
                                         human_inventory__entityToUse : EntityId;
                                         isDowned : bool;
                                         var hitpoints__revivingCount : int&;
                                         var human_inventory__entityUseStart : float&;
                                         var human_inventory__entityUseEnd : float&;
                                         var human_inventory__savedUseProgress : float&;
                                         var human_inventory__usePausedUntilTime : float&;
                                         human_medkit__healingResumeDelay : float = 0.5)
  if !isDowned
    return

  var isInterruptAllowed = false
  query(human_inventory__entityToUse) <| $ [es(REQUIRE_NOT=item__useInterruptDisabled)] (item__reviveAmount : float)
    isInterruptAllowed = item__reviveAmount > 0.0
  if !isInterruptAllowed
    return

  let pauseHealing = human_net_phys.phys.appliedCT.isMoving
  if pauseHealing
    if human_inventory__entityUseEnd > info.curTime
      human_inventory__entityUseEnd = -1.0
      human_inventory__savedUseProgress = info.curTime - human_inventory__entityUseStart
      human_inventory__usePausedUntilTime = info.curTime + human_medkit__healingResumeDelay
      hitpoints__revivingCount--
  elif human_inventory__savedUseProgress >= 0.0 && info.curTime > human_inventory__usePausedUntilTime
    let useTime = get_item_use_time(human_inventory__entityToUse, isDowned,  true)
    human_inventory__entityUseStart = info.curTime - human_inventory__savedUseProgress
    human_inventory__entityUseEnd = human_inventory__entityUseStart + useTime
    human_inventory__savedUseProgress = -1.0
    human_inventory__usePausedUntilTime = -1.0
    hitpoints__revivingCount++


[es(tag=server, before=before_human_inventory_use_update)]
def human_interrupt_revive_es(info : ParallelUpdateFrameDelayed;
                              eid : EntityId;
                              human_inventory__targetToUse : EntityId;
                              human_inventory__entityToUse : EntityId;
                              human_reviver__maxDistance : float2;
                              human__aimTm : float3x4)
  if !human_inventory__targetToUse || human_inventory__targetToUse == eid
    return
  let isReviving = get_bool(human_inventory__entityToUse, "item__isCurrentlyUsedForReviveTarget") ?? true
  query(human_inventory__targetToUse) <| $ [es(REQUIRE=(human))] (isAlive : bool;
                                                                  isDowned : bool;
                                                                  transform : float3x4)
    let distSq = length_sq(human__aimTm[3] - transform[3])
    if !isAlive || (isReviving != isDowned) || distSq > square(human_reviver__maxDistance.y)
      sendEvent(eid, EventInterruptItemUse())


[es(tag=server, before=before_human_inventory_use_update)]
def human_interrupt_use_entity_to_target_es(info : ParallelUpdateFrameDelayed;
                                            eid : EntityId;
                                            human_inventory__targetToUse : EntityId;
                                            human_use_object__useDist : float;
                                            human__aimTm : float3x4)
  if !human_inventory__targetToUse || human_inventory__targetToUse == eid
    return

  query(human_inventory__targetToUse) <| $ [es(REQUIRE_NOT=human)] (transform : float3x4)
    let distSq = length_sq(human__aimTm[3] - transform[3])
    if distSq > square(human_use_object__useDist)
      sendEvent(eid, EventInterruptItemUse())


[es(tag=server)]
def human_inventory_interrupt_item_use_on_drop_es(evt : EventOnLootDrop;
                                                  eid : EntityId;
                                                  human_inventory__entityToUse : EntityId)
  let droppedItemEid = evt.itemEid
  if droppedItemEid == human_inventory__entityToUse
    sendEventImmediate(eid, EventInterruptItemUse())

