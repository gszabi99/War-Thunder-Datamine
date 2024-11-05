from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { ceil, fabs } = require("math")
let DataBlock = require("DataBlock")
let { BULLET_TYPE } = require("%scripts/weaponry/bulletsInfo.nut")
let { TRIGGER_TYPE, addWeaponsFromBlk, getPresetsList, getUnitWeaponry,
  isWeaponEnabled, isWeaponUnlocked, getWeaponNameByBlkPath } = require("%scripts/weaponry/weaponryInfo.nut")
let { WEAPON_PRESET_TIER } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getTierTooltipParams } = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { MIN_TIERS_COUNT, CHAPTER_ORDER, CHAPTER_FAVORITE_IDX, CHAPTER_NEW_IDX, CUSTOM_PRESET_PREFIX,
  getUnitPresets, isCustomPreset, getWeaponsByTypes, getWeaponBlkParams, getSlotsWeaponsForEditPreset,
  getUnitWeaponSlots
} = require("%scripts/weaponry/weaponryPresets.nut")
let { getCustomPresetByPresetBlk, convertPresetToBlk
} = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { appendOnce } = u
let { cutPrefix } = require("%sqstd/string.nut")
let { openRestrictionsWeaponryPreset } = require("%scripts/weaponry/restrictionsWeaponryPreset.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { getMeasureTypeByName } = require("%scripts/measureType.nut")
let { isUnitUsable } = require("%scripts/unit/unitStatus.nut")

const WEAPON_PRESET_FAVORITE = "weaponPreset/favorite/"

local PURPOSE_TYPE = {
  AIR_TO_AIR = [BULLET_TYPE.AAM, BULLET_TYPE.ROCKET_AIR]
  AIR_TO_SEA = [BULLET_TYPE.TORPEDO]
  ARMORED    = [BULLET_TYPE.ATGM_TANK, BULLET_TYPE.AP_TANK, BULLET_TYPE.ATGM_TANDEM_TANK]
}

let GROUP_ORDER = [
  [TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.MINES, TRIGGER_TYPE.TORPEDOES],
  [TRIGGER_TYPE.ROCKETS],
  [TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON, TRIGGER_TYPE.ADD_GUN, TRIGGER_TYPE.TURRETS,
    TRIGGER_TYPE.SMOKE, TRIGGER_TYPE.FLARES],
  [TRIGGER_TYPE.AGM, TRIGGER_TYPE.ATGM],
  [TRIGGER_TYPE.AAM]
]

local unAllocatedTiers = []

function getWeaponrySize(massKg) {
  let blk = GUI.get()?.weaponrySizes
  if (blk == null)
    return ""

  let sizes = (blk % "size").sort(@(a, b)a.max <=> b.max)
  foreach (size in sizes)
    if (massKg > size.max)
      continue
    else
      return size.id
  return ""
}

let checkIsNotWeaponry = @(inst) inst?.trigger == "fuel tanks" || inst?.trigger == "boosters"

function getTypeByPurpose(weaponry) {
  if (u.isEmpty(weaponry))
    return "NONE"

  let res = []
  foreach (triggerType in (weaponry?.weaponsByTypes ?? {}))
    foreach (inst in triggerType) {
      if (checkIsNotWeaponry(inst))
        continue
      foreach (w in inst.weaponBlocks) {
        // Lack of bullet types or all types that is not in PURPOSE_TYPE is AIR_TO_GROUND type
        local isFound = false
        if (w.bulletType != null)
          foreach (pTypeName, pType in PURPOSE_TYPE) {
            foreach (tag in pType) {
              if (w.bulletType == tag) {
                if (!isInArray(pTypeName, res))
                  res.append(pTypeName)
                isFound = true
                break
              }
            }
            if (isFound)
              break
          }
        if (!isFound && !isInArray("AIR_TO_GROUND", res))
          res.append("AIR_TO_GROUND")
      }
    }

  return res.len() == 0 ? "UNIVERSAL"
    : res.len() == 1 ? res[0]
    : isInArray("AIR_TO_AIR", res) ? "UNIVERSAL"
    : isInArray("AIR_TO_SEA", res) ? "AIR_TO_SEA"
    : "AIR_TO_GROUND"
}

function getTierIcon(weaponry, itemsNum) {
  let path = "#ui/gameuiskin#"
  let triggerType = weaponry.tType
  let iconType = weaponry.iconType
  let isGroup = itemsNum > 1
  let isBlock = (weaponry?.amountPerTier ?? 0) > 1

  if (iconType != null)
    return $"{path}{iconType}"

  if (triggerType == TRIGGER_TYPE.TORPEDOES)
    return $"{path}air_torpedo"

  if (triggerType == TRIGGER_TYPE.ATGM)
    return $"{path}atgm_type2_x2"

  if (isInArray(triggerType,
    [TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON, TRIGGER_TYPE.ADD_GUN]))
      return isBlock || isGroup ? $"{path}multibarrel_gun" : $"{path}machine_gun"

  if (triggerType == TRIGGER_TYPE.AGM)
    return $"{path}missile_air_to_earth"

  if (triggerType == TRIGGER_TYPE.AAM)
    return isBlock || isGroup ? $"{path}missile_air_to_air_group" : $"{path}missile_air_to_air"

  if (triggerType == TRIGGER_TYPE.FLARES)
    return $"{path}ltc"

  let size = getWeaponrySize(weaponry.massKg)
  let wStr = isBlock && triggerType == TRIGGER_TYPE.ROCKETS ? "nar" : triggerType
  let groupStr = isBlock || isGroup ? $"{size}_group" : size

  return $"{path}{wStr}_{groupStr}"
}

function createTier(weaponry, presetName, unitName, itemsNum = 0) {
  let tierId  = weaponry?.tierId ?? -1
  let tierWeaponry = weaponry.__merge({ itemsNum = itemsNum })
  itemsNum = itemsNum > 0 ? itemsNum : weaponry.num
  return {
    tierId  = tierId
    weaponry = tierWeaponry
    img = getTierIcon(weaponry, itemsNum)
    tierTooltipId = WEAPON_PRESET_TIER.getTooltipId(unitName,
      getTierTooltipParams(tierWeaponry, presetName, tierId))
  }
}

function getBlocks(weaponry) {
  let amountPerTier = weaponry.amountPerTier
  if (amountPerTier == null)
    return [weaponry]

  let count = weaponry.num / amountPerTier
  let rest = weaponry.num % amountPerTier
  let res = []
  if (count > 0)
    res.append(weaponry.__merge({
      num = count
      amountPerTier = amountPerTier
    }))
  if (rest > 0)
    res.append(weaponry.__merge({ num = rest }))

  return res
}

function getWeaponryDistribution(weaponry, preset, unitName, isCentral = false) {
  let isEvenCount = weaponry.num % 2 == 0
  let isAllocateByGroup = preset.totalItemsAmount > preset.weaponsSlotCount
  // Group weapons when numbers of free tiers less then weapon items amount
  if (isAllocateByGroup) {
    if (!isCentral && isEvenCount) {
      let tier = createTier(weaponry, preset.name, unitName, weaponry.num / 2)
      return [tier, clone tier]
    }
    else
      return [createTier(weaponry, preset.name, unitName)]
  }
  // Place one weapon item per one tier when tiers amount is enough
  let res = []
  for (local i = 0; i < weaponry.num; i++) {
    // Set empty tier in center when count is EVEN
    if (isCentral && isEvenCount && i == weaponry.num / 2)
      res.append({ tierId = -1 })
    res.append(createTier(weaponry, preset.name,  unitName, 1))
  }

  return res
}

// Needs to keep in mind a few kinds of entities:
//  - simply weapon such as "bombs", "rockets" etc
//  - group of weapons (a few instances of the same type weapon placed into one tier) such as "bombs_group"
//  - weapon block (a few instances of the same type weapon united in functional block,
//    looked like one whole and being an one new entity) such as "rockets_block".
function getWeaponryGroup(preset, groupOrder) {
  let res = []
  foreach (triggerType in groupOrder)
    if (preset?.weaponsByTypes[triggerType] != null)
      foreach (w in preset.weaponsByTypes[triggerType].weaponBlocks)
        res.extend(getBlocks(w.__merge({ tType = triggerType })))
  // Needs additional sort by ammo to define "heaviest" block among identical mass blocks
  return res.sort(@(a, b) b.massKg <=> a.massKg || b.ammo <=> a.ammo)
}

// It set indexes to tiers place symmetric from center to edges
function getIndexedTiers(tiers, tiersCount, weaponsSlotCount) {
  let middleTierIdx = ceil(weaponsSlotCount / 2.0).tointeger() - 1
  if (tiersCount == 0) { // CENTRAL part of tiers
    let delta = ceil(tiers.len() / 2.0).tointeger() - 1
    for (local i = 0; i < tiers.len(); i++)
      tiers[i].tierId = middleTierIdx - (delta - i)
  }
  else { // SIDE part of tiers
    let isEvenCount = tiers.len() % 2 == 0
    if (!isEvenCount) // if SIDE tier has odd number of weapons
      unAllocatedTiers.append(tiers.pop())
    let lim = tiers.len() / 2
    let delta = ceil(tiersCount / 2.0).tointeger()
    for (local i = 0; i < lim; i++) {
      tiers[i].tierId = middleTierIdx + delta + i
      tiers[i + lim].tierId = middleTierIdx - delta - i
    }
  }

  return tiers
}

function getPredefinedTiers(preset, unitName) {
  let res = []
  let filledTiers = {}
  foreach (triggerType, triggers in (preset?.weaponsByTypes ?? {}))
    foreach (weaponry in triggers.weaponBlocks)
      if (weaponry?.tiers && !u.isEmpty(weaponry.tiers)) { // Tiers config takes effect only when all weapons in preset have tiers
        let amountPerTier = weaponry.amountPerTier ?? 1
        let iconType = weaponry.iconType
        foreach (idx, tier in weaponry.tiers) {
          let tierId = min(idx, preset.weaponsSlotCount - 1) // To avoid possible mistakes from config with incorrect tier idx
          let params = {
            tierId = tierId
            tType = triggerType
            isBlock = (tier?.amountPerTier ?? amountPerTier) > 1
            iconType  = tier?.iconType ?? iconType
            tooltipLang = tier?.tooltipLang
          }
          if (filledTiers?[tierId]) {
            // Create additional tiers info and add it on already existing tier if two weapons placed per one tier
            let currTier = u.search(res, @(p) p.tierId == tierId)
            if (currTier) {
              currTier.weaponry.addWeaponry <- weaponry.__merge(params.__merge({
                itemsNum = weaponry.num / (tier?.amountPerTier ?? amountPerTier) }))
              currTier.tierTooltipId = WEAPON_PRESET_TIER.getTooltipId(unitName,
                getTierTooltipParams(currTier.weaponry, preset.name, tierId))
            }

            continue
          }
          else
            filledTiers[tierId] <- weaponry

          res.append(createTier(weaponry.__merge(params),
            preset.name,  unitName, weaponry.num / (tier?.amountPerTier ?? amountPerTier)))
        }
      }

  if (res.len() == 0)
    return res

  // Add empty tiers in set if predefined tiers exist
  for (local i = res.len(); i < preset.weaponsSlotCount; i++)
    for (local j = 0; j < preset.weaponsSlotCount; j++)
      if (filledTiers?[j] == null) {
        res.append({ tierId = j })
        filledTiers[j] <- {}
      }

  return res
}

function getTiers(unit, preset) {
  let res = getPredefinedTiers(preset, unit.name)
  unAllocatedTiers = []

  if (!res.len()) {
    for (local i = 0; i < GROUP_ORDER.len(); i++)
      foreach (triggerType in GROUP_ORDER[i])
        if (preset?.weaponsByTypes[triggerType]) {
          let group = getWeaponryGroup(preset, GROUP_ORDER[i])
          for (local j = 0; j < group.len(); j++)
            res.extend(getIndexedTiers(getWeaponryDistribution(group[j],
              preset, unit.name, res.len() == 0), res.len(), preset.weaponsSlotCount))
        }

    // Check tiers count and remove excess tiers
    if (res.len() > preset.weaponsSlotCount)
      do {
        unAllocatedTiers.append(res.remove(0), res.pop())
      }
      while (res.len() > preset.weaponsSlotCount)

    // Add empty tiers if it's needed and allocate them symmetric
    let emptyTiers = []
    for (local i = res.len(); i < preset.weaponsSlotCount; i++)
      emptyTiers.append({ tierId = -1 })
    res.extend(getIndexedTiers(emptyTiers, res.len(), preset.weaponsSlotCount))

    // Add unallocated tiers on free places from central tier if it's free
    foreach (_idx, tier in res)
      if (!tier?.img  && unAllocatedTiers.len())
        foreach (prop, value in unAllocatedTiers.pop())
          if (prop != "tierId")
            tier[prop] <- value
  }
  res.sort(@(a, b) a.tierId  <=> b.tierId)

  return res
}

function getFavoritePresets(unitName) {
  let savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  return loadLocalAccountSettings(savePath, DataBlock()) % "presetId"
}

function setFavoritePresets(unitName, favoriteArr = []) {
  let savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  let data = DataBlock()
  foreach (inst in favoriteArr)
    data.addStr("presetId", inst)
  saveLocalAccountSettings(savePath, data)
}

let sortPresetsList = @(a, b)
  a.chapterOrd <=> b.chapterOrd
  || a.customIdx <=> b.customIdx
  || b.isEnabled <=> a.isEnabled
  || b.isDefault <=> a.isDefault
  || b.totalMass <=> a.totalMass

function updateUnitWeaponsByPreset(unit) {  //!!! FIX ME: why is this here and why modify weapons get from wpcost
  if (!unit)
    return

  let unitBlk = ::get_full_unit_blk(unit.name)
  if (!unitBlk)
    return

  foreach (wp in getUnitPresets(unitBlk))
    if (wp?.weaponConfig.presetType != null) {
      let weapon = unit.getWeapons().findvalue(@(inst) inst.name == wp.name)
      if (weapon != null)
        weapon.presetType <- wp.weaponConfig.presetType
    }
}

function getReqRankByMod(reqMod, modifications) {
  local res = 1
  if (!reqMod)
    return res
  foreach (modName in reqMod) {
    let mod = modifications.findvalue(@(m) m.name == modName)
    if (mod != null)
      res = max(mod.tier, res)
  }
  return res
}

function updateTiersActivity(tiers, weapons, weaponsSlotCount) {
  for (local i = 0; i < weaponsSlotCount; i++)
    tiers[i].__update({
      isActive = weapons.findvalue(@(w) w.tier == i) != null
    })
}

function getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons = null) {
  let modifications = unit.modifications
  let pType = preset?.presetType ?? getTypeByPurpose(weaponry)
  let isFavorite = favoriteArr.contains(preset.name)
  let isCustom = isCustomPreset(preset)
  let chapterOrd = isFavorite ? CHAPTER_FAVORITE_IDX
    : isCustom ? CHAPTER_NEW_IDX
    : CHAPTER_ORDER.findindex(@(p) p == pType)


  let presetView = {
    name              = preset.name
    type              = preset.type
    cost              = preset.cost
    image             = preset.image
    totalItemsAmount  = 0
    totalMass         = 0
    purposeType       = pType
    chapterOrd        = chapterOrd
    isDefault         = preset.name.indexof("default") != null
    isEnabled         = preset?.isEnabled
      ?? (isWeaponEnabled(unit, preset) || (isUnitUsable(unit) && isWeaponUnlocked(unit, preset)))
    rank              = getReqRankByMod(preset?.reqModification, modifications)
    customIdx         = isCustom ? cutPrefix(preset.name, CUSTOM_PRESET_PREFIX, -1).tointeger() : -1
    customNameText    = preset?.customNameText
    tiers             = {}
    dependentWeaponPreset = {}
    bannedWeaponPreset = {}
    tiersView         = {}
    weaponPreset      = u.copy(preset)
    weaponsByTypes    = {}
    weaponsSlotCount  = ::get_full_unit_blk(unit.name)?.WeaponSlots?.weaponsSlotCount ?? MIN_TIERS_COUNT
  }

  presetView.weaponPreset.hasSweepRange <- weaponry.hasSweepRange

  foreach (triggers in (weaponry?.weaponsByTypes ?? {}))
    foreach (t in triggers) {
      let tType = t.trigger
      presetView.weaponsByTypes[tType] <- presetView?.weaponsByTypes[tType] ?? {}
      presetView.weaponsByTypes[tType].weaponBlocks <- presetView.weaponsByTypes[tType]?.weaponBlocks ?? {}
      let w = presetView.weaponsByTypes[tType].weaponBlocks
      foreach (weaponName, weapon in t.weaponBlocks) {
        w[weaponName] <- (weapon.__merge({ name = weaponName, purposeType = presetView.purposeType }))
        presetView.totalItemsAmount += weapon.ammo / (weapon.amountPerTier ?? 1)
        presetView.totalMass += weapon.ammo * weapon.massKg
        presetView.tiers.__update(weapon.tiers)
        foreach (dependentWeaponName, dependentWeapons in weapon.dependentWeaponPreset) {
          let curDependentWeapons = presetView.dependentWeaponPreset?[dependentWeaponName] ?? []
          presetView.dependentWeaponPreset[dependentWeaponName] <- curDependentWeapons.extend(dependentWeapons)
        }
        foreach (bannedWeaponName, bannedWeapons in weapon.bannedWeaponPreset) {
          let curBannedWeapons = presetView.bannedWeaponPreset?[bannedWeaponName] ?? []
          presetView.bannedWeaponPreset[bannedWeaponName] <- curBannedWeapons.extend(bannedWeapons)
        }
      }
    }

  presetView.tiersView = getTiers(unit, presetView)
  if (isCustom && unit.hasWeaponSlots && availableWeapons != null)
    updateTiersActivity(presetView.tiersView, availableWeapons, presetView.weaponsSlotCount)

  if ((preset?.presetType != null) && !CHAPTER_ORDER.contains(preset.presetType))
    CHAPTER_ORDER.append(preset.presetType) // Needs add custom preset type in order array to get right chapter order

  return presetView
}

