require ecs
require ecs.safe
require app
require net
require %game.events
require ecs.common
require DngHuman
require HumanPhys
require %appGame.infantry.es.human_weap_common
require %appGame.infantry.es.multiple_guns_slot_common

def multiple_guns_slot_switch_is_anim_progress_valid_to_change_weapon(human_net_phys : HumanActor; multiple_guns_slot : int)
  let curSlot = int(human_net_phys.phys.currentState.weapEquipState.curSlot)
  let nextSlot = int(human_net_phys.phys.currentState.weapEquipState.nextSlot)
  if curSlot != multiple_guns_slot || nextSlot != multiple_guns_slot
    return false
  let prevStateProgress = human_net_phys.phys.previousState.weapEquipState.progress
  let curStateProgress = human_net_phys.phys.currentState.weapEquipState.progress
  let curState = human_net_phys.phys.currentState.weapEquipState.curState
  if curStateProgress < prevStateProgress && curState == HUWeaponEquipState.EES_EQUIPING
    return true
  return false

def multiple_guns_slot_switch_client(human_eid : EntityId;
                                     previous_gun_eid : EntityId;
                                     next_gun_eid : EntityId;
                                     multiple_guns_slot : int)
  sendEventImmediate(previous_gun_eid, CmdWeapAttach(toEid = human_eid, isAttached = false, slotId = multiple_guns_slot))
  setOptional(previous_gun_eid, "animchar_render__enabled", false)
  sendEventImmediate(next_gun_eid, CmdWeapAttach(toEid = human_eid, isAttached = true, slotId = multiple_guns_slot))
  setOptional(next_gun_eid, "animchar_render__enabled", true)

