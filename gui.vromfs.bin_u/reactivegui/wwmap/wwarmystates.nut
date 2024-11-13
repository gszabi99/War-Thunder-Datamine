from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { pow } = require("math")
let { wwGetArmiesNames, wwGetArmyInfo, wwClearOutlinedZones, wwUpdateSelectedArmyName } = require("worldwar")
let { subscribe } = require("eventbus")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")
let { sendToDagui } = require("%rGui/wwMap/wwMapUtils.nut")
let { updateSelectedAirfield } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { getMapAspectRatio, convertToRelativeMapCoords, getMapSize } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { armyIconByType } = require("%rGui/wwMap/wwMapTypes.nut")
let { getSettings, getSettingsArray } = require("%rGui/wwMap/wwSettings.nut")

let selectedArmy = Watched(null)
let hoveredArmy = Watched(null)
let isShowArmiesIndex = Watched(false)

local lastSelectedArmy = null
local lastSelectedArmyIndex = -1

let armiesList = Watched([])
let armiesData = Watched([])

function updateArmiesState() {
  let wwArmiesNames = wwGetArmiesNames()
  if (!isEqual(wwArmiesNames, armiesList.get())) {
    armiesData.set(wwArmiesNames.map(function(v) {
      let ai = DataBlock()
      wwGetArmyInfo(v, ai)
      return ai
    }))

   armiesList.set(wwArmiesNames)
  }
  else {
    wwArmiesNames.each(function(armyName) {
      let ai = DataBlock()
      wwGetArmyInfo(armyName, ai)
      let idx = armiesData.get().findindex(@(a) a.name == armyName)
      if (idx != null) {
        if (!isEqual(armiesData.get()[idx], ai))
          armiesData.mutate(@(arr) arr[idx] = ai)
      }
   })
  }
}

function getArmyByPoint(point) {
  let aspectRatio = getMapAspectRatio()
  return armiesData.get()
    .filter(function(armyData) {
      let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
      let armyRadius = armyData.specs.battleStartRadiusN / getMapSize().width
      return (pow(armyPos.x - point.x, 2) + pow((armyPos.y - point.y) * aspectRatio, 2) < pow(armyRadius, 2))
    })
}

function getArmyForHover(point) {
  let armies = getArmyByPoint(point)

  if (armies.len() == 0)
    return null

  return armies.contains(lastSelectedArmy) ? lastSelectedArmy : armies.top()
}

function getArmyForSelection(point) {
  let armies = getArmyByPoint(point)
  if (!armies.contains(lastSelectedArmy))
    lastSelectedArmyIndex = -1

  lastSelectedArmy = null
  if (armies.len() == 1)
    lastSelectedArmy = armies[0]
  else if (armies.len() > 1) {
    lastSelectedArmyIndex = ++lastSelectedArmyIndex % armies.len()
    lastSelectedArmy = armies[lastSelectedArmyIndex]
  }

  return lastSelectedArmy
}

function getArmyByName(armyName) {
  return armiesData.get().findvalue(@(armyData) armyData.name == armyName)
}

let getArmyIconOverride = @(name) getSettingsArray("armyIconCustom").findvalue(@(v) v.name == name)

function getArmyIcon(armyData) {
  if (armyData.iconOverride != "")
    return getArmyIconOverride(armyData.iconOverride)

  let unitType = armyData?.unitType ?? armyData.specs.unitType
  let data = armyIconByType[unitType]?.data
  if (data == null)
    armyIconByType[unitType].data <- getSettings(armyIconByType[unitType]?.type)
  return armyIconByType[unitType].data
}

subscribe("ww.hoverArmyByName", @(v) hoveredArmy.set(v))
subscribe("ww.showArmiesIndex", @(v) isShowArmiesIndex.set(v))

subscribe("ww.selectArmyByName", @(v) selectedArmy.set(v))
subscribe("ww.unselectAirfield", @(_v) updateSelectedAirfield(null))


subscribe("selectArmy", function(armyName) {
  updateArmiesState()
  selectedArmy.set(armyName)
})

hoveredArmy.subscribe(function(armyName) {
  sendToDagui("ww.hoverArmy", armyName != null ? { armyName } : {})
})

selectedArmy.subscribe(function(armyName) {
  wwClearOutlinedZones()
  if (armyName == null)
    return

  wwUpdateSelectedArmyName(armyName, true)
  sendToDagui("ww.selectArmy", { armyName })
})

return {
  selectedArmy
  hoveredArmy
  isShowArmiesIndex

  getArmyForHover
  getArmyForSelection

  updateArmiesState
  armiesList
  armiesData

  getArmyByName
  getArmyIcon
}