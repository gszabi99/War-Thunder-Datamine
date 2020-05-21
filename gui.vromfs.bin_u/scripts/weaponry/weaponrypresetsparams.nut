local { _clone } = require("std/deep.nut")
local { BULLET_TYPE } = require("scripts/weaponry/bulletsInfo.nut")
local { TRIGGER_TYPE,
        getPresetsList,
        getUnitWeaponry } = require("scripts/weaponry/weaponryInfo.nut")

local TIERS_NUMBER = 13
local SIZE = {
  small   = "small"
  middle  = "middle"
  large   = "large"
  special = "special"
}

local PURPOSE_TYPE_ORDER = ["NONE", "UNIVERSAL", "AIR_TO_AIR", "AIR_TO_GROUND", "AIR_TO_SEA", "ARMORED"]
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

local function getWeaponryByPresetInfo(unit, chooseMenuList = null)
{
  // Get list clone to avoid adding properties such as isEnabled, isDefault, chapterOrd in presets
  local res = {weaponrySizes = {}, presets = [],
    presetsList = _clone(getPresetsList(unit, chooseMenuList))}
  local presets = res.presets
  local presetsList = res.presetsList
  local sizes = res.weaponrySizes
  local isOwn = ::isUnitUsable(unit)

  foreach(idx, preset in presetsList)
  {
    local weaponry = getUnitWeaponry(unit, {isPrimary = false, weaponPreset = preset.name})
    local pType = preset?.presetType ?? getTypeByPurpose(weaponry)
    if(preset?.presetType && !::isInArray(preset.presetType, PURPOSE_TYPE_ORDER))
      PURPOSE_TYPE_ORDER.append(preset.presetType) // Needs add custom preset type in order array to get right chapter order
    if (preset?.isEnabled == null)
      preset.isEnabled <- ::is_weapon_enabled(unit, preset) ||
        (isOwn && ::is_weapon_unlocked(unit, preset))
    preset.isDefault <- preset.name.indexof("default") != null
    preset.chapterOrd <- PURPOSE_TYPE_ORDER.findindex(@(p) p == pType)
    presets.append({
        id = preset.name
        cost = preset.cost
        image = preset.image
        totalItemsAmount = 0
        purposeType = pType
        chapterOrd = preset.chapterOrd
        isDefault = preset.isDefault
        isEnabled = preset.isEnabled
      })
    local p = presets[idx]
    foreach (weaponType, triggers in weaponry)
      foreach (t in triggers)
      {
        if (!p?[t.trigger])
          p[t.trigger] <- []
        local w = p[t.trigger]
        foreach (weaponName, weapon in t)
          if (typeof(weapon) == "table")
          {
            w.append({
              name = weaponName
              num = weapon.num
              ammo = weapon.ammo
              massKg = weapon.massKg
              caliber = weapon.caliber
              iconType = weapon.iconType
              amountPerTier = weapon.amountPerTier
              bulletType = weapon.bulletType
              tiers = weapon.tiers
            })

            p.totalItemsAmount += weapon.num / (weapon.amountPerTier ?? 1)

            if (!sizes?[t.trigger])
              sizes[t.trigger] <- []
            local s = sizes[t.trigger]
            if(!::isInArray(weapon.massKg, s))
              s.append(weapon.massKg)
          }
        w.sort(@(a, b) b.massKg <=> a.massKg)
      }
  }

  foreach (inst in sizes)
    inst.sort(@(a, b) a <=> b)

  presets.sort(@(a, b)
    a.chapterOrd <=> b.chapterOrd
    || b.isEnabled <=> a.isEnabled
    || b.isDefault <=> a.isDefault)

  presetsList.sort(@(a, b)
    a.chapterOrd <=> b.chapterOrd
    || b.isEnabled <=> a.isEnabled
    || b.isDefault <=> a.isDefault)

  return res
}

local function getTierIcon(weaponry, size, itemsNum, isBlock)
{
  local path = "#ui/gameuiskin#"
  local triggerType = weaponry.tType
  local iconType = weaponry.iconType
  local isGroup = itemsNum > 1
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

  local wStr = isBlock && triggerType == TRIGGER_TYPE.ROCKETS ? "nar" : triggerType
  local groupStr = isBlock || isGroup ? $"{size}_group" : size

  return $"{path}{wStr}_{groupStr}"
}

local function createTier(weaponry, sizes, itemsNum = 0)
{
  local size = getWeaponrySize(sizes[weaponry.tType], weaponry.massKg)
  local isBlock = weaponry?.isBlock ?? false
  itemsNum = itemsNum > 0 ? itemsNum : weaponry.num
  local res = {
    tierId  = weaponry?.tierId ?? -1
    triggerType = weaponry.tType
    itemsNum = itemsNum
    size = size
    img = getTierIcon(weaponry, size, itemsNum, isBlock)
  }
  if (isBlock)
    res.isBlock <- isBlock

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
      isBlock = true
      num = count
      ammo = amountPerTier
    }))
  if (rest > 0)
    res.append(weaponry.__merge({
      num = rest
      ammo = 1
    }))

  return res
}

local function getWeaponryDistribution(weaponry, sizes, totalItemsAmount, isCentral = false)
{
  local isEvenCount = weaponry.num % 2 == 0
  local isAllocateByGroup = totalItemsAmount > TIERS_NUMBER
  // Group weapons when numbers of free tiers less then weapon items amount
  if (isAllocateByGroup)
  {
    if (!isCentral && isEvenCount)
    {
      local tier = createTier(weaponry, sizes, weaponry.num / 2)
      return [tier, clone tier]
    }
    else
      return [createTier(weaponry, sizes)]
  }
  // Place one weapon item per one tier when tiers amount is enough
  local res = []
  for (local i = 0; i < weaponry.num; i++)
  {
    // Set empty tier in center when count is EVEN
    if (isCentral && isEvenCount && i == weaponry.num / 2)
      res.append({tierId = -1})
    res.append(createTier(weaponry, sizes, 1))
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
            local params = {
              tierId = idx
              tType = triggerType
              isBlock = (tier?.amountPerTier ?? amountPerTier) > 1
              iconType  = tier?.iconType ?? iconType
            }
            if (filledTiers?[idx])
            {
              // Create additional tiers info and add it on already existing tier if two weapons placed per one tier
              local currTier = ::u.search(res, @(p) p.tierId == idx)
              if (currTier)
                currTier.addWTier <- createTier(weaponry.__merge(params),
                  sizes, weaponry.num / (tier?.amountPerTier ?? amountPerTier))
              continue
            }
            else
              filledTiers[idx] <- weaponry

            res.append(createTier(weaponry.__merge(params),
              sizes, weaponry.num / (tier?.amountPerTier ?? amountPerTier)))
          }
        }
        else
          return []
  return res
}

local function getTiers(unit, preset, sizes)
{
  local res = getPredefinedTiers(preset, sizes)
  unAllocatedTiers = []

  if (!res.len())
    for (local i = 0; i < GROUP_ORDER.len(); i++)
      foreach (triggerType in GROUP_ORDER[i])
        if (preset?[triggerType])
        {
          local group = getWeaponryGroup(preset, GROUP_ORDER[i])
          for (local j = 0; j < group.len(); j++)
            res.extend(getIndexedTiers(getWeaponryDistribution(group[j], sizes,
              preset.totalItemsAmount, res.len() == 0), res.len()))
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
  res.sort(@(a, b) b.tierId  <=> a.tierId)

  return res
}

return {
  TIERS_NUMBER            = TIERS_NUMBER
  getTiers                = getTiers
  getWeaponryByPresetInfo = getWeaponryByPresetInfo
}