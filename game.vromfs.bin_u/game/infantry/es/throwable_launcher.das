require app
require ecs
require ecs.common
require net
require DagorMath
require DngHuman
require GamePhys
require %game.events

require %appGame.wt_events
require %appGame.infantry.es.throwable_common
require %appGame.infantry.es.human_weap_common
require Weapon

let MAX_ALLOWED_PING_DELAY = 0.4

def throwable_launcher_server_report_fail_throw(throwable_launcher_eid : EntityId;
                                                var throwable_launcher__inProgress : bool&;
                                                var throwable_launcher_anim__throwInProgress : bool&;
                                                var throwable_launcher_throw__commonItem : EntityId&;
                                                var throwable_launcher_throw__commonItemThrowed : bool&)
  if throwable_launcher_throw__commonItem != INVALID_ENTITY_ID
    destroyEntity(throwable_launcher_throw__commonItem)

  throwable_launcher__inProgress = false
  throwable_launcher_anim__throwInProgress = false
  throwable_launcher_throw__commonItem = INVALID_ENTITY_ID
  throwable_launcher_throw__commonItemThrowed = false
  send_net_event(throwable_launcher_eid, ResponseThrowableLauncherFailThrow())

def get_throwable_item_velocity_relative_to_transform(transfrom : float3x4;
                                                      velocity : float3)
  return (transfrom[0] * velocity.x + transfrom[1] * velocity.y + transfrom[2] * velocity.z)

def throwable_item_apply_transform_and_velocity(transform : float3x4;
                                                velocity : float3;
                                                omega : float3;
                                                var proj__physObj : ProjectilePhysObject&)
  let orient = DagorMath::quat(transform)
  proj__physObj |> phys().currentState.location.O |> orient_setQuat(orient)
  let pos = transform[3]
  proj__physObj |> phys().currentState.location.P = DPoint3(pos)
  proj__physObj |> phys().currentState.velocity = velocity
  proj__physObj |> phys().currentState.omega = omega

def throwable_launcher_throw_item(owner_eid : EntityId;
                                  throwable_launcher_eid : EntityId;
                                  transform : float3x4;
                                  velocity : float3;
                                  omega : float3;
                                  throwable_launcher_throw__collisionWithOwnerDelay : float;
                                  throwable_launcher_throw__template : string;
                                  var throwable_launcher_throw__item : EntityId&;
                                  var throwable_launcher_throw__itemThrowed : bool&;
                                  is_local : bool;
                                  throw_at_time : float;
                                  current_time : float)
  if throwable_launcher_throw__item != INVALID_ENTITY_ID
    query(throwable_launcher_throw__item) <| $ [es] (var throwable_item__throwed : bool&;
                                                     var proj__physObj : ProjectilePhysObject&) 
      throwable_item_apply_transform_and_velocity(transform, velocity, omega, proj__physObj)
      throwable_item__throwed = true
  else
    throwable_launcher_throw__item = create_throwable_item(owner_eid, throwable_launcher_eid, throwable_launcher_throw__template, is_local, false, transform,
                                                           current_time, throw_at_time, throwable_launcher_throw__collisionWithOwnerDelay, velocity, omega)
  throwable_launcher_throw__itemThrowed = true

def throwable_launcher_decrease_items_count(var itemContainer : EidList&;
                                            var throwable_launcher__itemsCount : int&;
                                            throwable_launcher__inventoryItemName : string = "";
                                            throwable_launcher_use_items_in_inventory : Tag const? = null)
  if throwable_launcher__itemsCount <= 0
    return

  --throwable_launcher__itemsCount
  if throwable_launcher_use_items_in_inventory == null
    return

  var idxInContainer = -1
  for item in itemContainer
    query(item) <| $ [es(REQUIRE=throwable_inventory_item)] (throwable_inventory_item__name : string)
      if throwable_launcher__inventoryItemName == throwable_inventory_item__name
        idxInContainer = find_index(itemContainer, item)
    if idxInContainer != -1
      destroyEntity(itemContainer[idxInContainer])
      erase(itemContainer, idxInContainer)
      return

