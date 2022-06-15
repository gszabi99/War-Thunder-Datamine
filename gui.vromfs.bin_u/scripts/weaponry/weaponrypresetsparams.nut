let { BULLET_TYPE } = require("%scripts/weaponry/bulletsInfo.nut")
let { TRIGGER_TYPE, addWeaponsFromBlk, getPresetsList, getUnitWeaponry,
  isWeaponEnabled, isWeaponUnlocked, getWeaponBlkParams, getWeaponNameByBlkPath,
  WEAPON_TYPE } = require("%scripts/weaponry/weaponryInfo.nut")
let { WEAPON_PRESET_TIER } = require("%scripts/weaponry/weaponryTooltips.nut")
let { getTierTooltipParams } = require("%scripts/weaponry/weaponryTooltipPkg.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { TIERS_NUMBER, CHAPTER_ORDER, CHAPTER_FAVORITE_IDX, CHAPTER_NEW_IDX, CUSTOM_PRESET_PREFIX,
  getUnitWeapons, getUnitPresets, isCustomPreset, getWeaponsByTypes
} = require("%scripts/weaponry/weaponryPresets.nut")
let { getCustomPresetByPresetBlk, convertPresetToBlk
} = require("%scripts/unit/unitWeaponryCustomPresets.nut")
let { abs } = require("%sqstd/math.nut")
let { appendOnce } = require("%sqStdLibs/helpers/u.nut")
let { cutPrefix } = require("%sqstd/string.nut")

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
    return $"{path}{iconType}.png"

  if (triggerType == TRIGGER_TYPE.TORPEDOES)
    return $"{path}air_torpedo.png"

  if (triggerType == TRIGGER_TYPE.ATGM)
    return $"{path}atgm_type2_x2.png"

  if (::isInArray(triggerType,
    [TRIGGER_TYPE.MACHINE_GUN, TRIGGER_TYPE.CANNON, TRIGGER_TYPE.ADD_GUN]))
      return isBlock || isGroup ? $"{path}multibarrel_gun.png" : $"{path}machine_gun.png"

  if (triggerType == TRIGGER_TYPE.AGM)
    return $"{path}missile_air_to_earth.png"

  if (triggerType == TRIGGER_TYPE.AAM)
    return isBlock || isGroup ? $"{path}missile_air_to_air_group.png" : $"{path}missile_air_to_air.png"

  if (triggerType == TRIGGER_TYPE.FLARES)
    return $"{path}ltc.png"

  let size = getWeaponrySize(weaponry.massKg)
  let wStr = isBlock && triggerType == TRIGGER_TYPE.ROCKETS ? "nar" : triggerType
  let groupStr = isBlock || isGroup ? $"{size}_group" : size

  return $"{path}{wStr}_{groupStr}.png"
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
      let tier = createTier(weaponry, preset.name, weaponry.num / 2)
      return [tier, clone tier]
    }
    else
      return [createTier(weaponry, preset.name)]
  }
  // Place one weapon item per one tier when tiers amount is enough
  let res = []
  for (local i = 0; i < weaponry.num; i++)
  {
    // Set empty tier in center when count is EVEN
    if (isCentral && isEvenCount && i == weaponry.num / 2)
      res.append({tierId = -1})
    res.append(createTier(weaponry, preset.name, 1))
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
            let tierId = min(idx, TIERS_NUMBER-1) // To avoid possible mistakes from config with incorrect tier idx
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
                  getTierTooltipParams(currTier.weaponry, preset.name, tierId))
              }

              continue
            }
            else
              filledTiers[tierId] <- weaponry

            res.append(createTier(weaponry.__merge(params),
              preset.name, weaponry.num / (tier?.amountPerTier ?? amountPerTier)))
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

let sortPresetsList = @(a, b)
  a.chapterOrd <=> b.chapterOrd
  || a.customIdx <=> b.customIdx
  || b.isEnabled <=> a.isEnabled
  || b.isDefault <=> a.isDefault
  || b.totalMass <=> a.totalMass

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
  foreach(modName in reqMod) {
    let mod = modifications.findvalue(@(m) m.name == modName)
    if (mod != null)
      res = max(mod.tier, res)
  }
  return res
}

