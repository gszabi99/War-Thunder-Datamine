from "%scripts/dagui_library.nut" import *
let { eachBlock } = require("%sqstd/datablock.nut")
let { getFullUnitBlk } = require("%scripts/unit/unitParams.nut")
let { getUnitTooltipImage } = require("%scripts/unit/unitInfoTexts.nut")

let supportUnits = {
}

let baseUnits = {
}

function getSupportUnits(unitName) {
  if (unitName in supportUnits)
    return supportUnits[unitName]

  let { supportPlanes = null } = getFullUnitBlk(unitName)
  let supPlanes = []
  if (supportPlanes == null) {
    supportUnits[unitName] <- supPlanes
    return supPlanes
  }

  eachBlock(supportPlanes, function(supInfo) {
    if (!supInfo?.isSlave)
      return
    let supName = supInfo["class"].split("/")?[1] ?? supInfo["class"] ?? ""
    if (!supPlanes.contains(supName)) {
      supPlanes.append(supName)
      baseUnits[supName] <- unitName
    }
  })

  supportUnits[unitName] <- supPlanes
  return supPlanes
}

function getBaseUnit(supportUnitName) {
  return baseUnits?[supportUnitName]
}

function getSupportUnitImage(unitName) {
  let supportUnit = getAircraftByName(unitName)
  if (supportUnit == null)
    return ""
  return getUnitTooltipImage(supportUnit)
}

return {
  getSupportUnits
  getSupportUnitImage
  getBaseUnit
}
