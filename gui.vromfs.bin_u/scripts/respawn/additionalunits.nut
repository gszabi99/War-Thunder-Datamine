from "%scripts/unit/unitInfoTexts.nut" import getUnitTooltipImage
from "%scripts/unit/unitInfo.nut" import getUnitName
from "%scripts/utils/genericTooltipTypes.nut" import getTooltipType
from "%scripts/unlocks/unlocksModule.nut" import isUnlockOpened, isUnlockExist
from "blkGetters" import get_current_mission_info_cached
from "multiplayer" import get_mp_session_id_str
from "%scripts/dagui_library.nut" import *

let hardPersistWatched = mkHardPersistWatched("respawn.additionalUnits")
let units = Watched([])
let usedUnits = hardPersistWatched("usedUnits", {})
let baseUnit = Watched({})
let selectedUnit = hardPersistWatched("selectedUnit", {})
let initedSessionId = hardPersistWatched("initedSessionId", null)

function initAdditionalUnits(blk) {
  let res = []
  let initialSelectedUnits = {}
  let baseUnitsCount = blk.blockCount()
  for (local i = 0; i < baseUnitsCount; i++) {
    let unitsBlock = blk.getBlock(i)
    let baseUnitName = unitsBlock.getBlockName()
    let additionalUnits = unitsBlock % "additionalUnit"
    res
      .append({ unitName = baseUnitName, baseUnitName })
      .extend(additionalUnits.map(@(u) { unitName = u, baseUnitName }))

    initialSelectedUnits[baseUnitName] <- baseUnitName
  }

  baseUnit.set(res.reduce(function(r, v) {
    r[v.unitName] <- v.baseUnitName
    return r
  }, {}))

  units.set(res)

  let sessionId = get_mp_session_id_str()
  if (sessionId == initedSessionId.get())
    return
  initedSessionId.set(sessionId)
  selectedUnit.set(initialSelectedUnits)
  usedUnits.set({})
}

let isEventUnit = @(unitName) unitName in baseUnit.get()

function isLockedUnit(unitName) {
  let cmi = get_current_mission_info_cached()
  let unitReqUnlock = cmi?.editSlotbar.getBlock(0)[unitName].unlockId ?? ""
  if(unitReqUnlock == "")
    return false
  return isUnlockExist(unitReqUnlock) && !isUnlockOpened(unitReqUnlock)
}

let isUnitSelected = @(unitName) selectedUnit.get()[baseUnit.get()[unitName]] == unitName
let getUnitsBlockByBaseUnitName = @(baseUnitName) units.get().filter(@(v) v.baseUnitName == baseUnitName)

function getUnitsBlockByUnitName(unitName) {
  let block = units.get().findvalue(@(v) v.unitName == unitName)
  if(block == null)
    return null
  return getUnitsBlockByBaseUnitName(block.baseUnitName)
}

let getBaseUnitName = @(unitName) baseUnit.get()?[unitName] ?? unitName

function isUnitUsed(unitName) {
  let baseUnitName = getBaseUnitName(unitName)
  return usedUnits.get()?[baseUnitName] != null
}

function setUnitUsed(unitName) {
  let baseUnitName = getBaseUnitName(unitName)
  usedUnits.mutate(@(v) v[baseUnitName] <- true)
}

function createAdditionalUnitsViewData(unitName) {
  let block = getUnitsBlockByUnitName(unitName)
  if(block == null)
    return null

  return block.map(function(v, idx) {
    let unit = getAircraftByName(v.unitName)
    return {
      unitName = v.unitName
      unitFullName = getUnitName(unit, false)
      isFirst = idx == 0
      unitImage = getUnitTooltipImage(unit)
      tooltipId = getTooltipType("UNIT").getTooltipId(v.unitName, {})
      isLocked = isLockedUnit(v.unitName) ? "yes" : "no"
      isSelected = isUnitSelected(v.unitName)
    }
  })
}

let updateUnitSelection = @(unitName) selectedUnit.mutate(@(su) su[baseUnit.get()[unitName]] <- unitName)

return freeze({
  initAdditionalUnits
  isUnitSelected
  getUnitsBlockByUnitName
  createAdditionalUnitsViewData
  updateUnitSelection
  isLockedUnit
  isEventUnit
  isUnitUsed
  setUnitUsed
})
