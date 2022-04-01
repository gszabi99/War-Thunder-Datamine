let { deep_clone } = require("%sqstd/underscore.nut")
let { BULLET_TYPE } = require("%scripts/weaponry/bulletsInfo.nut")
let { TRIGGER_TYPE, addWeaponsFromBlk, getPresetsList, getUnitWeaponry,
  isWeaponEnabled, isWeaponUnlocked } = require("%scripts/weaponry/weaponryInfo.nut")
let { WEAPON_PRESET_TIER } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getTierTooltipParams } = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { TIERS_NUMBER, CHAPTER_ORDER, CHAPTER_FAVORITE_IDX, CHAPTER_NEW_IDX, getUnitWeapons,
  getUnitPresets, isCustomPreset, getWeaponsByTypes, updateTiersActivity
} = require("%scripts/weaponry/weaponryPresets.nut")
let DataBlock = require("DataBlock")

const WEAPON_PRESET_FAVORITE = "weaponPreset/favorite/"

local PURPOSE_TYPE = {
  AIR_TO_AIR = [BULLET_TYPE.AAM, BULLET_TYPE.ROCKET_AIR]
  AIR_TO_SEA = [BULLET_TYPE.TORPEDO]
  ARMORED    = [BULLET_TYPE.ATGM_TANK]
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

let function getWeaponrySize(massKg)
{
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

let function getTypeByPurpose(weaponry)
{
  if (::u.isEmpty(weaponry))
    return "NONE"

  let res =[]
  foreach (triggerType in weaponry)
    foreach (inst in triggerType)
      foreach (w in inst.weaponBlocks) {
        // Lack of bullet types or all types that is not in PURPOSE_TYPE is AIR_TO_GROUND type
        local isFound = false
        if (w.bulletType != null)
          foreach (pTypeName, pType in PURPOSE_TYPE)
          {
            foreach (tag in pType)
            {
              if (w.bulletType == tag)
              {
                if (!::isInArray(pTypeName, res))
                  res.append(pTypeName)
                isFound = true
                break
              }
            }
            if (isFound)
              break
          }
        if (!isFound && !::isInArray("AIR_TO_GROUND", res))
          res.append("AIR_TO_GROUND")
      }

  return res.len() == 1 ? res[0] : ::isInArray("AIR_TO_AIR", res) ?
    "UNIVERSAL" : ::isInArray("AIR_TO_SEA", res) ? "AIR_TO_SEA" : "AIR_TO_GROUND"
}

let function getTierIcon(weaponry, itemsNum)
{
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

  if (::isInArray(triggerType,
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

local function createTier(weaponry, presetName, itemsNum = 0)
{
  let tierId  = weaponry?.tierId ?? -1
  let tierWeaponry = weaponry.__merge({ itemsNum = itemsNum })
  itemsNum = itemsNum > 0 ? itemsNum : weaponry.num
  return {
    tierId  = tierId
    weaponry = tierWeaponry
    img = getTierIcon(weaponry, itemsNum)
    tierTooltipId = WEAPON_PRESET_TIER.getTooltipId(unit.name,
      getTierTooltipParams(tierWeaponry, presetName, tierId))
  }
}

let function getBlocks(weaponry)
{
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

let function getWeaponryDistribution(weaponry, preset, isCentral = false)
{
  let isEvenCount = weaponry.num % 2 == 0
  let isAllocateByGroup = preset.totalItemsAmount > TIERS_NUMBER
  // Group weapons when numbers of free tiers less then weapon items amount
  if (isAllocateByGroup)
  {
    if (!isCentral && isEvenCount)
    {
      let tier = createTier(weaponry, preset.id, weaponry.num / 2)
      return [tier, clone tier]
    }
    else
      return [createTier(weaponry, preset.id)]
  }
  // Place one weapon item per one tier when tiers amount is enough
  let res = []
  for (local i = 0; i < weaponry.num; i++)
  {
    // Set empty tier in center when count is EVEN
    if (isCentral && isEvenCount && i == weaponry.num / 2)
      res.append({tierId = -1})
    res.append(createTier(weaponry, preset.id, 1))
  }

  return res
}

// Needs to keep in mind a few kinds of entities:
//  - simply weapon such as "bombs", "rockets" etc
//  - group of weapons (a few instances of the same type weapon placed into one tier) such as "bombs_group"
//  - weapon block (a few instances of the same type weapon united in functional block,
//    looked like one whole and being an one new entity) such as "rockets_block".
let function getWeaponryGroup(preset, groupOrder)
{
  let res = []
  foreach (triggerType in groupOrder)
    if (preset?[triggerType])
      foreach (w in preset[triggerType].weaponBlocks)
        res.extend(getBlocks(w.__merge({tType = triggerType})))
  // Needs additional sort by ammo to define "heaviest" block among identical mass blocks
  return res.sort(@(a, b) b.massKg <=> a.massKg || b.ammo <=> a.ammo)
}

// It set indexes to tiers place symmetric from center to edges
let function getIndexedTiers(tiers, tiersCount)
{
  let middleTierIdx = ::ceil(TIERS_NUMBER/2.0).tointeger() - 1
  if (tiersCount == 0) // CENTRAL part of tiers
  {
    let delta = ::ceil(tiers.len()/2.0).tointeger() - 1
    for (local i = 0; i < tiers.len(); i++)
      tiers[i].tierId = middleTierIdx - (delta - i)
  }
  else // SIDE part of tiers
  {
    let isEvenCount = tiers.len() % 2 == 0
    if (!isEvenCount) // if SIDE tier has odd number of weapons
      unAllocatedTiers.append(tiers.pop())
    let lim = tiers.len() / 2
    let delta = ::ceil(tiersCount/2.0).tointeger()
    for (local i = 0; i < lim; i++)
    {
      tiers[i].tierId = middleTierIdx + delta + i
      tiers[i+lim].tierId = middleTierIdx - delta - i
    }
  }

  return tiers
}

let function getPredefinedTiers(preset)
{
  let res = []
  let filledTiers = {}
  foreach (triggerType in TRIGGER_TYPE)
    if (preset?[triggerType] != null)
      foreach (weaponry in preset[triggerType].weaponBlocks)
        if (weaponry?.tiers && !::u.isEmpty(weaponry.tiers)) // Tiers config takes effect only when all weapons in preset have tiers
        {
          let amountPerTier = weaponry.amountPerTier ?? 1
          let iconType = weaponry.iconType
          foreach (idx, tier in weaponry.tiers)
          {
            let tierId = ::min(idx, TIERS_NUMBER-1) // To avoid possible mistakes from config with incorrect tier idx
            let params = {
              tierId = tierId
              tType = triggerType
              isBlock = (tier?.amountPerTier ?? amountPerTier) > 1
              iconType  = tier?.iconType ?? iconType
              tooltipLang = tier?.tooltipLang
            }
            if (filledTiers?[tierId])
            {
              // Create additional tiers info and add it on already existing tier if two weapons placed per one tier
              let currTier = ::u.search(res, @(p) p.tierId == tierId)
              if (currTier)
              {
                currTier.weaponry.addWeaponry <- weaponry.__merge(params.__merge({
                  itemsNum = weaponry.num / (tier?.amountPerTier ?? amountPerTier)}))
                currTier.tierTooltipId = WEAPON_PRESET_TIER.getTooltipId(unit.name,
                  getTierTooltipParams(currTier.weaponry, preset.id, tierId))
              }

              continue
            }
            else
              filledTiers[tierId] <- weaponry

            res.append(createTier(weaponry.__merge(params),
              preset.id, weaponry.num / (tier?.amountPerTier ?? amountPerTier)))
          }
        }
        else
          return []

  if (res.len()) // Add empty tiers in set if predefined tiers exist
    for (local i = res.len(); i < TIERS_NUMBER; i++)
      for (local j = 0; j < TIERS_NUMBER; j++)
        if (filledTiers?[j] == null)
        {
          res.append({tierId = j})
          filledTiers[j] <- {}
        }

  return res
}

let function getTiers(unit, preset)
{
  let res = getPredefinedTiers(preset)
  unAllocatedTiers = []

  if (!res.len())
  {
    for (local i = 0; i < GROUP_ORDER.len(); i++)
      foreach (triggerType in GROUP_ORDER[i])
        if (preset?[triggerType])
        {
          let group = getWeaponryGroup(preset, GROUP_ORDER[i])
          for (local j = 0; j < group.len(); j++)
            res.extend(getIndexedTiers(getWeaponryDistribution(group[j],
              preset, res.len() == 0), res.len()))
        }

    // Check tiers count and remove excess tiers
    if (res.len() > TIERS_NUMBER)
      do {
        unAllocatedTiers.append(res.remove(0), res.pop())
      }
      while (res.len() > TIERS_NUMBER)

    // Add empty tiers if it's needed and allocate them symmetric
    let emptyTiers = []
    for (local i = res.len(); i < TIERS_NUMBER; i++)
      emptyTiers.append({tierId = -1})
    res.extend(getIndexedTiers(emptyTiers, res.len()))

    // Add unallocated tiers on free places from central tier if it's free
    foreach (idx, tier in res)
      if (!tier?.img  && unAllocatedTiers.len())
        foreach (prop, value in unAllocatedTiers.pop())
          if (prop != "tierId")
            tier[prop] <- value
  }
  res.sort(@(a, b) a.tierId  <=> b.tierId)

  return res
}

let function getFavoritePresets(unitName) {
  let savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  return ::load_local_account_settings(savePath, ::DataBlock()) % "presetId"
}

let function setFavoritePresets(unitName, favoriteArr=[]) {
  let savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  let data = ::DataBlock()
  foreach (inst in favoriteArr)
    data.addStr("presetId", inst)
  ::save_local_account_settings(savePath, data)
}

let function sortPresetLists(listArr) {
  foreach (list in listArr)
    list.sort(@(a, b)
      a.chapterOrd <=> b.chapterOrd
      || b.isEnabled <=> a.isEnabled
      || b.isDefault <=> a.isDefault
      || b.totalMass <=> a.totalMass)
}

let function updateUnitWeaponsByPreset(unit) {  //!!! FIX ME: why is this here and why modify weapons get from wpcost
  if (!unit)
    return

  let unitBlk = ::get_full_unit_blk(unit.name)
  if( !unitBlk )
    return

  foreach (wp in getUnitPresets(unitBlk))
    if (wp?.weaponConfig.presetType != null) {
      let weapon = unit.getWeapons().findvalue(@(inst) inst.name == wp.name)
      if (weapon != null)
        weapon.presetType <- wp.weaponConfig.presetType
    }
}

let function getReqRankByMod(reqMod, modifications) {
  local res = 1
  if (!reqMod)
    return res
  foreach(mod in reqMod)
    if (modifications?[mod] && modifications[mod].tier > res)
      res = modifications[mod].tier
  return res
}

let function getTierWeaponsParams(weapons, tierId) {
  let res = []
  foreach (triggerType in TRIGGER_TYPE)
    foreach (weapon in (weapons?[triggerType] ?? []))
      foreach(id, inst in weapon.weaponBlocks) {
        inst.id <- id
        inst.tType <- triggerType
        res.append({
          id = inst.tiers?[tierId].presetId ?? id
          name = ::loc($"weapons/{id}")
          img = getTierIcon(inst, inst.num)
        })
      }
  return res
}

let function convertPresetToBlk(preset) {
  let presetBlk = DataBlock()
  presetBlk["name"] = preset.customNameText ?? ""
  foreach (tier in preset.tiers) {
    let weaponBlk = presetBlk.addNewBlock("Weapon")
    weaponBlk["preset"] = tier.presetId
    weaponBlk["slot"] = tier.slot
  }
  return presetBlk
}

let function getPresetView(unit, preset, weaponry, pType) {
  let modifications = unit.modifications
  let res = {
    id                = preset.name
    cost              = preset.cost
    image             = preset.image
    totalItemsAmount  = 0
    totalMass         = 0
    purposeType       = pType
    chapterOrd        = preset.chapterOrd
    isDefault         = preset.isDefault
    isEnabled         = preset.isEnabled
    rank              = getReqRankByMod(preset?.reqModification, modifications)
    customNameText    = preset?.customNameText
    tiers             = {}
  }
  foreach (weaponType, triggers in weaponry)
    foreach (t in triggers) {
      let tType = weaponType == TRIGGER_TYPE.TURRETS ? weaponType : t.trigger
      res[tType] <- res?[tType] ?? {}
      res[tType].weaponBlocks <- res[tType]?.weaponBlocks ?? {}
      let w = res[tType].weaponBlocks
      foreach (weaponName, weapon in t.weaponBlocks) {
        w[weaponName] <- (weapon.__merge({name = weaponName, purposeType = res.purposeType}))
        res.totalItemsAmount += weapon.num / (weapon.amountPerTier ?? 1)
        res.totalMass += weapon.num * weapon.massKg
        res.tiers.__update(weapon.tiers)
      }
    }

  return res
}

let function prepareWeaponsPresetForView(unit, preset, weaponry, favoriteArr, availableWeapons = null) {
  let isOwn = ::isUnitUsable(unit)
  let pType = preset?.presetType ?? getTypeByPurpose(weaponry)
  let isFavorite = ::isInArray(preset.name, favoriteArr)
  if(preset?.presetType && !::isInArray(preset.presetType, CHAPTER_ORDER))
    CHAPTER_ORDER.append(preset.presetType) // Needs add custom preset type in order array to get right chapter order
  if (preset?.isEnabled == null)
    preset.isEnabled <- isWeaponEnabled(unit, preset) || (isOwn && isWeaponUnlocked(unit, preset))
  preset.isDefault <- preset.name.indexof("default") != null
  let isCustom = isCustomPreset(preset)
  preset.chapterOrd <- isFavorite ? CHAPTER_FAVORITE_IDX
    : isCustom ? CHAPTER_NEW_IDX
    : CHAPTER_ORDER.findindex(@(p) p == pType)
  let presetView = getPresetView(unit, preset, weaponry, pType)
  preset.totalMass <- presetView.totalMass
  preset.tiers <- getTiers(unit, presetView)
  if (isCustom && unit.hasWeaponSlots && availableWeapons != null)
    updateTiersActivity(preset.tiers, availableWeapons)
  return presetView
}

let getCustomPresetWeaponry = @(weaponsBlk, unit) addWeaponsFromBlk({},
  getWeaponsByTypes(::get_full_unit_blk(unit.name), weaponsBlk), unit)

let function getWeaponryByPresetInfo(unit, chooseMenuList = null)
{
  updateUnitWeaponsByPreset(unit)
  let res = {presets = [],
    presetsList = deep_clone(getPresetsList(unit, chooseMenuList)),
    favoriteArr = getFavoritePresets(unit.name)}
  let presets = res.presets
  let presetsList = res.presetsList
  let availableWeapons = unit.hasWeaponSlots ? getUnitWeapons(::get_full_unit_blk(unit.name)) : null

  foreach(preset in presetsList) {
    let weaponry = getUnitWeaponry(unit, {isPrimary = false, weaponPreset = preset.name})
    presets.append(prepareWeaponsPresetForView(unit, preset, weaponry, res.favoriteArr, availableWeapons))
  }

  sortPresetLists([presets, presetsList])
  return res
}

return {
  getWeaponryByPresetInfo
  setFavoritePresets
  sortPresetLists
  getTierTooltipParams
  getTierWeaponsParams
  convertPresetToBlk
  prepareWeaponsPresetForView
  getCustomPresetWeaponry
}