function getCustomWeaponryPresetView(unit, curPreset, favoriteArr, availableWeapons) {
  let presetBlk = convertPresetToBlk(curPreset)
  let preset =  getCustomPresetByPresetBlk(unit, curPreset.name, presetBlk)
  let weaponry = addWeaponsFromBlk({}, getWeaponsByTypes(::get_full_unit_blk(unit.name), presetBlk), unit)
  return getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons)
}

function getWeaponryPresetView(unit, preset, favoriteArr, availableWeapons) {
  let weaponry = getUnitWeaponry(unit, { isPrimary = false, weaponPreset = preset.name })
  return getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons)
}

function getWeaponryByPresetInfo(unit, chooseMenuList = null) {
  updateUnitWeaponsByPreset(unit)
  let fullUnitBlk = ::get_full_unit_blk(unit.name)
  let res = {
    weaponsSlotCount = fullUnitBlk?.WeaponSlots.weaponsSlotCount ?? MIN_TIERS_COUNT
    presets = []
    favoriteArr = getFavoritePresets(unit.name)
    availableWeapons = unit.hasWeaponSlots ? getSlotsWeaponsForEditPreset(fullUnitBlk) : null
  }
  let presetsList = getPresetsList(unit, chooseMenuList)

  let presets = ("weapon_presets" in fullUnitBlk) ? fullUnitBlk.weapon_presets % "preset"
    : []
  foreach (preset in presetsList) {
    let showInWeaponMenu = ::is_debug_mode_enabled || (presets.findvalue(@(p) p.name == preset.name)?.showInWeaponMenu ?? true)
    if(showInWeaponMenu)
      res.presets.append(getWeaponryPresetView(unit, preset, res.favoriteArr, res.availableWeapons))
  }

  res.presets.sort(sortPresetsList)
  return res
}

