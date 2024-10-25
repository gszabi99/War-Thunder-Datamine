from "%rGui/globals/ui_library.nut" import *
let DataBlock = require("DataBlock")
let { wwGetConfigurableValues } = require("worldwar")

let configurableValues = DataBlock()

let initConfigurableValues = @() wwGetConfigurableValues(configurableValues)
let getArtilleryUnits = @() configurableValues.artilleryUnits
let getInfantryUnits = @() configurableValues.infantryUnits

function getArtilleryParams(armyData) {
  let units = armyData.getBlockByName("units")
  let artilleryUnits = getArtilleryUnits()
  for (local i = 0; i < units.blockCount(); i++) {
    let wwUnitName = units.getBlock(i).getBlockName()
    if (wwUnitName in artilleryUnits)
      return artilleryUnits[wwUnitName]
  }
  return null
}

return {
  initConfigurableValues
  getArtilleryUnits
  getInfantryUnits
  getArtilleryParams
}