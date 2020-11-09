local { _clone } = require("std/deep.nut")
local { BULLET_TYPE } = require("scripts/weaponry/bulletsInfo.nut")
local { TRIGGER_TYPE,
        getPresetsList,
        getUnitWeaponry,
        isWeaponEnabled,
        isWeaponUnlocked } = require("scripts/weaponry/weaponryInfo.nut")

const WEAPON_PRESET_FAVORITE = "weaponPreset/favorite/"

local TIERS_NUMBER = 13
local SIZE = {
  small   = "small"
  middle  = "middle"
  large   = "large"
  special = "special"
}

local CHAPTER_ORDER = ["NONE", "FAVORITE", "UNIVERSAL", "AIR_TO_AIR", "AIR_TO_GROUND", "AIR_TO_SEA", "ARMORED"]
local CHAPTER_FAVORITE_IDX = CHAPTER_ORDER.findindex(@(p) p == "FAVORITE")
local PURPOSE_TYPE = {
  AIR_TO_AIR = [BULLET_TYPE.AAM, BULLET_TYPE.ROCKET_AIR]
  AIR_TO_SEA = [BULLET_TYPE.TORPEDO]
  ARMORED    = [BULLET_TYPE.ATGM_TANK]
}

local GROUP_ORDER = [
  [TRIGGER_TYPE.BOMBS, TRIGGER_TYPE.TORPEDOES],
  [TRIGGER_TYPE.ROCKETS],
  [TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON, TRIGGER_TYPE.ADD_GUN, TRIGGER_TYPE.TURRETS,
    TRIGGER_TYPE.SMOKE, TRIGGER_TYPE.FLARES],
  [TRIGGER_TYPE.AGM, TRIGGER_TYPE.ATGM],
  [TRIGGER_TYPE.AAM]
]

local unAllocatedTiers = []

local function getWeaponrySize(sizes, massKg)
{
  if(!sizes.len())
    return ""

  local idx = ::min(sizes.findindex(@(c) c == massKg), 3)  // all equal or bigger then 3 is "special"
  local size = SIZE.middle
  switch(::min(sizes.len(), 4))
  {
    case 2:
      size = [SIZE.middle, SIZE.large][idx]
    break
    case 3:
      size = [SIZE.small, SIZE.middle, SIZE.large][idx]
    break
    case 4:
      size = [SIZE.small, SIZE.middle, SIZE.large, SIZE.special][idx]
    break
  }
  return size
}

