import "%rGui/wwMap/wwMapZonesBackground.nut" as mkMapZonesBackground
from "%rGui/wwMap/wwArmyStates.nut" import getArmyForHover, getArmyForSelection, selectedArmy, hoveredArmy, newPartOfArmyPath
from "%rGui/wwMap/wwOperationStates.nut" import isOperationPausedWatch
from "%rGui/wwMap/wwMapZonesData.nut" import updateHoveredZone, getZoneByPoint, updateSelectedRearZone
from "%rGui/wwMap/wwMapZonesEdges.nut" import mkMapZonesEdges, mkMapHoveredZone
from "%rGui/wwMap/wwMapFrontLine.nut" import mkMapFrontLine
from "%rGui/wwMap/wwMapZoneNames.nut" import mkMapZoneNames
from "%rGui/wwMap/wwMapSectorSprites.nut" import mkSectorSprites
from "%rGui/wwMap/wwAirfields.nut" import mkAirfields
from "%rGui/wwMap/wwArmies.nut" import mkArmies
from "%rGui/wwMap/wwBattles.nut" import battles
from "%rGui/wwMap/wwBattlesMessages.nut" import mkBattlesMessages
from "%rGui/wwMap/wwArtilleryStrikes.nut" import artilleryStrikes
from "%rGui/wwMap/wwSAMVisualizations.nut" import samVisualizations
from "%rGui/wwMap/wwBattlesStates.nut" import getBattleByPoint, updateHoveredBattle, updateSelectedBattle, hoveredBattle
from "%rGui/wwMap/wwAirfieldsStates.nut" import getAirfieldByPoint, updateHoveredAirfield, updateSelectedAirfield, selectedAirfield
from "%rGui/wwMap/wwActionsLayer.nut" import actionsLayer
from "%rGui/wwMap/wwActionManager.nut" import haveActiveAction, doAction, moveArmy, sendAircraft
from "%rGui/wwMap/wwConfigurationInit.nut" import configurationLoaded, initConfiguration, invalidateConfiguration
from "%rGui/wwMap/wwOperationConfiguration.nut" import holderBounds, activeAreaBounds, getOperationMapImage, convertPointerCoords, convertPointerToMapCoords, getMapCellByCoords
from "%rGui/wwMap/wwMapStates.nut" import startUpdates, stopUpdates, cursorPosition, isShiftPressed
from "%rGui/wwMap/wwMapUtils.nut" import sendToDagui
from "%appGlobals/wwObjectsUnderCursor.nut" import mapCellUnderCursor, armyUnderCursor, mapCoordsUnderCursor
from "%appGlobals/worldWar/wwMapHoverState.nut" import isMapHovered
from "dagor.workcycle" import deferOnce
from "%rGui/globals/ui_library.nut" import *

const backgroundColor = 0xFF1B2226
const transparentColor = 0x00000000
let cursorPositionRT = Watched(null)

let clearAllHovers = @() sendToDagui("ww.clearHovers")

function processPointerMove(evt, areaBounds) {
  if (!evt.hit) {
    updateHoveredZone(null)
    return
  }

  let pos = convertPointerCoords(evt, areaBounds)

  if (evt.btnId == 0 && selectedArmy.get() != null)
    newPartOfArmyPath.set({ armyName = selectedArmy.get(), newPos = pos })
  else
    newPartOfArmyPath.set(null)

  let zoneUnderCursor = getZoneByPoint(pos)
  updateHoveredZone(zoneUnderCursor)

  let battle = getBattleByPoint(pos)
  if (battle != null) {
    updateHoveredAirfield(null)
    hoveredArmy.set(null)
    updateHoveredBattle(battle)
    return
  }

  updateHoveredBattle(null)
  let army = getArmyForHover(pos)
  if (army != null) {
    updateHoveredAirfield(null)
    armyUnderCursor.set(army.name)
    hoveredArmy.set(army.name)
    return
  }

  hoveredArmy.set(null)
  let airfield = getAirfieldByPoint(pos)
  if (airfield != null) {
    updateHoveredAirfield(airfield)
    return
  }

  updateHoveredAirfield(null)
  clearAllHovers()
}

function updateCursorPosition() {
  let { evt, areaBounds } = cursorPositionRT.get()
  cursorPosition.set(evt)
  processPointerMove(evt, areaBounds)
}