let function getTierWeaponsParams(weapons, tierId) {
  let res = []
  foreach (triggerType in WEAPON_TYPE)
    foreach (weapon in (weapons?[triggerType] ?? []))
      foreach(id, inst in weapon.weaponBlocks) {
        let tierWeaponConfig = inst.__merge({
          tType = triggerType
          iconType = inst.tiers?[tierId].iconType ?? inst.iconType
        })
        res.append({
          id = inst.tiers?[tierId].presetId ?? id
          name = "".concat(::loc($"weapons/{id}"), ::loc("ui/parentheses/space",
            {text = $"{::loc("shop/ammo")}{::loc("ui/colon")}{inst.ammo}"}))
          img = getTierIcon(tierWeaponConfig, inst.ammo)
        })
      }
  return res
}

let function updateTiersActivity(tiers, weapons) {
  for (local i = 0; i < TIERS_NUMBER; i++)
    tiers[i].__update({
      isActive = weapons.findvalue(@(w) w.tier == i) != null
    })
}

let function getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons = null) {
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
      ?? (isWeaponEnabled(unit, preset) || (::isUnitUsable(unit) && isWeaponUnlocked(unit, preset)))
    rank              = getReqRankByMod(preset?.reqModification, modifications)
    customIdx         = isCustom ? cutPrefix(preset.name, CUSTOM_PRESET_PREFIX, -1).tointeger() : -1
    customNameText    = preset?.customNameText
    tiers             = {}
    dependentWeaponPreset = {}
    bannedWeaponPreset = {}
    tiersView         = {}
    weaponPreset      = ::u.copy(preset)
  }
  foreach (weaponType, triggers in weaponry)
    foreach (t in triggers) {
      let tType = weaponType == TRIGGER_TYPE.TURRETS ? weaponType : t.trigger
      presetView[tType] <- presetView?[tType] ?? {}
      presetView[tType].weaponBlocks <- presetView[tType]?.weaponBlocks ?? {}
      let w = presetView[tType].weaponBlocks
      foreach (weaponName, weapon in t.weaponBlocks) {
        w[weaponName] <- (weapon.__merge({name = weaponName, purposeType = presetView.purposeType}))
        presetView.totalItemsAmount += weapon.num / (weapon.amountPerTier ?? 1)
        presetView.totalMass += weapon.num * weapon.massKg
        presetView.tiers.__update(weapon.tiers)
        presetView.dependentWeaponPreset.__update(weapon.dependentWeaponPreset)
        presetView.bannedWeaponPreset.__update(weapon.bannedWeaponPreset)
      }
    }
  presetView.tiersView = getTiers(unit, presetView)
  if (isCustom && unit.hasWeaponSlots && availableWeapons != null)
    updateTiersActivity(presetView.tiersView, availableWeapons)

  if((preset?.presetType != null) && !CHAPTER_ORDER.contains(preset.presetType))
    CHAPTER_ORDER.append(preset.presetType) // Needs add custom preset type in order array to get right chapter order

  return presetView
}

let function getCustomWeaponryPresetView(unit, curPreset, favoriteArr, availableWeapons) {
  let presetBlk = convertPresetToBlk(curPreset)
  let preset =  getCustomPresetByPresetBlk(unit, curPreset.name, presetBlk)
  let weaponry = addWeaponsFromBlk({}, getWeaponsByTypes(::get_full_unit_blk(unit.name), presetBlk), unit)
  return getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons)
}

let function getWeaponryPresetView(unit, preset, favoriteArr, availableWeapons) {
  let weaponry = getUnitWeaponry(unit, {isPrimary = false, weaponPreset = preset.name})
  return getPresetView(unit, preset, weaponry, favoriteArr, availableWeapons)
}

let function getWeaponryByPresetInfo(unit, chooseMenuList = null)
{
  updateUnitWeaponsByPreset(unit)
  let res = {
    presets = []
    favoriteArr = getFavoritePresets(unit.name)
    availableWeapons = unit.hasWeaponSlots ? getUnitWeapons(::get_full_unit_blk(unit.name)) : null
  }
  let presetsList = getPresetsList(unit, chooseMenuList)

  foreach(preset in presetsList)
    res.presets.append(getWeaponryPresetView(unit, preset, res.favoriteArr, res.availableWeapons))

  res.presets.sort(sortPresetsList)
  return res
}

let function editSlotInPresetImpl(preset, slots, cb) {
  foreach (slot in slots)
    if ("presetId" not in slot) {
      if (slot.tierId in preset.tiers)
        delete preset.tiers[slot.tierId]
    }
    else
      preset.tiers[slot.tierId] <- {slot = slot.slot, presetId = slot.presetId}
  cb()
}

let findAvailableWeapon = @(availableWeapons, presetId, tierId)
  availableWeapons.findvalue(@(w) w.presetId == presetId && w.tier == tierId)