[es(tag=gameClient, on_appear)]
def throwable_launcher_appear_client(evt : Event;
                                     var throwable_launcher_throw__localItem : EntityId&)
  throwable_launcher_throw__localItem = INVALID_ENTITY_ID

[es(tag=server, on_appear)]
def throwable_launcher_appear_server(evt : Event;
                                     var throwable_launcher_throw__commonItem : EntityId&)
  throwable_launcher_throw__commonItem = INVALID_ENTITY_ID

[es(on_appear)]
def throwable_launcher_appear(evt : Event;
                              var throwable_launcher_throw__velocityDir : float3&)
  throwable_launcher_throw__velocityDir = normalize(throwable_launcher_throw__velocityDir)

[es(on_appear, REQUIRE=throwable_launcher_throw_mode_delayed)]
def throwable_launcher_throw_type_delayed_init(evt : Event;
                                               var throwable_launcher_throw__mode : int&)
  throwable_launcher_throw__mode = int(ThrowableLauncherThrowMode.TLTM_DELAYED)

[es(on_appear, REQUIRE=throwable_launcher_throw_mode_direct)]
def throwable_launcher_throw_type_direct_init(evt : Event;
                                              var throwable_launcher_throw__mode : int&)
  throwable_launcher_throw__mode = int(ThrowableLauncherThrowMode.TLTM_DIRECT)

[es(tag=gameClient, on_appear, REQUIRE=throwable_launcher_local_item_replace_mode_instant)]
def throwable_launcher_local_item_replace_mode_instant_init(evt : Event;
                                                            var throwable_launcher_throw__localItemReplaceMode : int&)
  throwable_launcher_throw__localItemReplaceMode = int(ThrowableLauncherLocalItemReplaceMode.TLLIRM_INSTANT)

[es(tag=gameClient, on_appear, REQUIRE=throwable_launcher_local_item_replace_mode_lerp)]
def throwable_launcher_local_item_replace_mode_lerp_init(evt : Event;
                                                         var throwable_launcher_throw__localItemReplaceMode : int&)
  throwable_launcher_throw__localItemReplaceMode = int(ThrowableLauncherLocalItemReplaceMode.TLLIRM_LERP)

[es(tag=server, track=itemContainer, on_appear, after=multiple_guns_slot_fill_inventory_gun_items)]
def throwable_launcher_count_items_in_inventory(evt : Event;
                                                eid : EntityId;
                                                itemContainer : EidList)
  find_query() <| $ [es(REQUIRE=(throwable_launcher, throwable_launcher_use_items_in_inventory))] (gun__owner : EntityId;
                                                                                                   throwable_launcher__inventoryItemName : string;
                                                                                                   var throwable_launcher__itemsCount : int&)
    if gun__owner != eid
      return false

    throwable_launcher__itemsCount = 0
    for item in itemContainer
      query(item) <| $ [es(REQUIRE=throwable_inventory_item)] (throwable_inventory_item__name : string)
        if throwable_launcher__inventoryItemName == throwable_inventory_item__name
          ++throwable_launcher__itemsCount
    return true

[es(tag=gameClient, REQUIRE=watchedPlayerItem)]
def throwable_launcher_on_fail_throw_response(evt : ResponseThrowableLauncherFailThrow;
                                              throwable_launcher_anim__disableRenderOnItemAppear : bool;
                                              var throwable_launcher__inProgress : bool&;
                                              var throwable_launcher_anim__throwInProgress : bool&;
                                              var throwable_launcher_throw__localItem : EntityId&;
                                              var throwable_launcher_throw__localItemThrowed : bool&;
                                              var animchar_render__enabled : bool&)
  if throwable_launcher_anim__disableRenderOnItemAppear
    animchar_render__enabled = true

  if throwable_launcher_throw__localItem != INVALID_ENTITY_ID
    destroyEntity(throwable_launcher_throw__localItem)

  throwable_launcher__inProgress = false
  throwable_launcher_anim__throwInProgress = false
  throwable_launcher_throw__localItem = INVALID_ENTITY_ID
  throwable_launcher_throw__localItemThrowed = false

