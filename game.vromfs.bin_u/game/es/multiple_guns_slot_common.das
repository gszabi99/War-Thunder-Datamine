module multiple_guns_slot_common shared
require ecs
require ecs.safe
require ecs.common
require net

require DngHuman
require %game.events



def multiple_guns_slot_select_gun(previous_gun_eid : EntityId;
                                  next_gun_eid : EntityId;
                                  multiple_guns_slot : int;
                                  multiple_guns_slots__gunsEids : EidList;
                                  var human_weap__gunEids : EidList&;
                                  var multiple_guns_slots__wantedGunEid : EidList&;
                                  var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                  var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  human_weap__gunEids[multiple_guns_slot] = next_gun_eid
  multiple_guns_slots__wantedGunEid[multiple_guns_slot] = next_gun_eid
  multiple_guns_slots__hiddenGunInSlot[multiple_guns_slot] = false

  query(previous_gun_eid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (var slot_attach__weaponSlotIdx : int&)
    slot_attach__weaponSlotIdx = -1
  query(next_gun_eid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (var slot_attach__weaponSlotIdx : int?;
                                                                 multiple_guns_slot_gun_hidden : Tag const?)
    if slot_attach__weaponSlotIdx != null
      (*slot_attach__weaponSlotIdx) = multiple_guns_slot
    multiple_guns_slots__hiddenGunInSlot[multiple_guns_slot] = multiple_guns_slot_gun_hidden != null
    if !multiple_guns_slots__hiddenGunInSlot[multiple_guns_slot]
      multiple_guns_slots__lastVisibleGunIndex[multiple_guns_slot] = find_index(multiple_guns_slots__gunsEids, next_gun_eid)

def try_multiple_guns_slot_take_gun_server(next_gun_eid : EntityId;
                                           human_eid : EntityId;
                                           current_gun_slot : int;
                                           multiple_guns_slot : int;
                                           multiple_guns_slots__gunsEids : EidList;
                                           var human_weap__gunEids : EidList&;
                                           var multiple_guns_slots__wantedGunEid : EidList&;
                                           var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                           var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  var result = false
  query(next_gun_eid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (gun__owner : EntityId;
                                                                 multiple_guns_slot_gun__slot : int)
    if human_eid != gun__owner || multiple_guns_slot != multiple_guns_slot_gun__slot
      return

    if multiple_guns_slot == current_gun_slot
      multiple_guns_slots__wantedGunEid[multiple_guns_slot] = next_gun_eid
      result = true
      return

    assume previous_gun_eid = human_weap__gunEids[multiple_guns_slot]
    if next_gun_eid != previous_gun_eid
      multiple_guns_slot_select_gun(previous_gun_eid, next_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                    multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

    send_net_event(human_eid, [[CmdSelectWeaponSlot slot=uint8(multiple_guns_slot)]])
    result = true
  return result

def try_multiple_guns_slot_select_gun_server(human_eid : EntityId;
                                             wanted_gun_eid : EntityId;
                                             multiple_guns_slot : int)
  var result = false
  query(human_eid) <| $ [es] (multiple_guns_slots__gunsEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              var human_weap__gunEids : EidList&;
                              var multiple_guns_slots__wantedGunEid : EidList&;
                              var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                              var multiple_guns_slots__lastVisibleGunIndex : IntList&)
    result = try_multiple_guns_slot_select_gun_server(human_eid, wanted_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)
  return result

def try_multiple_guns_slot_select_gun_server(eid aka human_eid : EntityId;
                                             wanted_gun_eid : EntityId;
                                             multiple_guns_slot : int;
                                             multiple_guns_slots__gunsEids : EidList;
                                             multiple_guns_slots__active : BoolList;
                                             var human_weap__gunEids : EidList&;
                                             var multiple_guns_slots__wantedGunEid : EidList&;
                                             var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                             var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false) || length(human_weap__gunEids) <= multiple_guns_slot
    return false

  assume currentGun = human_weap__gunEids[multiple_guns_slot]
  if wanted_gun_eid == currentGun
    return true

  if wanted_gun_eid == INVALID_ENTITY_ID
    multiple_guns_slot_select_gun(currentGun, INVALID_ENTITY_ID, multiple_guns_slot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                  multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)
    return true

  var result = false
  query(wanted_gun_eid) <| $ [es(REQUIRE=multiple_guns_slot_gun)] (gun__owner : EntityId;
                                                                   multiple_guns_slot_gun__slot : int)
    if human_eid != gun__owner || multiple_guns_slot != multiple_guns_slot_gun__slot
      return
    multiple_guns_slot_select_gun(currentGun, wanted_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                  multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)
    result = true
  return result

def try_multiple_guns_slot_equip_gun_server(human_eid : EntityId;
                                            wanted_gun_eid : EntityId;
                                            multiple_guns_slot : int)
  var result = false
  query(human_eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                              human_weap__currentGunSlot : int;
                              multiple_guns_slots__gunsEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              var human_weap__gunEids : EidList&;
                              var multiple_guns_slots__wantedGunEid : EidList&;
                              var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                              var multiple_guns_slots__lastVisibleGunIndex : IntList&)
    result = try_multiple_guns_slot_equip_gun_server(human_eid, human_weap__currentGunEid, human_weap__currentGunSlot, wanted_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                                     human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)
  return result

def try_multiple_guns_slot_equip_gun_server(eid aka human_eid : EntityId;
                                            human_weap__currentGunEid : EntityId;
                                            human_weap__currentGunSlot : int;
                                            wanted_gun_eid : EntityId;
                                            multiple_guns_slot : int;
                                            multiple_guns_slots__gunsEids : EidList;
                                            multiple_guns_slots__active : BoolList;
                                            var human_weap__gunEids : EidList&;
                                            var multiple_guns_slots__wantedGunEid : EidList&;
                                            var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                            var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false) || length(human_weap__gunEids) <= multiple_guns_slot
    return false

  var gunToEquip = wanted_gun_eid
  if gunToEquip == INVALID_ENTITY_ID
    gunToEquip = get_multiple_guns_slot_last_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)

  if gunToEquip == human_weap__currentGunEid
    return true

  return try_multiple_guns_slot_take_gun_server(gunToEquip, human_eid, human_weap__currentGunSlot, multiple_guns_slot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                                multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

def try_multiple_guns_slot_equip_next_gun_server(human_eid : EntityId;
                                                 multiple_guns_slot : int)
  var result = false
  query(human_eid) <| $ [es] (human_weap__currentGunEid : EntityId;
                              human_weap__currentGunSlot : int;
                              multiple_guns_slots__gunsEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              var human_weap__gunEids : EidList&;
                              var multiple_guns_slots__wantedGunEid : EidList&;
                              var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                              var multiple_guns_slots__lastVisibleGunIndex : IntList&)
    result = try_multiple_guns_slot_equip_next_gun_server(human_eid, human_weap__currentGunEid, human_weap__currentGunSlot, multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                                          human_weap__gunEids, multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)
  return result

def try_multiple_guns_slot_equip_next_gun_server(human_eid : EntityId;
                                                 human_weap__currentGunEid : EntityId;
                                                 human_weap__currentGunSlot : int;
                                                 multiple_guns_slot : int;
                                                 multiple_guns_slots__gunsEids : EidList;
                                                 multiple_guns_slots__active : BoolList;
                                                 var human_weap__gunEids : EidList&;
                                                 var multiple_guns_slots__wantedGunEid : EidList&;
                                                 var multiple_guns_slots__hiddenGunInSlot : BoolList&;
                                                 var multiple_guns_slots__lastVisibleGunIndex : IntList&)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false) || length(human_weap__gunEids) <= multiple_guns_slot
    return false

  var nextGun = INVALID_ENTITY_ID
  if human_weap__currentGunSlot == multiple_guns_slot
    nextGun = get_multiple_guns_slot_next_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
  else
    nextGun = get_multiple_guns_slot_last_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)

  if nextGun == human_weap__currentGunEid
    return true

  return try_multiple_guns_slot_take_gun_server(nextGun, human_eid, human_weap__currentGunSlot, multiple_guns_slot, multiple_guns_slots__gunsEids, human_weap__gunEids,
                                                multiple_guns_slots__wantedGunEid, multiple_guns_slots__hiddenGunInSlot, multiple_guns_slots__lastVisibleGunIndex)

def get_multiple_guns_slot_next_visible_gun(multiple_guns_slot : int;
                                            multiple_guns_slots__gunsEids : EidList;
                                            multiple_guns_slots__active : BoolList;
                                            multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false)
    return INVALID_ENTITY_ID

  let gunsCount = length(multiple_guns_slots__gunsEids)
  if gunsCount <= 0
    return INVALID_ENTITY_ID

  var lastGunIdx = multiple_guns_slots__lastVisibleGunIndex[multiple_guns_slot]
  if lastGunIdx < -1 || gunsCount <= lastGunIdx
    lastGunIdx = -1

  var nextGun = INVALID_ENTITY_ID
  let startIndex = lastGunIdx + 1
  for i in range(startIndex, startIndex + gunsCount)
    let nextGunIdx = i % gunsCount
    query(multiple_guns_slots__gunsEids[nextGunIdx]) <| $ [es(REQUIRE_NOT=multiple_guns_slot_gun_hidden)] (multiple_guns_slot_gun__slot : int)
      if multiple_guns_slot_gun__slot == multiple_guns_slot
        nextGun = multiple_guns_slots__gunsEids[nextGunIdx]
    if nextGun != INVALID_ENTITY_ID
      return nextGun
  return INVALID_ENTITY_ID

def get_multiple_guns_slot_last_visible_gun(multiple_guns_slot : int;
                                            multiple_guns_slots__gunsEids : EidList;
                                            multiple_guns_slots__active : BoolList;
                                            multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false)
    return INVALID_ENTITY_ID

  let gunsCount = length(multiple_guns_slots__gunsEids)
  if gunsCount <= 0
    return INVALID_ENTITY_ID

  let lastGunIdx = multiple_guns_slots__lastVisibleGunIndex[multiple_guns_slot]
  if lastGunIdx < 0 || gunsCount <= lastGunIdx || has(multiple_guns_slots__gunsEids[lastGunIdx], "multiple_guns_slot_gun_hidden")
    return get_multiple_guns_slot_next_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
  return multiple_guns_slots__gunsEids[lastGunIdx]

def can_switch_to_multiple_guns_slot(current_gun_eid : EntityId;
                                     multiple_guns_slot : int;
                                     multiple_guns_slots__gunsEids : EidList;
                                     multiple_guns_slots__active : BoolList;
                                     multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false)
    return false
  let lastGun = get_multiple_guns_slot_last_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
  return current_gun_eid == lastGun

def can_multiple_guns_slot_equip_next_gun(current_gun_eid : EntityId;
                                          multiple_guns_slot : int;
                                          current_gun_slot : int;
                                          multiple_guns_slots__gunsEids : EidList;
                                          multiple_guns_slots__active : BoolList;
                                          multiple_guns_slots__wantedGunEid : EidList;
                                          multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false)
    return false

  if multiple_guns_slot == current_gun_slot
    if current_gun_eid != multiple_guns_slots__wantedGunEid[multiple_guns_slot]
      return false
    let nextGun = get_multiple_guns_slot_next_visible_gun(multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
    if !nextGun || current_gun_eid == nextGun
      return false
  else
    if !current_gun_eid || !can_switch_to_multiple_guns_slot(current_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
      return false
  return true

def try_request_multiple_guns_slot_equip_next_gun(human_eid : EntityId;
                                                  multiple_guns_slot : int)
  var result = false
  query(human_eid) <| $ [es] (human_weap__currentGunSlot : int;
                              human_weap__gunEids : EidList;
                              multiple_guns_slots__gunsEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              multiple_guns_slots__wantedGunEid : EidList;
                              multiple_guns_slots__lastVisibleGunIndex : IntList)
    result = try_request_multiple_guns_slot_equip_next_gun(human_eid, human_weap__gunEids[multiple_guns_slot], multiple_guns_slot, human_weap__currentGunSlot,
                                                           multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
  return result

def try_request_multiple_guns_slot_equip_next_gun(human_eid : EntityId;
                                                  current_gun_eid : EntityId;
                                                  multiple_guns_slot : int;
                                                  current_gun_slot : int;
                                                  multiple_guns_slots__gunsEids : EidList;
                                                  multiple_guns_slots__active : BoolList;
                                                  multiple_guns_slots__wantedGunEid : EidList;
                                                  multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !can_multiple_guns_slot_equip_next_gun(current_gun_eid, multiple_guns_slot, current_gun_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                            multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
    return false
  send_net_event(human_eid, [[RequestMultipleGunsSlotEquipNextGun slot = multiple_guns_slot]])
  return true

def can_multiple_guns_slot_equip_gun(current_gun_eid : EntityId;
                                     wanted_gun_eid : EntityId;
                                     multiple_guns_slot : int;
                                     current_gun_slot : int;
                                     multiple_guns_slots__gunsEids : EidList;
                                     multiple_guns_slots__active : BoolList;
                                     multiple_guns_slots__wantedGunEid : EidList;
                                     multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !(multiple_guns_slots__active?[multiple_guns_slot] ?? false) || !wanted_gun_eid
    return false

  if multiple_guns_slot == current_gun_slot
    if current_gun_eid != multiple_guns_slots__wantedGunEid[multiple_guns_slot] || current_gun_eid == wanted_gun_eid
      return false
  else
    if !can_switch_to_multiple_guns_slot(current_gun_eid, multiple_guns_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__lastVisibleGunIndex)
      return false
  return true

def try_request_multiple_guns_slot_equip_gun(human_eid : EntityId;
                                             wanted_gun_eid : EntityId;
                                             multiple_guns_slot : int)
  var result = false
  query(human_eid) <| $ [es] (human_weap__currentGunSlot : int;
                              human_weap__gunEids : EidList;
                              multiple_guns_slots__gunsEids : EidList;
                              multiple_guns_slots__active : BoolList;
                              multiple_guns_slots__wantedGunEid : EidList;
                              multiple_guns_slots__lastVisibleGunIndex : IntList)
    result = try_request_multiple_guns_slot_equip_gun(human_eid, human_weap__gunEids[multiple_guns_slot], wanted_gun_eid, multiple_guns_slot, human_weap__currentGunSlot,
                                                      multiple_guns_slots__gunsEids, multiple_guns_slots__active, multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
  return result

def try_request_multiple_guns_slot_equip_gun(human_eid : EntityId;
                                             current_gun_eid : EntityId;
                                             wanted_gun_eid : EntityId;
                                             multiple_guns_slot : int;
                                             current_gun_slot : int;
                                             multiple_guns_slots__gunsEids : EidList;
                                             multiple_guns_slots__active : BoolList;
                                             multiple_guns_slots__wantedGunEid : EidList;
                                             multiple_guns_slots__lastVisibleGunIndex : IntList)
  if !can_multiple_guns_slot_equip_gun(current_gun_eid, wanted_gun_eid, multiple_guns_slot, current_gun_slot, multiple_guns_slots__gunsEids, multiple_guns_slots__active,
                                       multiple_guns_slots__wantedGunEid, multiple_guns_slots__lastVisibleGunIndex)
    return false
  send_net_event(human_eid, [[RequestMultipleGunsSlotEquipGun gunEid = wanted_gun_eid, slot = multiple_guns_slot]])
  return true
