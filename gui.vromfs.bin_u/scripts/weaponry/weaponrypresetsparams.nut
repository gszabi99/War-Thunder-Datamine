local { PURPOSE_TYPE, TRIGGER_TYPE, getUnitWeaponry } = require("scripts/weaponry/weaponryInfo.nut")

local TIERS_NUMBER = 13
local SIZE = {
  small   = "small"
  middle  = "middle"
  large   = "large"
  special = "special"
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

local function getTypeByPurpose(tag)
{
  foreach (pTypeName, pType in PURPOSE_TYPE)
    if (::isInArray(tag, pType))
      return pTypeName

  return "UNIVERSAL"
}

local function getWeaponryByPresetInfo(unit, presetsList)
{
  local res = {weaponrySizes = {}, presets = []}
  local presets = res.presets
  local sizes = res.weaponrySizes
  foreach(idx, preset in presetsList)
  {
    local weaponry = getUnitWeaponry(unit, {isPrimary = false, weaponPreset = preset.name})
    presets.append({
        id = preset.name
        cost = preset.cost
        image = preset.image
        totalItemsAmount = 0
        presetPurposeType = preset.presetPurposeType
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
              purposeType = getTypeByPurpose(t.trigger)
              num = weapon.num
              ammo = weapon.ammo
              massKg = weapon.massKg
              caliber = weapon.caliber
              iconType = weapon?.iconType
              amountPerTier = weapon?.amountPerTier
            })

            p.totalItemsAmount += weapon.num / (weapon?.amountPerTier ?? 1)

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

  return res
}

local function getTierIcon(weaponry, size, itemsNum, isBlock)
{
  local path = "#ui/gameuiskin#"
  local triggerType = weaponry.tType
  local iconType = weaponry?.iconType
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
    tierId  = -1
    triggerType = weaponry.tType
    itemsNum = itemsNum
    size = size
    img = getTierIcon(weaponry, size, itemsNum, isBlock)
  }
  if (isBlock)
    res.isBlock <- isBlock

  return res
}

local function getBlocks(weaponry, isCentral)
{
  local amountPerTier = weaponry?.amountPerTier
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

// It returns:
//  - array of even length if !isCentral
//  - array that contains one element if isCentral
local function getWeaponryDistribution(weaponry, sizes, totalItemsAmount, isCentral = false)
{
  local isEvenCount = weaponry.num % 2 == 0
  local isAllocateByGroup = totalItemsAmount > TIERS_NUMBER
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
//    looked like one whole and being an one new entity) such as "rockets_block" or "cannon_block".
//    It maight be forexample MRL, Multiple-barrel firearm etc.
//  - group of weapom blocks such as "rockets_block_group"
local function getWeaponryGroup(preset, groupOrder, isCentral)
{
  local res = []
  foreach (triggerType in groupOrder)
    if (preset?[triggerType])
      foreach (w in preset[triggerType])
        res.extend(getBlocks(w.__merge({tType = triggerType}), isCentral))
  // Needs additional sort by ammo to define "heaviest" block among identical mass blocks
  return res.sort(@(a, b) b.massKg <=> a.massKg || b.ammo <=> a.ammo)
}

// It set indexes to tiers place symmetric from center to edges
local function getIndexedTiers(tiers, tiersCount)
{
  local isEvenCount = tiers.len() % 2 == 0
  local middleTierIdx = ::ceil(TIERS_NUMBER/2.0).tointeger() - 1
  if (tiersCount == 0) // CENTRAL part of tiers
  {
    local delta = ::ceil(tiers.len()/2.0).tointeger() - 1
    for (local i = 0; i < tiers.len(); i++)
      tiers[i].tierId = middleTierIdx - (delta - i)
  }
  else if (isEvenCount) // SIDE part of tiers
  {
    local lim = tiers.len() / 2
    local delta = ::ceil(tiersCount/2.0).tointeger()
    for (local i = 0; i < lim; i++)
    {
      tiers[i].tierId = middleTierIdx + delta + i
      tiers[i+lim].tierId = middleTierIdx - delta - i
    }
  }
  else // if SIDE tier has odd number of weapons (!isEvenCount)
  {
    unAllocatedTiers.extend(tiers)
    tiers = []
  }

  return tiers
}

local function getTiers(unit, preset, sizes)
{
  local res = []
  unAllocatedTiers = []

  for (local i = 0; i < GROUP_ORDER.len(); i++)
    foreach (triggerType in GROUP_ORDER[i])
      if (preset?[triggerType])
      {
        local group = getWeaponryGroup(preset, GROUP_ORDER[i], res.len() == 0)
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

  // Add unallocated tiers on free places
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