function editSlotInPresetImpl(preset, slots, cb) {
  foreach (slot in slots)
    if ("presetId" not in slot) {
      if (slot.tierId in preset.tiers)
        preset.tiers.$rawdelete(slot.tierId)
    }
    else
      preset.tiers[slot.tierId] <- { slot = slot.slot, presetId = slot.presetId }
  cb()
}

let findAvailableWeapon = @(availableWeapons, presetId, tierId)
  availableWeapons.findvalue(@(w) w.presetId == presetId && w.tier == tierId)

function getAvailableWeaponName(availableWeapons, presetId, tierId, weaponBlkCache = {}) {
  let wBlk = findAvailableWeapon(availableWeapons, presetId, tierId)
  if (wBlk == null)
    return presetId
  return getWeaponNameByBlkPath(getWeaponBlkParams(wBlk.blk, weaponBlkCache).weaponBlkPath)
}

function addDependedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams) {
  foreach (slot in (wBlk % "dependentWeaponPreset")) {
    let dependWBlk = availableWeapons.findvalue(@(w) w.presetId == slot.preset && w.slot == slot.slot)
    if (dependWBlk == null)
      continue

    let dependWeaponTier = dependWBlk.tier
    editSlotParams.slots.append({ slot = dependWBlk.slot, presetId = dependWBlk.presetId, tierId = dependWeaponTier })
    if (preset.tiers?[dependWeaponTier] == null || preset.tiers[dependWeaponTier].presetId == dependWBlk.presetId)
      continue

    let dependWeaponName = getAvailableWeaponName(availableWeapons, dependWBlk.presetId,
      dependWeaponTier, editSlotParams.weaponBlkCache)
    let curWeaponName = getAvailableWeaponName(availableWeapons, preset.tiers[dependWeaponTier].presetId,
      dependWeaponTier, editSlotParams.weaponBlkCache)
    let currentWeapon = loc($"weapons/{curWeaponName}")
    editSlotParams.msgTextArray.append(loc("editWeaponsSlot/requiredDependedWeaponInOccupiedSlot", {
      currentWeapon
      dependWeapon = loc($"weapons/{dependWeaponName}")
    }))
    appendOnce(currentWeapon, editSlotParams.removedWeapon)
    editSlotParams.removedWeaponCount++
  }
}

function addBannedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams) {
  let weaponsToRemove = []
  foreach (slot in (wBlk % "bannedWeaponPreset")) {
    let bannedWBlk = availableWeapons.findvalue(@(w) w.presetId == slot.preset && w.slot == slot.slot)
    if (bannedWBlk == null)
      continue

    let bannedWeaponTier = bannedWBlk.tier
    if (preset.tiers?[bannedWeaponTier].presetId != bannedWBlk.presetId)
      continue

    editSlotParams.slots.append({ tierId = bannedWeaponTier })
    let bannedWeaponName = getAvailableWeaponName(availableWeapons, bannedWBlk.presetId,
      bannedWeaponTier, editSlotParams.weaponBlkCache)
    let bannedWeapon = loc($"weapons/{bannedWeaponName}")
    appendOnce(bannedWeapon, editSlotParams.removedWeapon)
    weaponsToRemove.append({ bannedWeapon, tierNum = bannedWeaponTier + 1 })
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(loc("editWeaponsSlot/bannedWeapons", {
    bannedWeapons = loc("ui/comma").join(weaponsToRemove.map(@(w) w.bannedWeapon))
  }))
}

function addBanedByWeaponsParams(preset, tierId, presetId, availableWeapons, wBlk, editSlotParams) {
  if (presetId not in preset.bannedWeaponPreset)
    return

  let weapons = preset.bannedWeaponPreset[presetId].filter(@(w) w.slot == wBlk.slot) ?? []
  let weaponsToRemove = []
  foreach (weapon in weapons) {
    editSlotParams.slots.append({ tierId = weapon.bannedByTier })
    let weaponName = getAvailableWeaponName(availableWeapons, weapon.bannedByPresetId,
      weapon.bannedByTier, editSlotParams.weaponBlkCache)
    let weaponLocName = loc($"weapons/{weaponName}")
      appendOnce(weaponLocName, editSlotParams.removedWeapon)
    weaponsToRemove.append({ weaponLocName, tierNum = weapon.bannedByTier + 1 })
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(loc("editWeaponsSlot/bannedByWeapons", {
    currentWeapon = loc($"weapons/{getAvailableWeaponName(availableWeapons, presetId, tierId, editSlotParams.weaponBlkCache)}")
    weapons = loc("ui/comma").join(weaponsToRemove.map(@(w) w.weaponLocName))
  }))
}

function addRemovedDependetWeaponsParams(preset, tierId, availableWeapons, editSlotParams) {
  let curPresetInTier = preset.tiers?[tierId]
  if (curPresetInTier == null)
    return

  let { presetId, slot } = curPresetInTier
  if (presetId not in preset.dependentWeaponPreset)
    return

  let dependentWeapons = preset.dependentWeaponPreset[presetId].filter(@(w) w.slot == slot) ?? []
  let weaponsToRemove = []
  foreach (dependentWeapon in dependentWeapons) {
    if(editSlotParams.slots.filter(@(v) v.tierId == dependentWeapon.reqForTier).len() == 0)
      editSlotParams.slots.append({ tierId = dependentWeapon.reqForTier })
    let dependWeaponName = getAvailableWeaponName(availableWeapons, dependentWeapon.reqForPresetId,
      dependentWeapon.reqForTier, editSlotParams.weaponBlkCache)
    let dependWeapon = loc($"weapons/{dependWeaponName}")
    appendOnce(dependWeapon, editSlotParams.removedWeapon)
    weaponsToRemove.append({ dependWeapon, tierNum = dependentWeapon.reqForTier + 1 })
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(loc("editWeaponsSlot/requiredForDependedWeapon", {
    currentWeapon = loc($"weapons/{getAvailableWeaponName(availableWeapons, presetId, tierId, editSlotParams.weaponBlkCache)}")
    dependWeapons = loc("ui/comma").join(weaponsToRemove.map(@(w) w.dependWeapon))
  }))
}

function createPresetAfter(preset, unit, favoriteArr, availableWeapons, editSlotParams) {
  local res = deep_clone(preset)
  foreach (slot in editSlotParams.slots) {
    if ("presetId" not in slot) {
      if (slot.tierId in res.tiers)
        res.tiers.$rawdelete(slot.tierId)
    }
    else
      res.tiers[slot.tierId] <- { slot = slot.slot, presetId = slot.presetId }
  }
  res = getCustomWeaponryPresetView(unit, res, favoriteArr, availableWeapons)
  return { presetBefore = deep_clone(preset), presetAfter = res }
}

function editSlotInPreset(preset, tierId, presetId, availableWeapons, unit, favoriteArr, cb, isForced = false) {
  let editSlotParams = {
    slots = []
    msgTextArray = []
    removedWeapon = []
    weaponBlkCache = {}
    removedWeaponCount = 0
  }
  if (presetId == "")
    editSlotParams.slots.append({ tierId })
  else {
    let wBlk = findAvailableWeapon(availableWeapons, presetId, tierId)
    if (wBlk != null) {
      editSlotParams.slots.append({ slot = wBlk.slot, presetId = wBlk.presetId, tierId })
      addDependedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams)
      addBannedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams)
      addBanedByWeaponsParams(preset, tierId, presetId, availableWeapons, wBlk, editSlotParams)
    }
  }
  addRemovedDependetWeaponsParams(preset, tierId, availableWeapons, editSlotParams)

  let { msgTextArray, slots, removedWeapon, removedWeaponCount } = editSlotParams
  if (msgTextArray.len() == 0) {
    editSlotInPresetImpl(preset, slots, cb)
    return
  }

  msgTextArray.append(loc("editWeaponsSlot/removedDependedWeapons", {
    weapons = loc("ui/comma").join(removedWeapon)
    weaponsCount = removedWeaponCount
  }))

  openRestrictionsWeaponryPreset({ presets = createPresetAfter(preset, unit, favoriteArr, availableWeapons, editSlotParams),
    messageText = "\n".join(msgTextArray), ok_fn = @() editSlotInPresetImpl(preset, slots, cb), isForced })
}

function overloadMsg(locKey, weight, maxWeight) {
  let overload = weight - maxWeight
  if (overload <= 0)
    return ""

  let kgMeasure = getMeasureTypeByName("kg", true)
  return loc(locKey, {
    overload = kgMeasure.getMeasureUnitsText(fabs(overload)),
    weight = kgMeasure.getMeasureUnitsText(fabs(weight)),
    maxWeight = kgMeasure.getMeasureUnitsText(maxWeight)
  })
}

function getPresetWeightRestrictionText(preset, unitBlk) {
  let { maxDisbalance = -1, maxloadMass = -1,
      maxloadMassLeftConsoles = -1, maxloadMassRightConsoles = -1 } = unitBlk?.WeaponSlots

  if (maxDisbalance < 0 && maxloadMass < 0 && maxloadMassLeftConsoles < 0
      && maxloadMassRightConsoles < 0)
    return ""

  let notUseforDisbalance = {}

  foreach (slot in getUnitWeaponSlots(unitBlk))
    if (slot?.notUseforDisbalanceCalculation ?? false)
      notUseforDisbalance[slot?.tier ?? slot.index] <- true

  let result = []

  local leftMass = 0
  local rightMass = 0
  local centerMass = 0

  let centerIdx = preset.weaponsSlotCount / 2

  foreach (idx, tier in preset.tiersView) {
    let { tierId = -1, massKg = 0.0 } = tier?.weaponry
    let { additionalMassKg = 0.0 } = tier?.weaponry.tiers[idx]
    let amount = tier?.weaponry.tiers[tierId].amountPerTier ?? 1.0
    let tierMass = massKg * amount + additionalMassKg
    if (notUseforDisbalance?[idx] ?? false)
      centerMass += tierMass
    else if (idx < centerIdx)
      leftMass += tierMass
    else
      rightMass += tierMass
  }

  let disbalance = fabs(leftMass - rightMass)
  if (disbalance > maxDisbalance) {
    let kgMeasure = getMeasureTypeByName("kg", true)
    result.append(loc("weapons/pylonsWeightDisbalance", {
      side = loc($"side/{leftMass > rightMass ? "left" : "right"}")
      disbalance = kgMeasure.getMeasureUnitsText(disbalance)
      maxDisbalance = kgMeasure.getMeasureUnitsText(maxDisbalance)
      })
    )
  }

  let summaryWeight = leftMass + rightMass +  centerMass
  result.append(
    overloadMsg("weapons/pylonsWeightSummaryOverload", summaryWeight, maxloadMass)
    overloadMsg("weapons/pylonsWeightLeftOverload", leftMass, maxloadMassLeftConsoles)
    overloadMsg("weapons/pylonsWeightRightOverload", rightMass, maxloadMassRightConsoles)
  )

  return "\n".join(result, true)
}

return {
  getWeaponryByPresetInfo
  setFavoritePresets
  sortPresetsList
  getTierTooltipParams
  getCustomWeaponryPresetView
  getWeaponryPresetView
  editSlotInPreset
  getPresetWeightRestrictionText
  getTierIcon
  findAvailableWeapon
}