let function getAvailableWeaponName(availableWeapons, presetId, tierId, weaponBlkCache = {}) {
  let wBlk = findAvailableWeapon(availableWeapons, presetId, tierId)
  if (wBlk == null)
    return presetId
  return getWeaponNameByBlkPath(getWeaponBlkParams(wBlk.blk, weaponBlkCache).weaponBlkPath)
}

let function addDependedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams) {
  foreach (slot in (wBlk % "dependentWeaponPreset")) {
    let dependWBlk = availableWeapons.findvalue(@(w) w.presetId == slot.preset && w.slot == slot.slot)
    if (dependWBlk == null)
      continue

    let dependWeaponTier = dependWBlk.tier
    editSlotParams.slots.append({slot = dependWBlk.slot, presetId = dependWBlk.presetId, tierId = dependWeaponTier})
    if (preset.tiers?[dependWeaponTier] == null || preset.tiers[dependWeaponTier].presetId == dependWBlk.presetId)
      continue

    let dependWeaponName = getAvailableWeaponName(availableWeapons, dependWBlk.presetId,
      dependWeaponTier, editSlotParams.weaponBlkCache)
    let curWeaponName = getAvailableWeaponName(availableWeapons, preset.tiers[dependWeaponTier].presetId,
      dependWeaponTier, editSlotParams.weaponBlkCache)
    let currentWeapon = ::loc($"weapons/{curWeaponName}")
    editSlotParams.msgTextArray.append(::loc("editWeaponsSlot/requiredDependedWeaponInOccupiedSlot", {
      currentWeapon
      dependWeapon = ::loc($"weapons/{dependWeaponName}")
      tierNum = dependWeaponTier + 1
    }))
    appendOnce(currentWeapon, editSlotParams.removedWeapon)
    editSlotParams.removedWeaponCount++
  }
}

