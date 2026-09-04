from "weaponSelector" import AAM_TRIGGER, AGM_TRIGGER, MINES_TRIGGER, BOMBS_TRIGGER, ROCKETS_TRIGGER, TORPEDOES_TRIGGER
from "guiMission" import get_mission_difficulty_int
from "%scripts/dagui_library.nut" import *
from "%globalScripts/difficultyConsts.nut" import *

const FIND_DIRECTION_MIDDLE = 0
const FIND_DIRECTION_LEFT = 1
const FIND_DIRECTION_RIGHT = 2

let triggerTypeConvert = {
  aam = AAM_TRIGGER
  agm = AGM_TRIGGER
  atgm = AGM_TRIGGER
  mines = MINES_TRIGGER
  bombs = BOMBS_TRIGGER
  rockets = ROCKETS_TRIGGER
  torpedoes = TORPEDOES_TRIGGER
}

function preparePresetData(chosenPreset, unit) {
  local weaponsCount = 0
  local gunsInPresetCount = 0
  let slotIdToTiersId = {}
  let weaponSlotToTiersId = {}

  foreach (idx, t in chosenPreset.tiersView) {
    let tier = t?.weaponry.tiers[t.tierId]
    if (t?.weaponry != null)
      weaponsCount++
    if (unit.hasWeaponSlots) {
      if (tier != null && tier?.slot != null)
        slotIdToTiersId[tier.slot] <- t.tierId
      continue
    }
    slotIdToTiersId[idx] <- t.tierId
  }

  if (!unit.hasWeaponSlots && weaponsCount > 0) {
    gunsInPresetCount = 0
    foreach (idx, t in chosenPreset.tiersView) {
      if (t?.weaponry == null)
        continue
      if (t.weaponry?.isGun)
        gunsInPresetCount++

      weaponSlotToTiersId[idx] <- {
        tierId = slotIdToTiersId[idx],
        ammo = t.weaponry?.tiers[t.tierId].amountPerTier ?? t.weaponry?.amountPerTier ?? 1,
        countedAmmo = 0
        trigger = triggerTypeConvert?[t.weaponry?.tType] ?? -1
      }
    }
  }
  return {weaponSlotToTiersId, slotIdToTiersId, gunsInPresetCount}
}

function getNextDirection(curDirection, hasMiddleWeapon) {
  if (curDirection == FIND_DIRECTION_RIGHT)
    return hasMiddleWeapon ? FIND_DIRECTION_MIDDLE : FIND_DIRECTION_LEFT
  return curDirection + 1
}

function isSuitableWeaponSlot(idx, trigger, weaponSlotToTiersId) {
  return weaponSlotToTiersId?[idx] != null
    && weaponSlotToTiersId[idx].trigger == trigger
    && weaponSlotToTiersId[idx].countedAmmo < weaponSlotToTiersId[idx].ammo
}

function getNextSideData(directionData, trigger, weaponSlotToTiersId, maxSlotNum) {
  let isLeft = directionData.direction == FIND_DIRECTION_LEFT
  local cycleNum = 0
  local stepCount = 0

  let sideData = isLeft ? directionData.left : directionData.right
  let startIndex = sideData.index

  while (stepCount < directionData.sideCount) {
    if (cycleNum > 0 && startIndex == sideData.index)
      return null
    stepCount++
    sideData.index = sideData.index + 1
    let index = sideData.first + (isLeft ? -sideData.index : sideData.index)
    if (index < 0 || index >= maxSlotNum) {
      sideData.index = -1
      cycleNum = cycleNum + 1
      continue
    }
    if (isSuitableWeaponSlot(index, trigger, weaponSlotToTiersId))
      return weaponSlotToTiersId[index]
  }
  return null
}

function getTierDataByDirection(directionData, trigger, weaponSlotToTiersId, maxSlotNum) {
  return directionData.direction == FIND_DIRECTION_MIDDLE
    ? isSuitableWeaponSlot(directionData.middleCell, trigger, weaponSlotToTiersId) ? weaponSlotToTiersId[directionData.middleCell] : null
    : getNextSideData(directionData, trigger, weaponSlotToTiersId, maxSlotNum)
}

function getTierData(directionData, trigger, weaponSlotToTiersId, maxSlotNum) {
  let stepCount = directionData.hasMiddleWeapon ? 3 : 2
  for (local i = 0; i < stepCount; i++) {
    directionData.direction = getNextDirection(directionData.direction, directionData.hasMiddleWeapon)
    let wdata = getTierDataByDirection(directionData, trigger, weaponSlotToTiersId, maxSlotNum)
    if (wdata != null)
      return wdata
  }
  return null
}

