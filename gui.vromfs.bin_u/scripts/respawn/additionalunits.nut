from "%scripts/dagui_library.nut" import *
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { isUnlockOpened, isUnlockExist } = require("%scripts/unlocks/unlocksModule.nut")
let { get_current_mission_info_cached } = require("blkGetters")

let units = mkWatched(persist, "units", [])
let usedUnits = mkWatched(persist, "usedUnits", {})
let baseUnit = mkWatched(persist, "baseUnit", {})
let selectedUnit = mkWatched(persist, "selectedUnit", {})

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

  selectedUnit.set(initialSelectedUnits)

  units.set(res)
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

return {
  initAdditionalUnits
  isUnitSelected
  getUnitsBlockByUnitName
  createAdditionalUnitsViewData
  updateUnitSelection
  isLockedUnit
  isEventUnit
  isUnitUsed
  setUnitUsed
}