[es(tag=gameClient, REQUIRE=throwable_self_launcher)]
def throwable_self_launcher_phys_es(evt : CmdWeapPhysUpdate;
                                    eid : EntityId;
                                    throwable_launcher__inProgress : bool;
                                    throwable_launcher__itemsCount : int;
                                    var throwable_launcher__throwButtonPressed : bool&)
  let isForReal = evt.isForReal
  if !isForReal || throwable_launcher__itemsCount <= 0 || throwable_launcher__inProgress
    return

  if evt.gctrl.shoot != throwable_launcher__throwButtonPressed
    throwable_launcher__throwButtonPressed = evt.gctrl.shoot
    if !throwable_launcher__throwButtonPressed
      return
    throwable_launcher_request_throw(evt.owner, eid, evt.atTime)

[es(tag=server, no_order)]
def throwable_launcher_throw_delayed(info : UpdateStageInfoAct;
                                     eid : EntityId;
                                     gun__owner : EntityId;
                                     throwable_launcher__inProgress : bool;
                                     throwable_launcher_throw__mode : int;
                                     throwable_launcher_throw__startAtTime : float;
                                     throwable_launcher_throw__throwTime : float;
                                     throwable_launcher_throw__commonTemplate : string;
                                     throwable_launcher_throw__positionOffset : float3;
                                     throwable_launcher_throw__velocityDir : float3;
                                     throwable_launcher_throw__speed : float;
                                     throwable_launcher_throw__omega : float3;
                                     throwable_launcher_throw__collisionWithOwnerDelay : float;
                                     var throwable_launcher_throw__commonItem : EntityId&;
                                     var throwable_launcher_throw__commonItemThrowed : bool&;
                                     var throwable_launcher__itemsCount : int&;
                                     throwable_launcher__inventoryItemName : string = "";
                                     throwable_launcher_use_items_in_inventory : Tag const? = null)
  if (!throwable_launcher__inProgress
      || throwable_launcher_throw__mode != int(ThrowableLauncherThrowMode.TLTM_DELAYED)
      || throwable_launcher_throw__commonItemThrowed)
    return

  let throwAtTime = throwable_launcher_throw__startAtTime + throwable_launcher_throw__throwTime
  if info.curTime < throwAtTime
    return

  query(gun__owner) <| $ [es] (human_net_phys : HumanActor;
                               var itemContainer : EidList&)
    let throwableItemTM = get_throwable_item_transform_relative_to_human(human_net_phys, throwable_launcher_throw__positionOffset)
    let throwableVelocity = get_throwable_item_velocity_relative_to_transform(throwableItemTM, throwable_launcher_throw__velocityDir * throwable_launcher_throw__speed)
    throwable_launcher_throw_item(gun__owner, eid, throwableItemTM, throwableVelocity, throwable_launcher_throw__omega, throwable_launcher_throw__collisionWithOwnerDelay,
                                  throwable_launcher_throw__commonTemplate, throwable_launcher_throw__commonItem, throwable_launcher_throw__commonItemThrowed, false, throwAtTime, info.curTime)
    throwable_launcher_decrease_items_count(itemContainer, throwable_launcher__itemsCount, throwable_launcher__inventoryItemName, throwable_launcher_use_items_in_inventory)

[es(tag=server, no_order)]
def throwable_launcher_throw_direct_reject_for_too_long_wait(info : UpdateStageInfoAct;
                                                             eid : EntityId;
                                                             throwable_launcher_throw__mode : int;
                                                             throwable_launcher_throw__startAtTime : float;
                                                             throwable_launcher_throw__throwTime : float;
                                                             var throwable_launcher__inProgress : bool&;
                                                             var throwable_launcher_anim__throwInProgress : bool&;
                                                             var throwable_launcher_throw__commonItem : EntityId&;
                                                             var throwable_launcher_throw__commonItemThrowed : bool&)
  if (!throwable_launcher__inProgress
      || throwable_launcher_throw__mode != int(ThrowableLauncherThrowMode.TLTM_DIRECT)
      || throwable_launcher_throw__commonItemThrowed)
    return

  let throwAtTime = throwable_launcher_throw__startAtTime + throwable_launcher_throw__throwTime
  if (info.curTime - throwAtTime) <= MAX_ALLOWED_PING_DELAY
    return

  throwable_launcher_server_report_fail_throw(eid, throwable_launcher__inProgress, throwable_launcher_anim__throwInProgress, throwable_launcher_throw__commonItem, throwable_launcher_throw__commonItemThrowed)

