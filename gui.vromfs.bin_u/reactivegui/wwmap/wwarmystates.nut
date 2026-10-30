import "DataBlock" as DataBlock
from "%sqStdLibs/helpers/u.nut" import isEqual
from "%rGui/wwMap/wwMapUtils.nut" import sendToDagui
from "%rGui/wwMap/wwOperationConfiguration.nut" import getMapAspectRatio, convertToRelativeMapCoords, getMapSize
from "%appGlobals/worldWar/wwSettings.nut" import getSettings, getSettingsArray
from "%appGlobals/worldWar/wwMapHoverState.nut" import isMapHovered
from "%rGui/wwMap/wwOperationStates.nut" import isPlayerSideStr
from "math" import pow
from "worldwar" import wwGetArmiesNames, wwGetArmyInfo, wwClearOutlinedZones, wwUpdateSelectedArmyName, wwUpdateSelectedArmiesName
from "eventbus" import subscribe
from "%rGui/globals/ui_library.nut" import *

let { armyIconByType } = require("%rGui/wwMap/wwMapTypes.nut")

let selectedArmy = Watched(null)
let hoveredArmy = Watched(null)
let isShowArmiesIndex = Watched(false)

local lastSelectedArmy = null
local lastSelectedArmyIndex = -1

let armiesList = Watched([])
let armiesData = Watched([])

let movingArmiesPositions = Watched({})
let newPartOfArmyPath = Watched(null)

let armyNameForTooltip = keepref(Computed(@() (hoveredArmy.get() && isMapHovered.get()) ? hoveredArmy.get() : null))


function dropStoppedArmiesPositions() {
  let stopped = armiesData.get()
    .filter(@(a) a.name in movingArmiesPositions.get() && a.pathTracker.status != "ES_MOVING_BY_PATH")
  if (stopped.len() > 0)
    movingArmiesPositions.mutate(@(t) stopped.each(@(a) t.$rawdelete(a.name)))
}

function updateArmiesState() {
  let wwArmiesNames = wwGetArmiesNames()
  if (!isEqual(wwArmiesNames, armiesList.get())) {
    armiesData.set(wwArmiesNames.map(function(v) {
      let ai = DataBlock()
      wwGetArmyInfo(v, ai)
      return ai
    }).sort(@(army1, army2) isPlayerSideStr(army1.owner.side) <=> isPlayerSideStr(army2.owner.side) || army2.specs.unitType <=> army1.specs.unitType))

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
  dropStoppedArmiesPositions()
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

function mkArmyMapPosition(armyName) {
  let army = Computed(@() armiesData.get().findvalue(@(armyData) armyData.name == armyName))
  return Computed(function() {
    let pos = movingArmiesPositions.get()?[armyName]
    if (pos != null)
      return pos
    let armyInfo = army.get()
    return armyInfo == null ? null : convertToRelativeMapCoords(armyInfo.pathTracker.pos)
  })
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
subscribe("selectArmy", function(armyName) {
  updateArmiesState()
  selectedArmy.set(armyName)
})

armyNameForTooltip.subscribe(function(armyName) {
  sendToDagui("ww.hoverArmy", armyName != null ? { armyName } : {})
})

selectedArmy.subscribe(function(armyName) {
  wwClearOutlinedZones()
  if (armyName != null)
    wwUpdateSelectedArmyName(armyName, true)
  else
    wwUpdateSelectedArmiesName([])
  sendToDagui("ww.selectArmy", { armyName = armyName ?? "" })
})

return freeze({
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
  mkArmyMapPosition

  movingArmiesPositions

  newPartOfArmyPath
})