local function getTypeByPurpose(weaponry)
{
  if (::u.isEmpty(weaponry))
    return "NONE"

  local res =[]
  foreach (triggerType in weaponry)
    foreach (inst in triggerType)
      foreach (w in inst)
        if (typeof(w) == "table")
        {
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

local function getTierIcon(weaponry, size, itemsNum)
{
  local path = "#ui/gameuiskin#"
  local triggerType = weaponry.tType
  local iconType = weaponry.iconType
  local isGroup = itemsNum > 1
  local isBlock = (weaponry?.amountPerTier ?? 0) > 1
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

  local wStr = isBlock && triggerType == TRIGGER_TYPE.ROCKETS ? "nar" : triggerType
  local groupStr = isBlock || isGroup ? $"{size}_group" : size

  return $"{path}{wStr}_{groupStr}"
}

local function createTier(weaponry, sizes, presetName, itemsNum = 0)
{
  local tierId  = weaponry?.tierId ?? -1
  local tierWeaponry = weaponry.__merge({ itemsNum = itemsNum })
  local size = getWeaponrySize(sizes[weaponry.tType], weaponry.massKg)
  itemsNum = itemsNum > 0 ? itemsNum : weaponry.num
  local res = {
    tierId  = tierId
    weaponry = tierWeaponry
    img = getTierIcon(weaponry, size, itemsNum)
    tierTooltipId = ::g_tooltip_type.TIER.getTooltipId(unit.name, tierWeaponry, presetName, tierId)
  }

  return res
}

local function getBlocks(weaponry)
{
  local amountPerTier = weaponry.amountPerTier
  if (amountPerTier == null)
    return [weaponry]

  local count = weaponry.num / amountPerTier
  local rest = weaponry.num % amountPerTier
  local res = []
  if (count > 0)
    res.append(weaponry.__merge({
      num = count
      amountPerTier = amountPerTier
    }))
  if (rest > 0)
    res.append(weaponry.__merge({ num = rest }))

  return res
}

local function getWeaponryDistribution(weaponry, sizes, preset, isCentral = false)
{
  local isEvenCount = weaponry.num % 2 == 0
  local isAllocateByGroup = preset.totalItemsAmount > TIERS_NUMBER
  // Group weapons when numbers of free tiers less then weapon items amount
  if (isAllocateByGroup)
  {
    if (!isCentral && isEvenCount)
    {
      local tier = createTier(weaponry, sizes, preset.id, weaponry.num / 2)
      return [tier, clone tier]
    }
    else
      return [createTier(weaponry, sizes, preset.id)]
  }
  // Place one weapon item per one tier when tiers amount is enough
  local res = []
  for (local i = 0; i < weaponry.num; i++)
  {
    // Set empty tier in center when count is EVEN
    if (isCentral && isEvenCount && i == weaponry.num / 2)
      res.append({tierId = -1})
    res.append(createTier(weaponry, sizes, preset.id, 1))
  }

  return res
}

// Needs to keep in mind a few kinds of entities:
//  - simply weapon such as "bombs", "rockets" etc
//  - group of weapons (a few instances of the same type weapon placed into one tier) such as "bombs_group"
//  - weapon block (a few instances of the same type weapon united in functional block,
//    looked like one whole and being an one new entity) such as "rockets_block".
local function getWeaponryGroup(preset, groupOrder)
{
  local res = []
  foreach (triggerType in groupOrder)
    if (preset?[triggerType])
      foreach (w in preset[triggerType])
        res.extend(getBlocks(w.__merge({tType = triggerType})))
  // Needs additional sort by ammo to define "heaviest" block among identical mass blocks
  return res.sort(@(a, b) b.massKg <=> a.massKg || b.ammo <=> a.ammo)
}

// It set indexes to tiers place symmetric from center to edges
local function getIndexedTiers(tiers, tiersCount)
{
  local middleTierIdx = ::ceil(TIERS_NUMBER/2.0).tointeger() - 1
  if (tiersCount == 0) // CENTRAL part of tiers
  {
    local delta = ::ceil(tiers.len()/2.0).tointeger() - 1
    for (local i = 0; i < tiers.len(); i++)
      tiers[i].tierId = middleTierIdx - (delta - i)
  }
  else // SIDE part of tiers
  {
    local isEvenCount = tiers.len() % 2 == 0
    if (!isEvenCount) // if SIDE tier has odd number of weapons
      unAllocatedTiers.append(tiers.pop())
    local lim = tiers.len() / 2
    local delta = ::ceil(tiersCount/2.0).tointeger()
    for (local i = 0; i < lim; i++)
    {
      tiers[i].tierId = middleTierIdx + delta + i
      tiers[i+lim].tierId = middleTierIdx - delta - i
    }
  }

  return tiers
}

local function getPredefinedTiers(preset, sizes)
{
  local res = []
  local filledTiers = {}
  foreach (triggerType in TRIGGER_TYPE)
    if (preset?[triggerType] != null)
      foreach (weaponry in preset[triggerType])
        if (weaponry?.tiers && !::u.isEmpty(weaponry.tiers)) // Tiers config takes effect only when all weapons in preset have tiers
        {
          local amountPerTier = weaponry.amountPerTier ?? 1
          local iconType = weaponry.iconType
          foreach (idx, tier in weaponry.tiers)
          {
            local tierId = ::min(idx, TIERS_NUMBER-1) // To avoid possible mistakes from config with incorrect tier idx
            local params = {
              tierId = tierId
              tType = triggerType
              isBlock = (tier?.amountPerTier ?? amountPerTier) > 1
              iconType  = tier?.iconType ?? iconType
            }
            if (filledTiers?[tierId])
            {
              // Create additional tiers info and add it on already existing tier if two weapons placed per one tier
              local currTier = ::u.search(res, @(p) p.tierId == tierId)
              if (currTier)
              {
                currTier.weaponry.addWeaponry <- weaponry.__merge(params.__merge({
                  itemsNum = weaponry.num / (tier?.amountPerTier ?? amountPerTier)}))
                currTier.tierTooltipId = ::g_tooltip_type.TIER.getTooltipId(unit.name,
                  currTier.weaponry, preset.id, idx)
              }

              continue
            }
            else
              filledTiers[tierId] <- weaponry

            res.append(createTier(weaponry.__merge(params),
              sizes, preset.id, weaponry.num / (tier?.amountPerTier ?? amountPerTier)))
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

local function getTiers(unit, preset, sizes)
{
  local res = getPredefinedTiers(preset, sizes)
  unAllocatedTiers = []

  if (!res.len())
  {
    for (local i = 0; i < GROUP_ORDER.len(); i++)
      foreach (triggerType in GROUP_ORDER[i])
        if (preset?[triggerType])
        {
          local group = getWeaponryGroup(preset, GROUP_ORDER[i])
          for (local j = 0; j < group.len(); j++)
            res.extend(getIndexedTiers(getWeaponryDistribution(group[j], sizes,
              preset, res.len() == 0), res.len()))
        }

    // Сheck tiers count and remove excess tiers
    if (res.len() > TIERS_NUMBER)
      do {
        unAllocatedTiers.append(res.remove(0), res.pop())
      }
      while (res.len() > TIERS_NUMBER)

    // Add empty tiers if it's needed and allocate them symmetric
    local emptyTiers = []
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

local function getFavoritePresets(unitName) {
  local savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  return ::load_local_account_settings(savePath, ::DataBlock()) % "presetId"
}

local function setFavoritePresets(unitName, favoriteArr=[]) {
  local savePath = $"{WEAPON_PRESET_FAVORITE}{unitName}"
  local data = ::DataBlock()
  foreach (inst in favoriteArr)
    data.addStr("presetId", inst)
  ::save_local_account_settings(savePath, data)
}

local function sortPresetLists(listArr) {
  foreach (list in listArr)
    list.sort(@(a, b)
      a.chapterOrd <=> b.chapterOrd
      || b.isEnabled <=> a.isEnabled
      || b.isDefault <=> a.isDefault
      || b.totalMass <=> a.totalMass)
}

local function getWeaponryByPresetInfo(unit, chooseMenuList = null)
{
  // Get list clone to avoid adding properties such as isEnabled, isDefault, chapterOrd in presets
  local res = {weaponrySizes = {}, presets = [],
    presetsList = _clone(getPresetsList(unit, chooseMenuList)),
    favoriteArr = getFavoritePresets(unit.name)}
  local presets = res.presets
  local presetsList = res.presetsList
  local sizes = res.weaponrySizes
  local isOwn = ::isUnitUsable(unit)

  foreach(idx, preset in presetsList)
  {
    local weaponry = getUnitWeaponry(unit, {isPrimary = false, weaponPreset = preset.name})
    local pType = preset?.presetType ?? getTypeByPurpose(weaponry)
    local isFavorite = ::isInArray(preset.name, res.favoriteArr)
    if(preset?.presetType && !::isInArray(preset.presetType, CHAPTER_ORDER))
      CHAPTER_ORDER.append(preset.presetType) // Needs add custom preset type in order array to get right chapter order
    if (preset?.isEnabled == null)
      preset.isEnabled <- isWeaponEnabled(unit, preset) ||
        (isOwn && isWeaponUnlocked(unit, preset))
    preset.isDefault <- preset.name.indexof("default") != null
    preset.chapterOrd <- isFavorite
      ? CHAPTER_FAVORITE_IDX : CHAPTER_ORDER.findindex(@(p) p == pType)
    presets.append({
        id               = preset.name
        cost             = preset.cost
        image            = preset.image
        totalItemsAmount = 0
        totalMass        = 0
        purposeType      = pType
        chapterOrd       = preset.chapterOrd
        isDefault        = preset.isDefault
        isEnabled        = preset.isEnabled
      })
    local p = presets[idx]
    foreach (weaponType, triggers in weaponry)
      foreach (t in triggers)
      {
        local tType = weaponType == TRIGGER_TYPE.TURRETS ? weaponType : t.trigger
        if (!p?[tType])
          p[tType] <- []
        local w = p[tType]
        foreach (weaponName, weapon in t)
          if (typeof(weapon) == "table")
          {
            w.append(weapon.__update(
              {
                name = weaponName
                purposeType = pType
              }))

            p.totalItemsAmount += weapon.num / (weapon.amountPerTier ?? 1)
            p.totalMass += weapon.num * weapon.massKg

            if (!sizes?[tType])
              sizes[tType] <- []
            local s = sizes[tType]
            if(!::isInArray(weapon.massKg, s))
              s.append(weapon.massKg)
          }
        w.sort(@(a, b) b.massKg <=> a.massKg)
      }

    preset.totalMass <- p.totalMass
  }

  foreach (inst in sizes)
    inst.sort(@(a, b) a <=> b)
  sortPresetLists([presets, presetsList])
  foreach (idx, preset in presets)
    presetsList[idx].tiers <- getTiers(unit, preset, sizes)

  return res
}

return {
  TIERS_NUMBER            = TIERS_NUMBER
  CHAPTER_ORDER           = CHAPTER_ORDER
  CHAPTER_FAVORITE_IDX    = CHAPTER_FAVORITE_IDX
  getWeaponryByPresetInfo = getWeaponryByPresetInfo
  setFavoritePresets      = setFavoritePresets
  sortPresetLists         = sortPresetLists
}