cursorPositionRT.subscribe(@(_) deferOnce(updateCursorPosition))

let processPointer = @(evt, areaBounds) cursorPositionRT.set({ evt, areaBounds })

function processPointerPress(evt, areaBounds) {
  if (!evt.hit)
    return

  newPartOfArmyPath.set(null)
  let { x, y } = evt

  mapCellUnderCursor.set(getMapCellByCoords(x, y, areaBounds))
  mapCoordsUnderCursor.set(convertPointerToMapCoords(evt, areaBounds))

  if (evt.btnId == 0 && evt.shiftKey && selectedArmy.get() != null) {
    moveArmy(null, { x, y }, true)
    return
  }

  if (evt.btnId == 1) {
    let armyTargetName = hoveredBattle.get() ?? hoveredArmy.get()
    if (selectedArmy.get() != null)
      moveArmy(armyTargetName, { x, y }, false)
    else if (selectedAirfield.get() != null)
      sendAircraft(selectedAirfield.get(), armyTargetName, { x, y })

    return
  }

  if (haveActiveAction()) {
    doAction({ x, y })
    return
  }

  let pos = convertPointerCoords(evt, areaBounds)

  let battle = getBattleByPoint(pos)
  if (battle != null) {
    updateSelectedAirfield(null)
    selectedArmy.set(null)
    updateSelectedBattle(battle)
    return
  }

  updateSelectedBattle(null)
  let army = getArmyForSelection(pos)
  if (army != null) {
    updateSelectedAirfield(null)
    selectedArmy.set(army.name)
    return
  }

  selectedArmy.set(null)
  let airfield = getAirfieldByPoint(pos)
  if (airfield != null) {
    updateSelectedAirfield(airfield)
    return
  }

  updateSelectedAirfield(null)
  updateSelectedRearZone(getZoneByPoint(pos))
}

let mapFOW = @() {
  watch = isOperationPausedWatch
  rendObj = ROBJ_SOLID
  size = FLEX
  color = isOperationPausedWatch.get() ? Color(0, 0, 0, 64) : transparentColor
}

let mapBackground = @() {
  watch = activeAreaBounds
  rendObj = ROBJ_IMAGE
  size = activeAreaBounds.get().rectangleArea
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  image = Picture(getOperationMapImage())
}

let shiftPressedMonitor = {
  behavior = Behaviors.Button
  onElemState = @(sf) isShiftPressed.set((sf & S_ACTIVE) != 0)
  hotkeys = [["^L.Shift | R.Shift"]]
  onDetach = @() isShiftPressed.set(false)
}

let mkMapContainer = function() {
  if(holderBounds.get() == null)
    return { watch = [holderBounds, activeAreaBounds] }

  let { holderPosX, holderPosY, holderWidth, holderHeight } = holderBounds.get()
  return {
    watch = [holderBounds, activeAreaBounds]
    behavior = Behaviors.ProcessPointingInput
    pos = [holderPosX, holderPosY]
    size = [holderWidth, holderHeight]
    clipChildren = true
    children = [
      shiftPressedMonitor,
      mapBackground,
      mkMapZonesBackground,
      mkMapZonesEdges,
      mkMapHoveredZone,
      mkMapFrontLine,
      mkMapZoneNames,
      mkAirfields,
      mkSectorSprites,
      samVisualizations,
      mkArmies,
      battles,
      artilleryStrikes,
      actionsLayer,
      mkBattlesMessages,
      mapFOW
    ]
    function onAttach() {
      startUpdates()
    }
    function onPointerMove(evt) {
      if (isMapHovered.get())
        processPointer(evt, activeAreaBounds.get())
    }

    function onPointerPress(evt) {
      if (isMapHovered.get())
        processPointerPress(evt, activeAreaBounds.get())
    }
  }
}

let mapHolder = @() function() {
  if (configurationLoaded.get() == false)
    return {
      watch = configurationLoaded
      function onAttach() {
        initConfiguration()
      }
    }

  return {
    watch = configurationLoaded
    size = const [sw(100), sh(100)]
    rendObj = ROBJ_SOLID
    color = backgroundColor
    children = mkMapContainer
    function onDetach() {
      stopUpdates()
      invalidateConfiguration()
    }
  }
}

return mapHolder