[es(tag=server)]
def throwable_launcher_throw_direct(evt : RequestThrowableLauncherDirectThrow;
                                    eid aka human_eid : EntityId;
                                    human_weap__currentGunEid : EntityId;
                                    human_net_phys : HumanActor;
                                    var itemContainer : EidList&)
  if human_weap__currentGunEid != evt.throwableLauncherEid
    return

  query(evt.throwableLauncherEid) <| $ [es] (gun__owner : EntityId;
                                             throwable_launcher_throw__mode : int;
                                             throwable_launcher_throw__startAtTime : float;
                                             throwable_launcher_throw__throwTime : float;
                                             throwable_launcher_throw__commonTemplate : string;
                                             throwable_launcher_throw__positionOffset : float3;
                                             throwable_launcher_throw__velocityDir : float3;
                                             throwable_launcher_throw__speed : float;
                                             throwable_launcher_throw__omega : float3;
                                             throwable_launcher_throw__collisionWithOwnerDelay : float;
                                             var throwable_launcher__inProgress : bool&;
                                             var throwable_launcher__itemsCount : int&;
                                             var throwable_launcher_anim__throwInProgress : bool&;
                                             var throwable_launcher_throw__commonItem : EntityId&;
                                             var throwable_launcher_throw__commonItemThrowed : bool&;
                                             throwable_launcher__inventoryItemName : string = "";
                                             throwable_launcher_use_items_in_inventory : Tag const? = null)
    if (!throwable_launcher__inProgress
        || human_eid != gun__owner
        || throwable_launcher_throw__mode != int(ThrowableLauncherThrowMode.TLTM_DIRECT)
        || throwable_launcher_throw__commonItemThrowed)
      return

    let currentTime = get_sync_time()
    let throwAtTime = throwable_launcher_throw__startAtTime + throwable_launcher_throw__throwTime
    let throwTimeIsTooOld = (currentTime - throwAtTime) > MAX_ALLOWED_PING_DELAY 
    let throwTimeIsFuture = currentTime < throwAtTime 

    if throwTimeIsTooOld || throwTimeIsFuture
      throwable_launcher_server_report_fail_throw(evt.throwableLauncherEid, throwable_launcher__inProgress, throwable_launcher_anim__throwInProgress, throwable_launcher_throw__commonItem, throwable_launcher_throw__commonItemThrowed)
      return

    let throwableItemTM = get_throwable_item_transform_relative_to_human(human_net_phys, throwable_launcher_throw__positionOffset, evt.direction)
    let throwableVelocity = get_throwable_item_velocity_relative_to_transform(throwableItemTM, throwable_launcher_throw__velocityDir * throwable_launcher_throw__speed)
    throwable_launcher_throw_item(human_eid, evt.throwableLauncherEid, throwableItemTM, throwableVelocity, throwable_launcher_throw__omega, throwable_launcher_throw__collisionWithOwnerDelay,
                                  throwable_launcher_throw__commonTemplate, throwable_launcher_throw__commonItem, throwable_launcher_throw__commonItemThrowed, false, throwAtTime, currentTime)
    throwable_launcher_decrease_items_count(itemContainer, throwable_launcher__itemsCount, throwable_launcher__inventoryItemName, throwable_launcher_use_items_in_inventory)