[es(tag=server, on_appear)]
def multiple_guns_slot_init(evt : Event;
                            multiple_guns_slots__active : BoolList;
                            var multiple_guns_slots__wantedGunEid : EidList&;
                            var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                            var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  let MultipleGunsSlotsCount = length(multiple_guns_slots__active)
  multiple_guns_slots__wantedGunEid |> resize(MultipleGunsSlotsCount)
  multiple_guns_slots__hiddenGunInSlot |> resize(MultipleGunsSlotsCount)
  multiple_guns_slots__lastVisibleGunIndex |> resize(MultipleGunsSlotsCount)
  for i in range(MultipleGunsSlotsCount)
    multiple_guns_slots__wantedGunEid[i] = INVALID_ENTITY_ID
    multiple_guns_slots__hiddenGunInSlot[i] = false
    multiple_guns_slots__lastVisibleGunIndex[i] = -1

[es(tag=server, after=(human_weap_created_server_es, human_weap_reinit_guns_es, multiple_guns_slot_init), track=(itemContainer, multiple_guns_slots__additionalGunsEids), on_event=CmdReinitWeapons, on_appear)]
def multiple_guns_slot_fill_inventory_gun_items(evt : Event;
                                                eid : EntityId;
                                                itemContainer : EidList;
                                                human_weap__currentGunSlot : int;
                                                multiple_guns_slots__active : BoolList;
                                                multiple_guns_slots__additionalGunsEids : EidList;
                                                var human_weap__gunEids : EidList&;
                                                var multiple_guns_slots__gunsEids : EidList&;
                                                var multiple_guns_slots__wantedGunEid : EidList&;
                                                var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                                var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  var newMultipleGunsSlotsItems : array<EntityId>
  for itemEid in multiple_guns_slots__additionalGunsEids
    query(itemEid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (multiple_guns_slot_gun__slot : int;
                                                              var gun__owner : EntityId&)
      gun__owner = eid
      if multiple_guns_slots__active?[multiple_guns_slot_gun__slot] ?? false
        push(newMultipleGunsSlotsItems, itemEid)

  for itemEid in itemContainer
    query(itemEid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (multiple_guns_slot_gun__slot : int;
                                                              var gun__owner : EntityId&)
      gun__owner = eid
      if multiple_guns_slots__active?[multiple_guns_slot_gun__slot] ?? false
        push(newMultipleGunsSlotsItems, itemEid)

  clear(multiple_guns_slots__gunsEids)
  for itemEid in newMultipleGunsSlotsItems
    push(multiple_guns_slots__gunsEids, itemEid)

  let iterRange = min(length(multiple_guns_slots__active), length(human_weap__gunEids))
  for i, multipleGunSlotIsActive in range(iterRange), multiple_guns_slots__active
    if !multipleGunSlotIsActive
      continue

    assume currentGun = human_weap__gunEids[i]
    let currentGunIdx = find_index(multiple_guns_slots__gunsEids, currentGun)

    if !!currentGun
      multiple_guns_slots__wantedGunEid[i] = currentGun
      multiple_guns_slots__lastVisibleGunIndex[i] = has(currentGun, "multiple_guns_slot_gun_hidden") ? -1 : currentGunIdx
      return

    let gunToSelect = get_multiple_guns_slot_last_visible_gun(i, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
    if human_weap__currentGunSlot == i
      if gunToSelect != INVALID_ENTITY_ID
        multiple_guns_slots__wantedGunEid[i] = gunToSelect
    else
      multiple_guns_slot_select_gun(eid, currentGun, gunToSelect, i, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                    multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

[es(tag=gameClient, track=multiple_guns_slots__gunsEids)]
def multiple_guns_slot_empty(evt : Event;
                             human_weap__currentGunSlot : int;
                             human_weap__gunEids : EidList;
                             multiple_guns_slots__gunsEids : EidList;
                             multiple_guns_slots__active : BoolList;
                             multiple_guns_slots__lastVisibleGunIndex : IntList;
                             var human_net_phys : HumanActor&)
  if !(multiple_guns_slots__active?[human_weap__currentGunSlot] ?? false)
    return

  let currentGun = get_multiple_guns_slot_last_visible_gun(human_weap__currentGunSlot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
  if currentGun == INVALID_ENTITY_ID
    return

  switch_to_first_weap_with_ammo(human_weap__gunEids, human_net_phys.phys)

[es(tag=server)]
def multiple_guns_slot_reqeust_select_gun(evt : RequestMultipleGunsSlotSelectGun;
                                          eid aka human_eid : EntityId;
                                          multiple_guns_slots__gunsEids : EidList;
                                          multiple_guns_slots__active : BoolList;
                                          var human_weap__gunEids : EidList&;
                                          var multiple_guns_slots__wantedGunEid : EidList&;
                                          var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                          var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  try_multiple_guns_slot_select_gun_server(human_eid, evt.gunEid, evt.slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                           human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

[es(tag=server)]
def multiple_guns_slot_reqeust_equip_gun(evt : RequestMultipleGunsSlotEquipGun;
                                         eid aka human_eid : EntityId;
                                         human_weap__currentGunEid : EntityId;
                                         human_weap__currentGunSlot : int;
                                         multiple_guns_slots__gunsEids : EidList;
                                         multiple_guns_slots__active : BoolList;
                                         var human_weap__gunEids : EidList&;
                                         var multiple_guns_slots__wantedGunEid : EidList&;
                                         var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                         var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  try_multiple_guns_slot_equip_gun_server(human_eid, human_weap__currentGunEid, human_weap__currentGunSlot, evt.gunEid, evt.slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                          human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

[es(tag=server)]
def multiple_guns_slot_reqeust_equip_next_gun(evt : RequestMultipleGunsSlotEquipNextGun;
                                              eid aka human_eid : EntityId;
                                              human_weap__currentGunEid : EntityId;
                                              human_weap__currentGunSlot : int;
                                              multiple_guns_slots__gunsEids : EidList;
                                              multiple_guns_slots__active : BoolList;
                                              var human_weap__gunEids : EidList&;
                                              var multiple_guns_slots__wantedGunEid : EidList&;
                                              var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                              var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  try_multiple_guns_slot_equip_next_gun_server(human_eid, human_weap__currentGunEid, human_weap__currentGunSlot, evt.slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                               human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

[es(track=(multiple_guns_slots__wantedGunEid, action__running))]
def multiple_guns_slot_switch_start(evt : Event;
                                    human_weap__currentGunSlot : int;
                                    human_weap__gunEids : EidList;
                                    action__running : bool;
                                    multiple_guns_slots__active : BoolList;
                                    multiple_guns_slots__wantedGunEid : EidList;
                                    var human_net_phys : HumanActor&)
  if !(multiple_guns_slots__active?[human_weap__currentGunSlot] ?? false)
    return

  assume wantedGun = multiple_guns_slots__wantedGunEid[human_weap__currentGunSlot]
  assume currentGun = human_weap__gunEids[human_weap__currentGunSlot]
  if action__running || wantedGun == INVALID_ENTITY_ID || wantedGun == currentGun
    return

  reset_weapon_state(human_net_phys.phys)

[es(tag=gameClient, no_order)]
def multiple_guns_slot_switch_progress(info : ParallelUpdateFrameDelayed;
                                       eid aka human_eid : EntityId;
                                       human_weap__currentGunEid : EntityId;
                                       human_weap__currentGunSlot : int;
                                       human_net_phys : HumanActor;
                                       action__running : bool;
                                       multiple_guns_slots__gunsEids : EidList;
                                       multiple_guns_slots__active : BoolList;
                                       var human_weap__gunEids : EidList&;
                                       var multiple_guns_slots__wantedGunEid : EidList&;
                                       var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                       var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  if !(multiple_guns_slots__active?[human_weap__currentGunSlot] ?? false)
    return

  let wantedGun = multiple_guns_slots__wantedGunEid[human_weap__currentGunSlot]
  let currentGun = human_weap__gunEids[human_weap__currentGunSlot]
  if (action__running
      || wantedGun == INVALID_ENTITY_ID
      || wantedGun == currentGun
      || human_weap__currentGunEid != currentGun
      || !multiple_guns_slot_switch_is_anim_progress_valid_to_change_weapon(human_net_phys, human_weap__currentGunSlot))
    return

  send_net_event(human_eid, RequestMultipleGunsSlotSelectGun(gunEid = wantedGun, slot = human_weap__currentGunSlot))
  multiple_guns_slot_switch_client(human_eid, currentGun, wantedGun, human_weap__currentGunSlot)
  multiple_guns_slot_select_gun(human_eid, currentGun, wantedGun, human_weap__currentGunSlot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

[es(tag=server, track=human_weap__currentGunSlot, REQUIRE=human_weap__currentGunSlot)]
def multiple_guns_slot_on_switch_to_other_slot(evt : Event;
                                               human_weap__gunEids : EidList;
                                               human_weap__previousGunSlot : int;
                                               multiple_guns_slots__active : BoolList;
                                               var multiple_guns_slots__wantedGunEid : EidList&)
  if !(multiple_guns_slots__active?[human_weap__previousGunSlot] ?? false)
    return

  assume currentGun = human_weap__gunEids[human_weap__previousGunSlot]
  assume wantedGun = multiple_guns_slots__wantedGunEid[human_weap__previousGunSlot]
  if wantedGun != currentGun
    wantedGun = currentGun

[es(tag=gameClient, track=multiple_guns_slots__hiddenGunInSlot)]
def multiple_guns_slot_contain_any_hidden_gun_in_slots(evt : Event;
                                                       multiple_guns_slots__hiddenGunInSlot : BoolList;
                                                       multiple_guns_slots__hiddenGunHideDelay : float;
                                                       var multiple_guns_slots__hiddenGunInAnySlot : bool&;
                                                       var multiple_guns_slots__hiddenGunDontHideUntil : float&)
  multiple_guns_slots__hiddenGunInAnySlot = false
  for hiddenGunInSlot in multiple_guns_slots__hiddenGunInSlot
    multiple_guns_slots__hiddenGunInAnySlot ||= hiddenGunInSlot

  if multiple_guns_slots__hiddenGunInAnySlot
    multiple_guns_slots__hiddenGunDontHideUntil = get_sync_time() + multiple_guns_slots__hiddenGunHideDelay

[es(tag=gameClient, after=multiple_guns_slot_contain_any_hidden_gun_in_slots)]
def multiple_guns_slot_hide_hidden_guns_when_not_in_hands(info : UpdateStageInfoAct;
                                                          eid aka human_eid : EntityId;
                                                          human_net_phys : HumanActor;
                                                          human_weap__currentGunSlot : int;
                                                          multiple_guns_slots__gunsEids : EidList;
                                                          multiple_guns_slots__active : BoolList;
                                                          multiple_guns_slots__hiddenGunInAnySlot : bool;
                                                          multiple_guns_slots__hiddenGunDontHideUntil : float;
                                                          multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                                          multiple_guns_slots__lastVisibleGunIndex : IntList&)
  if !multiple_guns_slots__hiddenGunInAnySlot || info.curTime < multiple_guns_slots__hiddenGunDontHideUntil
    return
  for slot in iter_range(multiple_guns_slots__hiddenGunInSlot)
    if !multiple_guns_slots__hiddenGunInSlot[slot] || int(human_net_phys.phys.producedCT.chosenWeapon) == slot || human_weap__currentGunSlot == slot
      continue

    let lastVisibleGun = get_multiple_guns_slot_last_visible_gun(slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
    send_net_event(human_eid, RequestMultipleGunsSlotSelectGun(gunEid = lastVisibleGun, slot = slot))
