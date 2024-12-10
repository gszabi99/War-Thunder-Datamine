from "%rGui/globals/ui_library.nut" import *

let { getArmyForHover, getArmyForSelection, selectedArmy, hoveredArmy } = require("%rGui/wwMap/wwArmyStates.nut")
let { isOperationPausedWatch } = require("%rGui/wwMap/wwOperationStates.nut")
let { updateHoveredZone, getZoneByPoint, updateSelectedRearZone } = require("%rGui/wwMap/wwMapZonesData.nut")
let mkMapZonesBackground = require("%rGui/wwMap/wwMapZonesBackground.nut")
let { mkMapZonesEdges, mkMapHoveredZone } = require("%rGui/wwMap/wwMapZonesEdges.nut")
let { mkMapFrontLine } = require("%rGui/wwMap/wwMapFrontLine.nut")
let { mkMapZoneNames } = require("%rGui/wwMap/wwMapZoneNames.nut")
let { mkSectorSprites } = require("%rGui/wwMap/wwMapSectorSprites.nut")
let { mkAirfields } = require("%rGui/wwMap/wwAirfields.nut")
let { mkArmies } = require("%rGui/wwMap/wwArmies.nut")
let { battles } = require("%rGui/wwMap/wwBattles.nut")
let { mkBattlesMessages } = require("%rGui/wwMap/wwBattlesMessages.nut")
let { artilleryStrikes } = require("%rGui/wwMap/wwArtilleryStrikes.nut")
let { samVisualizations } = require("%rGui/wwMap/wwSAMVisualizations.nut")
let { getBattleByPoint, updateHoveredBattle, updateSelectedBattle, hoveredBattle } = require("%rGui/wwMap/wwBattlesStates.nut")
let { getAirfieldByPoint, updateHoveredAirfield, updateSelectedAirfield, selectedAirfield } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { actionsLayer } = require("%rGui/wwMap/wwActionsLayer.nut")
let { haveActiveAction, doAction, moveArmy, sendAircraft } = require("%rGui/wwMap/wwActionManager.nut")
let { configurationLoaded, initConfiguration, invalidateConfiguration } = require("%rGui/wwMap/wwConfigurationInit.nut")
let { holderBounds, activeAreaBounds, getOperationMapImage, convertPointerCoords, convertPointerToMapCoords,
  getMapCellByCoords } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { startUpdates, stopUpdates, cursorPosition } = require("%rGui/wwMap/wwMapStates.nut")
let { sendToDagui } = require("%rGui/wwMap/wwMapUtils.nut")
let { mapCellUnderCursor, armyUnderCursor, mapCoordsUnderCursor } = require("%appGlobals/wwObjectsUnderCursor.nut")
let { deferOnce } = require("dagor.workcycle")


let backgroundColor = 0xFF1B2226
let transparentColor = 0x00000000
let cursorPositionRT = Watched(null)

let clearAllHovers = @() sendToDagui("ww.clearHovers")

function processPointerMove(evt, areaBounds) {
  if (!evt.hit) {
    updateHoveredZone(null)
    return
  }

  let pos = convertPointerCoords(evt, areaBounds)

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
  size = flex()
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
      processPointer(evt, activeAreaBounds.get())
    }

    function onPointerPress(evt) {
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
    size = [sw(100), sh(100)]
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