[es(tag=gameClient, no_order)]
def throwable_launcher_throw_local_item(info : UpdateStageInfoAct;
                                        eid : EntityId;
                                        gun__owner : EntityId;
                                        throwable_launcher__inProgress : bool;
                                        throwable_launcher_throw__mode : int;
                                        throwable_launcher_throw__startAtTime : float;
                                        throwable_launcher_throw__throwTime : float;
                                        throwable_launcher_throw__localTemplate : string;
                                        throwable_launcher_throw__positionOffset : float3;
                                        throwable_launcher_throw__velocityDir : float3;
                                        throwable_launcher_throw__speed : float;
                                        throwable_launcher_throw__omega : float3;
                                        throwable_launcher_throw__collisionWithOwnerDelay : float;
                                        throwable_launcher_throw__useLocalItem : bool;
                                        var throwable_launcher_throw__localItem : EntityId&;
                                        var throwable_launcher_throw__localItemThrowed : bool&)
  if !throwable_launcher__inProgress || throwable_launcher_throw__localItemThrowed
    return

  let throwAtTime = throwable_launcher_throw__startAtTime + throwable_launcher_throw__throwTime
  if info.curTime < throwAtTime
    return

  query(gun__owner) <| $ [es] (human_net_phys : HumanActor)
    if throwable_launcher_throw__mode == int(ThrowableLauncherThrowMode.TLTM_DIRECT)
      send_net_event(gun__owner, RequestThrowableLauncherDirectThrow(throwableLauncherEid = eid, direction = human_net_phys.phys.appliedCT.wishLookDir))

    if is_server() || !throwable_launcher_throw__useLocalItem
      throwable_launcher_throw__localItemThrowed = true
      return

    let throwableItemTM = get_throwable_item_transform_relative_to_human(human_net_phys, throwable_launcher_throw__positionOffset)
    let throwableVelocity = get_throwable_item_velocity_relative_to_transform(throwableItemTM, throwable_launcher_throw__velocityDir * throwable_launcher_throw__speed)
    throwable_launcher_throw_item(gun__owner, eid, throwableItemTM, throwableVelocity, throwable_launcher_throw__omega, throwable_launcher_throw__collisionWithOwnerDelay,
                                  throwable_launcher_throw__localTemplate, throwable_launcher_throw__localItem, throwable_launcher_throw__localItemThrowed, true, throwAtTime, info.curTime)

[es(tag=server)]
def throwable_launcher_start_throw_server(evt : RequestThrowableLauncherStartThrow;
                                          eid aka human_eid : EntityId;
                                          human_weap__currentGunEid : EntityId)
  if human_weap__currentGunEid != evt.throwableLauncherEid
    return

  query(evt.throwableLauncherEid) <| $ [es] (gun__owner : EntityId;
                                             throwable_launcher__itemsCount : int;
                                             throwable_launcher_anim__throwTime : float;
                                             throwable_launcher_throw__commonTemplate : string;
                                             throwable_launcher_throw__createCommonItemInAdvance : bool;
                                             throwable_launcher_throw__throwTime : float;
                                             throwable_launcher_throw__collisionWithOwnerDelay : float;
                                             var throwable_launcher_throw__commonItem : EntityId&;
                                             var throwable_launcher_throw__commonItemThrowed : bool&;
                                             var throwable_launcher__inProgress : bool&;
                                             var throwable_launcher_throw__startAtTime : float&;
                                             var throwable_launcher_anim__throwInProgress : bool&;
                                             var throwable_launcher_anim__throwStart : float&;
                                             var throwable_launcher_anim__throwEnd : float&;
                                             tnt_exploder__inProgress : bool = false)
    if human_eid != gun__owner || (is_dedicated()  && throwable_launcher__inProgress)
      return

    let currentTime = get_sync_time()
    let itemsCountIsZero = throwable_launcher__itemsCount <= 0
    let requestTimeIsTooOld = (currentTime - evt.atTime) > MAX_ALLOWED_PING_DELAY 
    let requestTimeIsFuture = currentTime < evt.atTime 

    if requestTimeIsTooOld || requestTimeIsFuture || itemsCountIsZero || tnt_exploder__inProgress
      throwable_launcher_server_report_fail_throw(evt.throwableLauncherEid, throwable_launcher__inProgress, throwable_launcher_anim__throwInProgress, throwable_launcher_throw__commonItem, throwable_launcher_throw__commonItemThrowed)
      return

    throwable_launcher_start_throw(human_eid,
                                   evt.throwableLauncherEid,
                                   throwable_launcher_throw__commonTemplate,
                                   throwable_launcher_throw__createCommonItemInAdvance,
                                   throwable_launcher_throw__throwTime,
                                   throwable_launcher_throw__collisionWithOwnerDelay,
                                   throwable_launcher_anim__throwTime,
                                   throwable_launcher__inProgress,
                                   throwable_launcher_throw__commonItem,
                                   throwable_launcher_throw__commonItemThrowed,
                                   throwable_launcher_throw__startAtTime,
                                   throwable_launcher_anim__throwInProgress,
                                   throwable_launcher_anim__throwStart,
                                   throwable_launcher_anim__throwEnd,
                                   false,
                                   evt.atTime,
                                   currentTime)

