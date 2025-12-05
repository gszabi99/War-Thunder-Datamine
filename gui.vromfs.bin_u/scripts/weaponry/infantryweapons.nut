from "%scripts/dagui_library.nut" import *

let {  addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { blkFromPath, convertBlk } = require("%sqstd/datablock.nut")
let { weaponsItem } = require("%scripts/weaponry/weaponryConsts.nut")
let { getWeaponryCustomPresets } = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { isCustomPreset, CUSTOM_PRESET_PREFIX, getUnitPresets, INF_MAX_SOLDIERS_COUNT,
  INF_ADD_SOLDIERS_COUNT, getUnitWeaponSlots
} = require("%scripts/weaponry/weaponryPresets.nut")
let { cutPrefix } = require("%sqstd/string.nut")
let { deep_clone } = require("%sqstd/underscore.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { getTemplateCompValue } = require("%globalScripts/templates.nut")
let { skillParametersRequestType } = require("%scripts/crew/skillParametersRequestType.nut")
let { getCrewByAir } = require("%scripts/crew/crewInfo.nut")
let { get_difficulty_by_ediff } = require("%scripts/difficulty.nut")
let { getUnitTemplateNames } = require("%scripts/weaponry/infantryTemplates.nut")

let isEqualWeapon = @(a, b) a.name == b.name

const INF_SOLDIERS_BASE_COUNT_PARAM = "unit_crew__count"

let soldiersMinMaxValues = {
  min = {}
  addMax = {}
}
let weaponsForInfantryUnitCache = {}
let presetsForInfantryUnitCache = {}
let infantryWeaponsSlotIdx = {
  special = 2
  nonUniqe = 4
}

function createEmptyWeaponSlot(slot) {
  return {
    slot
    name = "infantry_empty"
    type = weaponsItem.infantryWeapon
  }
}

function getSoldiersWeaponsListForPreset(preset) {
  let res = {
    specialWeaponsBySoldier = {}
    nonUniqeBysoldier = {}
  }
  foreach (soldier in preset.soldiers) {
    res.specialWeaponsBySoldier[soldier.index] <- ""
    res.nonUniqeBysoldier[soldier.index] <- ""
    foreach (weapon in soldier.weapons) {
      if (weapon.slot == infantryWeaponsSlotIdx.special)
        res.specialWeaponsBySoldier[soldier.index] <- weapon.name
      if (weapon.slot == infantryWeaponsSlotIdx.nonUniqe)
        res.nonUniqeBysoldier[soldier.index] <- weapon.name
    }
  }
  return res
}

let getHumanWeaponIcons = @() GUI.get()?.human_additional_weapon_icons

function getWeaponsForInfantryUnit(unit) {
  if (weaponsForInfantryUnitCache?[unit.name])
    return weaponsForInfantryUnitCache[unit.name]

  let res = {
    specialWeapons = []
    nonUniqe = []
  }
  let weaponSlots = getUnitWeaponSlots(getFullUnitBlk(unit.name))
  if (!weaponSlots)
    return res

  let weaponIcons = getHumanWeaponIcons()

  foreach (slot in weaponSlots) {
    let slotWeapons = []
    foreach (preset in (slot % "WeaponPreset")) {
      let presetWeapon = convertBlk(preset)
      presetWeapon.slot <- slot.index
      presetWeapon.type <- weaponsItem.infantryWeapon
      presetWeapon.amount <- presetWeapon?.inventoryItemNum ?? 1
      if (presetWeapon?.reqModification && type(presetWeapon.reqModification) != "array")
        presetWeapon.reqModification <- [presetWeapon.reqModification]
      let presetName = presetWeapon?.name ?? ""
      if (presetName != "")
        presetWeapon.image <- weaponIcons?[presetName] ?? ""
      let idx = slotWeapons.findindex(@(w) isEqualWeapon(w, presetWeapon))
      if (idx == null)
        slotWeapons.append(presetWeapon)
    }
    if (slot.index == infantryWeaponsSlotIdx.special)
      res.specialWeapons.extend(slotWeapons)
    if (slot.index == infantryWeaponsSlotIdx.nonUniqe)
      res.nonUniqe.extend(slotWeapons)
  }

  weaponsForInfantryUnitCache[unit.name] <- res
  return res
}

function convertInfantryBlkPresetToData(presetBlk, name) {
  let presetItem = {
    name
    soldiers = []
  }
  foreach (soldier in presetBlk % "soldier"){
    let weapons = []
    foreach (w in soldier % "weapon") {
      weapons.append({ name = w.preset, slot = w.slot })
    }
    presetItem.soldiers.append({
      index = soldier.index
      weapons
    })
  }

  return presetItem
}

function getPresetSpecialWeapons(preset, maxSoldiersCount) {
  let res = {}
  if (!preset)
    return res

  foreach (soldier in preset.soldiers) {
    if (soldier.index >= maxSoldiersCount)
      return res
    foreach (w in soldier.weapons) {
      if (w.slot == infantryWeaponsSlotIdx.special && w.name != "infantry_empty")
        res[w.name] <- soldier.index
    }
  }
  return res
}

function getSoldiersAdditionalMaxCount(unit, difficulty) {
  if (soldiersMinMaxValues.addMax?[unit.name][difficulty.crewSkillName])
    return soldiersMinMaxValues.addMax[unit.name][difficulty.crewSkillName]
  if (!soldiersMinMaxValues.addMax?[unit.name])
    soldiersMinMaxValues.addMax[unit.name] <- {}

  let addMaxCount = skillParametersRequestType.MAX_VALUES.getParameters(-1, unit)[difficulty.crewSkillName]?.groundService
    .squadAdditionalSoldierCount.max_skill_level ?? INF_ADD_SOLDIERS_COUNT
  soldiersMinMaxValues.addMax[unit.name][difficulty.crewSkillName] <- addMaxCount

  return soldiersMinMaxValues.addMax[unit.name][difficulty.crewSkillName]
}


function getSoldiersAdditionalByPercentCount(count, crewSkillsPercent) {
  if (crewSkillsPercent == 100)
    return count
  return (crewSkillsPercent * count.tofloat() / 100).tointeger()
}

function getSoldiersAdditionalCurrentCount(unit, difficulty) {
  local addCurrCount = 0
  let crewId = getCrewByAir(unit)?.id ?? -1
  if (crewId == -1) {
    addCurrCount = INF_ADD_SOLDIERS_COUNT
    return addCurrCount
  }

  addCurrCount = skillParametersRequestType.CURRENT_VALUES.getParameters(crewId, unit)[difficulty.crewSkillName]?.groundService
    .squadAdditionalSoldierCount.squadAdditionalSoldierCount ?? 0
  return addCurrCount
}

function getSoldiersMinCount(unit) {
  if (soldiersMinMaxValues.min?[unit.name])
    return soldiersMinMaxValues.min[unit.name]

  let { mainTemplateName } = getUnitTemplateNames(unit)
  local res = INF_MAX_SOLDIERS_COUNT
  if (mainTemplateName != "") {
    let minCountFromTemplate = getTemplateCompValue(mainTemplateName, INF_SOLDIERS_BASE_COUNT_PARAM)
    if (minCountFromTemplate != null)
      res = minCountFromTemplate + 1 
  }
  soldiersMinMaxValues.min[unit.name] <- res
  return res
}

function getSoldiersMinMaxCount(unit, difficulty) {
  let minCount = getSoldiersMinCount(unit)
  let maxCount = min((minCount + getSoldiersAdditionalMaxCount(unit, difficulty)), INF_MAX_SOLDIERS_COUNT)

  return { minCount, maxCount }
}

function getSoldiersCount(unit, curEdiff, crewSkillsPercent = null) {
  let difficulty = get_difficulty_by_ediff(curEdiff)
  let { minCount, maxCount } = getSoldiersMinMaxCount(unit, difficulty)
  let leftToMaxCount = INF_MAX_SOLDIERS_COUNT - minCount
  let addCurrCount = min(
    crewSkillsPercent != null ? getSoldiersAdditionalByPercentCount(maxCount - minCount, crewSkillsPercent)
      : getSoldiersAdditionalCurrentCount(unit, difficulty)
    leftToMaxCount
  )
  let res = {
    minCount
    maxCount
    addCurrCount
  }
  return res
}

function initInfantryPresetsCompositionForUnit(unit) {
  let res = {}
  presetsForInfantryUnitCache[unit.name] <- res

  let fullUnitBlk = getFullUnitBlk(unit.name)

  let presetsFromBlk = getUnitPresets(fullUnitBlk)
  foreach (preset in presetsFromBlk) {
    let presetBlk = blkFromPath(preset.blk)
    if (!presetBlk)
      continue
    let presetItem = convertInfantryBlkPresetToData(presetBlk, preset.name)
    res[presetItem.name] <- presetItem
  }

  let customPresetsConfig = getWeaponryCustomPresets(unit)
  foreach (customPresetBlk in customPresetsConfig) {
    if (!customPresetBlk?.weaponsBlk)
      continue
    let customPresetItem = convertInfantryBlkPresetToData(customPresetBlk.weaponsBlk, customPresetBlk["name"])
    res[customPresetItem.name] <- customPresetItem
  }
}

function getPresetCompositionByName(unit, presetName) {
  if (!unit?.isHuman())
    return null
  if (!presetsForInfantryUnitCache?[unit.name])
    initInfantryPresetsCompositionForUnit(unit)

  return presetsForInfantryUnitCache[unit.name]?[presetName]
}

function updateCustomInfantryPresetsCache(unit, newPreset) {
  presetsForInfantryUnitCache[unit.name][newPreset.name] <- newPreset
}

function createCustomInfantryPreset(unit, preset) {
  let customPreset = deep_clone(preset)

  let idx = getWeaponryCustomPresets(unit).filter(isCustomPreset).reduce(
    @(res, value) max(res, cutPrefix(value.name, CUSTOM_PRESET_PREFIX).tointeger() + 1), 0)
  customPreset.name <- $"{CUSTOM_PRESET_PREFIX}{idx}"
  return customPreset
}

function makeEmptyPresetComposition() {
  let emptyPreset = {
    soldiers = array(INF_MAX_SOLDIERS_COUNT).map(@(_, soldierIdx) {
      index = soldierIdx
      weapons = infantryWeaponsSlotIdx.values().map(@(slot) createEmptyWeaponSlot(slot))
    })
  }
  return emptyPreset
}

function createEmptyInfantryPreset(unit) {
  return createCustomInfantryPreset(unit, makeEmptyPresetComposition())
}

function getPresetCompositionViewParams(unit, item, ediff) {
  
  
  let res = {
    compositionIcons = []
    deleteButtonCanShow = false
  }

  let { minCount, maxCount, addCurrCount } = getSoldiersCount(unit, ediff)
  let availableSoldiersCount = minCount + addCurrCount

  let preset = getPresetCompositionByName(unit, item.name)
    ?? convertInfantryBlkPresetToData(item?.weaponsBlk, item.name)
  if (!preset)
    return res

  res.deleteButtonCanShow = isCustomPreset(preset)

  let weaponIcons = getHumanWeaponIcons()

  foreach (solIdx, soldier in preset.soldiers) {
    if (solIdx >= maxCount)
      break
    let iconsForSoldier = { icons = [], disabledSoldier = solIdx >= availableSoldiersCount }
    foreach (wIdx, weapon in soldier.weapons) {
      let icon = {
        weaponName = weapon.name
        itemImg = weaponIcons?[weapon.name] ?? ""
        hasMargin = wIdx == 0
      }
      iconsForSoldier.icons.append(icon)
    }
    res.compositionIcons.append(iconsForSoldier)
  }
  return res
}

function isEmptyPresetAlreadyExist(unit) {
  let currentPresets = presetsForInfantryUnitCache?[unit.name]
  if ((currentPresets?.len() ?? 0) == 0)
    return false
  foreach (preset in currentPresets) {
    if (!isCustomPreset(preset))
      continue

    let presetHasWeapons = preset.soldiers.findvalue(function(s) {
      let soldierHasWeapon = s.weapons.findvalue(@(w) w.name != "infantry_empty") != null
      return soldierHasWeapon
    }) != null
    if (!presetHasWeapons)
      return true
  }
  return false
}



function getWeaponDataByWeaponInfo(unit, weaponInfo) {
  let weapons = getWeaponsForInfantryUnit(unit)
  local res = null
  foreach (weaponType in weapons) {
    foreach (weaponData in weaponType)
      if (weaponData.name == weaponInfo.name && weaponData.slot == weaponInfo.slot) {
        res = weaponData
        return res
      }
  }
  return res
}

addListenersWithoutEnv({
  function CustomPresetChanged(params) {
    let { unitName, presetId } = params
    let unit = getAircraftByName(unitName)
    if (!unit?.isHuman())
      return
    let newPresetBlk = getWeaponryCustomPresets(unit).findvalue(@(p) p?.name == presetId)
    if (!newPresetBlk)
      return
    let newPreset = convertInfantryBlkPresetToData(newPresetBlk.weaponsBlk, presetId)
    updateCustomInfantryPresetsCache(unit, newPreset)
  }

  function CustomPresetRemoved(params) {
    let { unitName, presetId } = params
    let unit = getAircraftByName(unitName)
    if (!unit?.isHuman())
      return
    presetsForInfantryUnitCache?[unit.name].rawdelete(presetId)
  }
})

return {
  getWeaponsForInfantryUnit
  infantryWeaponsSlotIdx
  createEmptyWeaponSlot
  getPresetCompositionByName
  getSoldiersWeaponsListForPreset
  createCustomInfantryPreset
  getPresetCompositionViewParams
  isEmptyPresetAlreadyExist
  createEmptyInfantryPreset
  getPresetSpecialWeapons
  getSoldiersCount
  getWeaponDataByWeaponInfo
  getHumanWeaponIcons
}
