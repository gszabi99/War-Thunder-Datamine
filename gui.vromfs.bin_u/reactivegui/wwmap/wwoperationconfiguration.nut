from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { floor } = require("math")
let extWatched = require("%rGui/globals/extWatched.nut")
let { parseZones, getZoneSize } = require("%rGui/wwMap/wwMapZonesData.nut")
let { getMapsDirName } = require("%appGlobals/worldWar/wwSettings.nut")
let { clearArmyGroupsInfo } = require("%rGui/wwMap/wwArmyGroups.nut")
let { wwGetOperationMapName } = require("worldwar")
let operationBlk = DataBlock()

let isOperationDataLoaded = Watched(false)
let currentMapBounds = extWatched("currentMapBounds", null)

let getOperationMapImage = @() $"!ui/images/wwmap/{operationBlk.map_image}"
let getMapSize = @() { width = operationBlk.getReal("map_w", 1.0), height = operationBlk.getReal("map_h", 1.0) }
let getCellSize = @() operationBlk.getReal("cell_sz", 1.0)
let getMapAspectRatio = @() operationBlk.getReal("map_h", 1.0) / operationBlk.getReal("map_w", 1.0)

let holderBounds = keepref(Computed(function() {
  let mapBounds = currentMapBounds.get()
  if(!isOperationDataLoaded.get() || mapBounds == null)
    return null

  let { pos, size } = mapBounds
  return { holderPosX = pos[0], holderPosY = pos[1], holderWidth = size[0], holderHeight = size[1] }
}))

let activeAreaBounds = keepref(Computed(function() {
  if (holderBounds.get() == null)
    return {
      areaX = 0
      areaY = 0
      areaWidth = 0
      areaHeight = 0
      size = 0
      rectangleArea = [0, 0]
    }

  let aspectRatio = getMapAspectRatio()
  let { holderPosX, holderPosY, holderWidth, holderHeight } = holderBounds.get()
  local areaWidth = holderWidth
  local areaHeight = areaWidth * aspectRatio

  if (areaHeight > holderHeight) {
    areaHeight = holderHeight
    areaWidth = floor(areaHeight / aspectRatio)
  }

  let areaX = holderPosX + (holderWidth - areaWidth) / 2
  let areaY = holderPosY + (holderHeight - areaHeight) / 2

  return {
    areaX
    areaY
    areaWidth
    areaHeight
    size = [areaWidth, areaHeight]
    rectangleArea = [areaWidth, areaWidth]
  }
}))

let gridWidth = keepref(Computed(function() {
  if(!isOperationDataLoaded.get() || activeAreaBounds.get() == null)
    return 1
  return max(1, floor(getZoneSize().w * activeAreaBounds.get().areaWidth * 0.0443951))
}))

let mapZoom = keepref(Computed(function() {
  if (holderBounds.get() == null)
    return null

  let { holderWidth, holderHeight } = holderBounds.get()
  let mapSize = getMapSize()
  return min(holderWidth / mapSize.width, holderHeight / mapSize.height)
}))

function loadOperationData() {
  let mapName = wwGetOperationMapName()
  let mapsDirName = getMapsDirName()
  if(mapsDirName == null)
    return
  let mapBlkName = $"{mapsDirName}/{mapName}.blk"
  let loadRes = operationBlk.tryLoad(mapBlkName)
  if(loadRes) {
    parseZones(operationBlk.zones)
    clearArmyGroupsInfo()
  }
  isOperationDataLoaded.set(loadRes)
}

function convertPointerCoords(pos, areaBounds) {
  let { areaX, areaY, areaWidth, areaHeight } = areaBounds
  return {
    x = (pos.x - areaX) / areaWidth
    y = (pos.y - areaY) / areaHeight
  }
}

function convertAbsoluteToMapCoords(pos, areaBounds) {
  let { x = 0, y = 0 } = pos
  let { areaX, areaY } = areaBounds
  return {
    x = x - areaX
    y = y - areaY
  }
}

function convertMapToAbsoluteCoords(pos) {
  let { x = 0, y = 0 } = pos
  let zoom = mapZoom.get()
  return {
    x = x * zoom
    y = y * zoom
  }
}

function convertToRelativeMapCoords(pos) {
  let mapSize = getMapSize()
  return {
    x = pos.x / mapSize.width
    y = pos.y / mapSize.height
  }
}

function getMapCellByCoords(x, y, areaBounds) {
  let { width, height } = getMapSize()
  let cellSize = getCellSize()
  local zoom = mapZoom.get()

  let coords = convertAbsoluteToMapCoords({ x, y }, areaBounds)
  let mapCoords = {
    x = coords.x / zoom
    y = coords.y / zoom
  }

  if(mapCoords.x >= width || mapCoords.y >= height || mapCoords.x < 0 || mapCoords.y < 0)
    return -1

  let cellX = floor(mapCoords.x / cellSize)
  let cellY = floor(mapCoords.y / cellSize)

  return (cellY * width / cellSize + cellX).tointeger()
}

function convertPointerToMapCoords(pos, areaBounds) {
  local zoom = mapZoom.get()

  let coords = convertAbsoluteToMapCoords(pos, areaBounds)
  return {
    x = coords.x / zoom
    y = coords.y / zoom
  }
}

return {
  convertPointerCoords
  convertAbsoluteToMapCoords
  loadOperationData
  holderBounds
  activeAreaBounds
  getOperationMapImage
  mapZoom
  getMapSize
  convertMapToAbsoluteCoords
  convertToRelativeMapCoords
  getMapAspectRatio
  getMapCellByCoords
  convertPointerToMapCoords
  isOperationDataLoaded
  gridWidth
}