[es(REQUIRE=(throwable_launcher_hide_on_zero_items, multiple_guns_slot_gun), track=throwable_launcher__itemsCount)]
def throwable_launcher_hide_on_zero_items(evt : Event;
                                          eid : EntityId;
                                          throwable_launcher__itemsCount : int;
                                          multiple_guns_slot_gun_hidden : Tag const?)
  if multiple_guns_slot_gun_hidden != null && throwable_launcher__itemsCount > 0
    removeSubTemplate(eid, "multiple_guns_slot_gun_hidden")
  elif multiple_guns_slot_gun_hidden == null && throwable_launcher__itemsCount <= 0
    addSubTemplate(eid, "multiple_guns_slot_gun_hidden")

[es(tag=gameClient, REQUIRE=throwable_launcher_switch_to_other_weapon_on_zero_items, track=throwable_launcher_anim__throwInProgress)]
def throwable_launcher_switch_to_other_weapon_on_zero_items(evt : Event;
                                                            eid : EntityId;
                                                            gun__owner : EntityId;
                                                            throwable_launcher__itemsCount : int;
                                                            throwable_launcher_anim__throwInProgress : bool)
  if throwable_launcher_anim__throwInProgress || throwable_launcher__itemsCount > 0
    return

  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               human_weap__gunEids : EidList;
                               var human_net_phys : HumanActor&)
    if human_weap__currentGunEid != eid
      return

    switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)

[es(REQUIRE=throwable_launcher_reset_after_anim_end, track=throwable_launcher_anim__throwInProgress, after=throwable_launcher_switch_to_other_weapon_on_zero_items)]
def throwable_launcher_reset_on_anim_end(evt : Event;
                                         eid : EntityId;
                                         gun__owner : EntityId;
                                         throwable_launcher_anim__throwInProgress : bool)
  if throwable_launcher_anim__throwInProgress
    return

  query(gun__owner) <| $ [es] (human_weap__currentGunEid : EntityId;
                               var human_net_phys : HumanActor&)
    if human_weap__currentGunEid != eid
      return
    reset_weapon_state(human_net_phys.phys)

[es(tag=server, REQUIRE=throwable_item, on_appear, track=throwable_item__throwed)]
def throwable_launcher_reset_common_item_on_throw(evt : Event;
                                                  throwable_item__launcher : EntityId;
                                                  throwable_item__throwed : bool)
  if !throwable_item__throwed
    return

  query(throwable_item__launcher) <| $ [es] (var throwable_launcher_throw__commonItem : EntityId&;
                                             var throwable_launcher_throw__commonItemThrowed : bool&)
    throwable_launcher_throw__commonItem = INVALID_ENTITY_ID
    throwable_launcher_throw__commonItemThrowed = true

[es(tag=server, track=(throwable_launcher_anim__throwInProgress, throwable_launcher_throw__commonItemThrowed))]
def throwable_launcher_ready_to_throw(evt : Event;
                                      throwable_launcher_throw__commonItemThrowed : bool;
                                      throwable_launcher_anim__throwInProgress : bool;
                                      var throwable_launcher__inProgress : bool&)
  if throwable_launcher_anim__throwInProgress || !throwable_launcher_throw__commonItemThrowed
    return

  throwable_launcher__inProgress = false