let function addBannedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams) {
  let weaponsToRemove = []
  foreach (slot in (wBlk % "bannedWeaponPreset")) {
    let bannedWBlk = availableWeapons.findvalue(@(w) w.presetId == slot.preset && w.slot == slot.slot)
    if (bannedWBlk == null)
      continue

    let bannedWeaponTier = bannedWBlk.tier
    if (preset.tiers?[bannedWeaponTier].presetId != bannedWBlk.presetId)
      continue

    editSlotParams.slots.append({tierId = bannedWeaponTier})
    let bannedWeaponName = getAvailableWeaponName(availableWeapons, bannedWBlk.presetId,
      bannedWeaponTier, editSlotParams.weaponBlkCache)
    let bannedWeapon = ::loc($"weapons/{bannedWeaponName}")
    appendOnce(bannedWeapon, editSlotParams.removedWeapon)
    weaponsToRemove.append({ bannedWeapon, tierNum = bannedWeaponTier + 1})
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(::loc("editWeaponsSlot/bannedWeapons", {
    bannedWeapons = ::loc("ui/comma").join(weaponsToRemove.map(@(w) ::loc("editWeaponsSlot/weaponInSlot", {
      weapon = w.bannedWeapon
      tierNum = w.tierNum
    })))
  }))
}

let function addBanedByWeaponsParams(preset, tierId, presetId, availableWeapons, wBlk, editSlotParams) {
  if (presetId not in preset.bannedWeaponPreset)
    return

  let weapons = preset.bannedWeaponPreset[presetId].filter(@(w) w.slot == wBlk.slot) ?? []
  let weaponsToRemove = []
  foreach (weapon in weapons) {
    editSlotParams.slots.append({tierId = weapon.bannedByTier})
    let weaponName = getAvailableWeaponName(availableWeapons, weapon.bannedByPresetId,
      weapon.bannedByTier, editSlotParams.weaponBlkCache)
    let weaponLocName = ::loc($"weapons/{weaponName}")
      appendOnce(weaponLocName, editSlotParams.removedWeapon)
    weaponsToRemove.append({ weaponLocName, tierNum = weapon.bannedByTier + 1})
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(::loc("editWeaponsSlot/bannedByWeapons", {
    currentWeapon = ::loc($"weapons/{getAvailableWeaponName(availableWeapons, presetId, tierId, editSlotParams.weaponBlkCache)}")
    weapons = ::loc("ui/comma").join(weaponsToRemove.map(@(w) ::loc("editWeaponsSlot/weaponInSlot", {
      weapon = w.weaponLocName
      tierNum = w.tierNum
    })))
  }))
}

let function addRemovedDependetWeaponsParams(preset, tierId, availableWeapons, editSlotParams) {
  let curPresetInTier = preset.tiers?[tierId]
  if (curPresetInTier == null)
    return

  let {presetId, slot} = curPresetInTier
  if (presetId not in preset.dependentWeaponPreset)
    return

  let dependentWeapons = preset.dependentWeaponPreset[presetId].filter(@(w) w.slot == slot) ?? []
  let weaponsToRemove = []
  foreach (dependentWeapon in dependentWeapons) {
    editSlotParams.slots.append({tierId = dependentWeapon.reqForTier})
    let dependWeaponName = getAvailableWeaponName(availableWeapons, dependentWeapon.reqForPresetId,
      dependentWeapon.reqForTier, editSlotParams.weaponBlkCache)
    let dependWeapon = ::loc($"weapons/{dependWeaponName}")
    appendOnce(dependWeapon,editSlotParams. removedWeapon)
    weaponsToRemove.append({ dependWeapon, tierNum = dependentWeapon.reqForTier + 1})
    editSlotParams.removedWeaponCount++
  }
  if (weaponsToRemove.len() == 0)
    return

  editSlotParams.msgTextArray.append(::loc("editWeaponsSlot/requiredForDependedWeapon", {
    currentWeapon = ::loc($"weapons/{getAvailableWeaponName(availableWeapons, presetId, tierId, editSlotParams.weaponBlkCache)}")
    dependWeapons = ::loc("ui/comma").join(weaponsToRemove.map(@(w) ::loc("editWeaponsSlot/weaponInSlot", {
      weapon = w.dependWeapon
      tierNum = w.tierNum
    })))
  }))
}

let function editSlotInPreset(preset, tierId, presetId, availableWeapons, cb) {
  let editSlotParams = {
    slots = []
    msgTextArray = []
    removedWeapon = []
    weaponBlkCache = {}
    removedWeaponCount = 0
  }
  if (presetId == "")
    editSlotParams.slots.append({tierId})
  else {
    let wBlk = findAvailableWeapon(availableWeapons, presetId, tierId)
    if (wBlk != null) {
      editSlotParams.slots.append({slot = wBlk.slot, presetId = wBlk.presetId, tierId})
      addDependedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams)
      addBannedWeaponsParams(preset, availableWeapons, wBlk, editSlotParams)
      addBanedByWeaponsParams(preset, tierId, presetId, availableWeapons, wBlk, editSlotParams)
    }
  }
  addRemovedDependetWeaponsParams(preset, tierId, availableWeapons, editSlotParams)

  let {msgTextArray, slots, removedWeapon, removedWeaponCount} = editSlotParams
  if (msgTextArray.len() == 0) {
    editSlotInPresetImpl(preset, slots, cb)
    return
  }

  msgTextArray.append(::loc("editWeaponsSlot/removedDependedWeapons", {
    weapons = ::loc("ui/comma").join(removedWeapon)
    weaponsCount = removedWeaponCount
  }))
  ::scene_msg_box("question_edit_slots_in_preset", null, "\n".join(msgTextArray),
    [
      ["ok", @() editSlotInPresetImpl(preset, slots, cb) ],
      ["cancel", @() null ]
    ],
    "ok", { cancel_fn = @() null })
}

let function getPresetDisbalanceText(preset, maxDisbalance, notUseforDisbalance) {
  if (maxDisbalance < 0)
    return ""

  let massBySide = [0, 0]
  let centerIdx = TIERS_NUMBER/2
  foreach (idx, tier in preset.tiersView) {
    if (notUseforDisbalance?[idx] ?? false)
      continue

    let sideIdx = idx < centerIdx ? 0 : 1
    massBySide[sideIdx] += tier?.weaponry.massKg ?? 0.0
  }

  let disbalance = abs(massBySide[0]-massBySide[1])
  if (disbalance <= maxDisbalance)
    return ""

  let kgMeasure = ::g_measure_type.getTypeByName("kg", true)
  return ::loc("weapons/pylonsWeightDisbalance", {
    side = ::loc($"side/{massBySide[0] > massBySide[1] ? "left" : "right"}")
    disbalance = kgMeasure.getMeasureUnitsText(disbalance)
    maxDisbalance = kgMeasure.getMeasureUnitsText(maxDisbalance)
  })
}

return {
  getWeaponryByPresetInfo
  setFavoritePresets
  sortPresetsList
  getTierTooltipParams
  getTierWeaponsParams
  getCustomWeaponryPresetView
  getWeaponryPresetView
  editSlotInPreset
  getPresetDisbalanceText
}