function updateTierStatsNoSlots(data, weaponSlotToTiersId, gunsInPresetCount, chosenPreset, unit) {
  let {weapons = [], blocksCount = 0, selected = []} = data
  let slotsCount = weaponSlotToTiersId.len() - gunsInPresetCount
  if (blocksCount <= 0 || weapons.len() == 0 || slotsCount == 0)
    return {}
  let blockSize = weapons.len() / blocksCount
  let lastTiersStats = {}

  let middleCell = (chosenPreset.tiersView.len() / 2).tointeger()
  let directionData = {
    left = {index = -1, first = middleCell - 1}
    right = {index = -1, first = middleCell + 1}
    direction = FIND_DIRECTION_RIGHT
    middleCell
    sideCount = middleCell + 1
    hasMiddleWeapon = chosenPreset.tiersView[middleCell]?.weaponry != null
  }

  foreach (w in weaponSlotToTiersId)
    w.countedAmmo = 0

  let weaponsIdxToTierId = {}
  local prevTrigger = -1
  let maxSlotNum = chosenPreset.tiersView.len()
  for (local i = 0; i < blocksCount; i++) {
    let weaponIdx = weapons[i * blockSize + 3]
    if (weaponIdx < 0)
      continue

    let trigger = weapons[i * blockSize + 4]
    if (prevTrigger != trigger) {
      directionData.left.index = -1
      directionData.right.index = -1
      directionData.direction = FIND_DIRECTION_RIGHT
      prevTrigger = trigger
    }

    let oldTierData = getTierData(directionData, trigger, weaponSlotToTiersId, maxSlotNum)
    if (!oldTierData) {
      logerr($"Selector: updateTierStatsNoSlots tierData not found {unit.name} {chosenPreset.name}")
      continue
    }
    let maxAmmo = weapons[i * blockSize + 2]
    oldTierData.countedAmmo += maxAmmo
    let tierId = oldTierData.tierId
    weaponsIdxToTierId[weaponIdx] <- tierId
    if (lastTiersStats?[tierId] == null) {
      lastTiersStats[tierId] <- {
        tierId
        count = 0
        maxCount = 0
        weaponIdx
      }
    }
    let tierStats = lastTiersStats[tierId]
    tierStats.count = tierStats.count + weapons[i * blockSize + 1]
    tierStats.maxCount = tierStats.maxCount + maxAmmo
  }
  let selectedTiers =
    selected.map(@(t) weaponsIdxToTierId?[t] ?? -1)
  return {lastTiersStats, selectedTiers}
}

function updateTierStats(data, slotIdToTiersId) {
  let lastTiersStats = {}
  let weaponsToTiers = {}
  let {weapons = [], blocksCount = 0, selected = [], nextWeapon = -1, isNextWeaponSeparate = true} = data
  if (blocksCount <= 0 || weapons.len() == 0)
    return { lastTiersStats, weaponsToTiers, selectedTiers = [], nextWeaponsTiers = [] }

  let blockSize = weapons.len() / blocksCount
  for (local i = 0; i < blocksCount; i++) {
    let weaponIdx = weapons[i * blockSize + 3]
    if (weaponIdx == -1)
      continue
    let tierId = slotIdToTiersId?[weapons[i * blockSize]] ?? -1
    weaponsToTiers[weaponIdx] <- tierId
    if (lastTiersStats?[tierId] == null) {
      lastTiersStats[tierId] <- {
        tierId
        count = weapons[i * blockSize + 1]
        maxCount = weapons[i * blockSize + 2]
        weaponIdx
        trigger = weapons[i * blockSize + 4]
      }
      continue
    }
    let stats = lastTiersStats[tierId]
    let trigger = weapons[i * blockSize + 4]
    if (stats.trigger != trigger)
      continue

    stats.count = stats.count + weapons[i * blockSize + 1]
    stats.maxCount = stats.maxCount + weapons[i * blockSize + 2]
  }
  let selectedTiers = selected.map(@(t) slotIdToTiersId?[t] ?? -1)
  local nextWeaponsTiers = null
  if (!(isNextWeaponSeparate || get_mission_difficulty_int() == DIFFICULTY_ARCADE))
    nextWeaponsTiers = selectedTiers
  else
    nextWeaponsTiers = [slotIdToTiersId?[nextWeapon] ?? -1]

  return { lastTiersStats, selectedTiers, nextWeaponsTiers, weaponsToTiers }
}


return {
  getTierData
  updateTierStatsNoSlots
  updateTierStats
  preparePresetData
}
