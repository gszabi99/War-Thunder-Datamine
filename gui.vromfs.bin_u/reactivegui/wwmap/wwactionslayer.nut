from "%rGui/globals/ui_library.nut" import *

let { floor, pow } = require("math")
let { wwArtilleryGetAttackRadius, wwArtillerySetAttackRadius, wwCanUnloadArmyFromTransport } = require("worldwar")
let { artilleryReadyToStrike, artilleryAttackRaduis } = require("%rGui/wwMap/wwArtilleryStrikeStates.nut")
let { getSettings, getSettingsArray } = require("%appGlobals/worldWar/wwSettings.nut")
let { getMapColor, convertColor4 } = require("%rGui/wwMap/wwMapUtils.nut")
let { getArtilleryParams } = require("%rGui/wwMap/wwArtilleryUtils.nut")
let { convertAbsoluteToMapCoords, convertToRelativeMapCoords
  getMapCellByCoords, activeAreaBounds, mapZoom } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { hoveredArmy, getArmyIcon, getArmyByName } = require("%rGui/wwMap/wwArmyStates.nut")
let { isPlayerSide, isOperationPausedWatch } = require("%rGui/wwMap/wwOperationStates.nut")
let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")
let { transportReadyToUnload, transportReadyToLoad, getLoadedArmyName, getLoadedArmy } = require("%rGui/wwMap/wwTransportUtils.nut")
let { loadedTransport, cursorPosition } = require("%rGui/wwMap/wwMapStates.nut")
let { getArmyGroupsInfo } = require("%rGui/wwMap/wwArmyGroups.nut")
let { selectedAirfield } = require("%rGui/wwMap/wwAirfieldsStates.nut")
let { getZoneById } = require("%rGui/wwMap/wwMapZonesData.nut")
let { calcAngleBetweenVectors, even } = require("%rGui/wwMap/wwUtils.nut")
let { artilleryReadyState } = require("%appGlobals/worldWar/wwArtilleryStatus.nut")

let partSize = hdpx(20)

let distSq = @(p1, p2) (p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y)

function lineLength(p1, p2, size) {
  let from = { x = p1.x * size[0], y = p1.y * size[1] }
  let to = { x = p2.x * size[0], y = p2.y * size[1] }
  return pow(distSq(from, to), 0.5)
}

function inRange(armyPos, r1, r2, cursorPos) {
  let dist = distSq(armyPos, cursorPos)
  return dist >= r1 * r1 && dist <= r2 * r2
}

function mkArtilleryCursorPart(data, cursorTexture) {
  let { pos, rotate, color } = data

  return {
    rendObj = ROBJ_IMAGE
    size = [partSize, partSize]
    pos
    color
    image = Picture($"{cursorTexture}:{partSize}:{partSize}")
    transform = {
      pivot = [0.5, 0.5]
      rotate
    }
  }
}

function artilleryCursor() {
  if (artilleryReadyToStrike.get() == null)
    return {
      watch = [artilleryReadyToStrike]
    }

  let armyData = artilleryReadyToStrike.get()
  let artillery = getArtilleryParams(armyData)
  let { x, y } = convertAbsoluteToMapCoords(cursorPosition.get(), activeAreaBounds.get())
  let { cursorMinColor, cursorActiveColor, cursorDisabledColor, cursorTexture } = getSettings("artilleryStrike")
  let radiusCursorMin = floor(artillery.attackRadiusAtMinDist * mapZoom.get())
  let radius = floor(artilleryAttackRaduis.get() * mapZoom.get())

  let colorMin = convertColor4(cursorMinColor)
  let armyPos = { x = armyData.pathTracker.pos.x * mapZoom.get(), y = armyData.pathTracker.pos.y * mapZoom.get() }
  let radiusMin = floor(artillery.minAttackRange * mapZoom.get())
  let radiusMax = floor(artillery.maxAttackRange * mapZoom.get())
  let isFriendlyFire = isPlayerSide(zoneSideType[hoveredArmy.get()?.owner.side ?? "SIDE_NONE" ])
  let isArtilleryReady = artilleryReadyState.get()?[armyData.name] ?? true
  let isInAllowedRange = inRange(armyPos, radiusMin, radiusMax, {x, y})
  let color = convertColor4((!isFriendlyFire && isInAllowedRange && isArtilleryReady) ? cursorActiveColor
    : cursorDisabledColor)

  let parts = [
    { pos = [-partSize/2, -partSize - radius + hdpx(6)], rotate = 0, color },
    { pos = [radius - hdpx(6), -partSize/2], rotate = 90, color },
    { pos = [-partSize/2, radius - hdpx(6)], rotate = 180, color },
    { pos = [-partSize - radius + hdpx(6), -partSize/2], rotate = 270, color },
    { pos = [-partSize/2, -partSize - radiusCursorMin + hdpx(6)], rotate = 0, color = colorMin },
    { pos = [radiusCursorMin - hdpx(6), -partSize/2], rotate = 90, color = colorMin },
    { pos = [-partSize/2, radiusCursorMin - hdpx(6)], rotate = 180, color = colorMin },
    { pos = [-partSize - radiusCursorMin + hdpx(6), -partSize/2], rotate = 270, color = colorMin }
  ]

  return {
    watch = [cursorPosition, artilleryReadyToStrike, artilleryAttackRaduis, hoveredArmy, artilleryReadyState, mapZoom, activeAreaBounds]
    pos = [x, y]
    children = parts.map(@(p) mkArtilleryCursorPart(p, cursorTexture))
  }
}

function transportUnloadCursor() {
  let armyName = transportReadyToUnload.get()
  if (armyName == null)
    return {
      watch = [transportReadyToUnload, cursorPosition]
    }

  let armyData = getArmyByName(armyName)

  let { x, y } = convertAbsoluteToMapCoords(cursorPosition.get(), activeAreaBounds.get())
  let cellIdx = getMapCellByCoords(cursorPosition.get().x, cursorPosition.get().y,activeAreaBounds.get())
  let loadedArmyName = getLoadedArmyName(armyData, loadedTransport.get())
  let canUnload = wwCanUnloadArmyFromTransport(armyData.name, loadedArmyName, cellIdx)
  let armyPos = { x = armyData.pathTracker.pos.x * mapZoom.get(), y = armyData.pathTracker.pos.y * mapZoom.get() }
  let armySize = floor(armyData.specs.battleStartRadiusN * mapZoom.get())
  let radiusMax = floor(armyData.specs.transportInfo.loadDistance * mapZoom.get())
  let isInAllowedRange = inRange(armyPos, armySize, radiusMax, {x, y})

  let borderColor = (isInAllowedRange && canUnload) ? getMapColor("unloadPossibleCursorOutlineColor")
    : getMapColor("unloadImpossibleCursorOutlineColor")

  let armySide = zoneSideType[armyData.owner.side ?? "SIDE_NONE"]

  let fillColor = !isPlayerSide(armySide) ? "enemiesArmyColor"
    : getArmyGroupsInfo()[armyData.owner.armyGroupIdx].side == armyData.owner.side ? "ownedArmyColor"
    : "alliesArmyColor"

  let loadedArmy = getLoadedArmy(armyData, loadedTransport.get())
  let icon = getArmyIcon(loadedArmy)
  let armyIconSize = floor(icon.iconSize * mapZoom.get())
  let armyIconName = $"{icon.iconName}:{armyIconSize}:{armyIconSize}"

  return {
    watch = [cursorPosition, transportReadyToUnload, hoveredArmy, loadedTransport, mapZoom, activeAreaBounds]
    pos = [x - armySize, y - armySize]
    size = [2 * armySize, 2 * armySize]
    rendObj = ROBJ_BOX
    borderColor
    borderWidth = hdpx(2)
    fillColor = getMapColor(fillColor)
    borderRadius = armySize
    children = {
      rendObj = ROBJ_IMAGE
      color = Color(0, 0, 0)
      image = Picture(armyIconName)
      vplace = ALIGN_CENTER
      hplace = ALIGN_CENTER
      size = [armyIconSize, armyIconSize]
    }
  }
}

function mkActionCircle(pos, r1, r2) {
  let lineWidth = r2 - r1
  let actualRadius = r1 + lineWidth / 2
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = [actualRadius, actualRadius]
    pos = [pos[0] - actualRadius / 2, pos[1] - actualRadius / 2]
    lineWidth
    color = Color(0, 0, 0, 128)
    subPixel = true
    fillColor = 0
    commands = [
      [VECTOR_ELLIPSE, 50, 50, 100, 100]
    ]
  }
}

let mkArtilleryStrikeCircles = @(areaBounds) function() {
  let armyData = artilleryReadyToStrike.get()
  if (armyData == null)
    return {
      watch = artilleryReadyToStrike
    }

  let { areaWidth, areaHeight } = areaBounds
  let artillery = getArtilleryParams(armyData)
  let armySize = even(armyData.specs.battleStartRadiusN * mapZoom.get())
  let radiusMin = even(artillery.minAttackRange * mapZoom.get())
  let radiusMax = even(artillery.maxAttackRange * mapZoom.get())
  let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
  let pos = [areaWidth * armyPos.x, areaHeight * armyPos.y]
  return {
    watch = [artilleryReadyToStrike, mapZoom]
    size = flex()
    children = [
      mkActionCircle(pos, armySize, radiusMin),
      mkActionCircle(pos, radiusMax, 2 * areaHeight)
    ]
  }
}

let mkTransportCircles = @(areaBounds) function() {
  let armyName = transportReadyToUnload.get() ?? transportReadyToLoad.get()
  if (armyName == null)
    return {
      watch = [transportReadyToUnload, transportReadyToLoad]
    }

  let armyData = getArmyByName(armyName)

  let { areaWidth, areaHeight } = areaBounds
  let armySize = even(armyData.specs.battleStartRadiusN * mapZoom.get())
  let radiusMax = even(armyData.specs.transportInfo.loadDistance * mapZoom.get())
  let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
  let pos = [areaWidth * armyPos.x, areaHeight * armyPos.y]
  return {
    watch = [transportReadyToUnload, transportReadyToLoad, mapZoom]
    size = flex()
    children = [
      mkActionCircle(pos, armySize, armySize),
      mkActionCircle(pos, radiusMax, 2 * areaHeight)
    ]
  }
}

let mkArmyIcon = @(airfieldType, armyPos, armySize, armyAngle, color, fillColor) function() {
  let borderWidth = hdpx(2)
  armySize -= borderWidth

  let isHelicopter = airfieldType == "AT_HELIPAD"

  let iconName = isHelicopter ? getSettingsArray("armyIconCustom").findvalue(@(v) v.name == "helicopter")?.iconName ?? ""
    : getSettings("armyIconAir").iconName

  return {
    rendObj = ROBJ_BOX
    borderColor = color
    pos = [armyPos.x - armySize / 2, armyPos.y - armySize / 2]
    size = [armySize, armySize]
    fillColor = getMapColor(fillColor)
    borderWidth
    borderRadius = armySize / 2
    children = [
      {
        rendObj = ROBJ_IMAGE
        keepAspect = true
        size = [armySize, armySize]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        image = Picture($"{iconName}:{armySize}:{armySize}")
        color = Color(0, 0, 0)
        transform = {
          rotate = isHelicopter ? 0 : (armyAngle - 90)
        }
      }
    ]
  }
}

function mkArmyArrow(arrowPos, radius, arrowAngle, color, fillColor) {
  let borderWidth = hdpx(2)
  let arrowSize = 2 * radius + borderWidth / 2

  return {
    rendObj = ROBJ_BOX
    borderColor = color
    pos = [arrowPos.x - arrowSize / 2, arrowPos.y - arrowSize / 2]
    size = [arrowSize, arrowSize]
    fillColor
    borderWidth
    borderRadius = arrowSize / 2
    transform = {
      rotate = arrowAngle + 180
    }
    children = [
      {
        rendObj = ROBJ_VECTOR_CANVAS
        size = flex()
        color
        fillColor = color
        commands = [
          [VECTOR_POLY, radius + 50, 50, -radius * 0.5 + 50, radius * 0.866 + 50, -radius * 0.5 + 50, -radius * 0.866 + 50]
        ]
      }
    ]
  }
}

let mkFlyOutArrow = @(areaBounds) function() {
  let airfield = selectedAirfield.get()
  let { areaWidth, areaHeight } = areaBounds
  let posTo = convertAbsoluteToMapCoords(cursorPosition.get(), areaBounds)
  posTo.x = posTo.x / areaWidth
  posTo.y = posTo.y / areaHeight

  let isPointerInMap = (posTo.x > 0 && posTo.x < 1) && (posTo.y > 0 && posTo.y < 1)
  if (airfield == null || isOperationPausedWatch.get() || !isPlayerSide(zoneSideType[airfield.side]) || !isPointerInMap)
    return {
      watch = [cursorPosition, selectedAirfield, isOperationPausedWatch, mapZoom]
    }

  let { airfieldType, ownedZoneId } = airfield
  let ownedZone = getZoneById(ownedZoneId)
  let posFrom = { x = ownedZone.center.x, y = ownedZone.center.y }
  let airfieldArrowArmyShowK = getSettings("airfieldArrowArmyShowK")
  let lineLen = lineLength(posFrom, posTo, [areaWidth, areaHeight])
  let radius = getSettings("airfieldArrowFirstCircleRadius") * mapZoom.get()
  let color = Color(255, 228, 81, 255)
  let isArmyShow = lineLen > radius * 2 * airfieldArrowArmyShowK
  let armyPos = { x = areaWidth * (posFrom.x + posTo.x) / 2, y = areaHeight * (posFrom.y + posTo.y) / 2 }
  let armyAngle = calcAngleBetweenVectors(posFrom, posTo).deg
  let fillColor = "ownedArmyColor"
  let armySize = floor(getSettings("airfieldArrowArmySize") * mapZoom.get()) * 2
  let arrowPos = { x = areaWidth * posTo.x, y = areaHeight * posTo.y }

  return {
    watch = [cursorPosition, selectedAirfield, isOperationPausedWatch, mapZoom]
    rendObj = ROBJ_VECTOR_CANVAS
    size = flex()
    lineWidth = radius * 2
    color
    commands = [
      [VECTOR_LINE, 100 * posFrom.x, 100 * posFrom.y, 100 * posTo.x, 100 * posTo.y]
    ]
    children = [
       isArmyShow ? mkArmyIcon(airfieldType, armyPos, armySize, armyAngle, color, fillColor) : null,
       mkArmyArrow(arrowPos, radius, armyAngle, color, Color(255, 255, 225, 255))
    ]
  }
}

let actionsLayer = @() {
  watch = activeAreaBounds
  behavior = Behaviors.TrackMouse
  size = activeAreaBounds.get().size
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  children = [
    mkArtilleryStrikeCircles(activeAreaBounds.get()),
    artilleryCursor,
    mkTransportCircles(activeAreaBounds.get()),
    transportUnloadCursor,
    mkFlyOutArrow(activeAreaBounds.get())
  ]

  function onMouseWheel(evt) {
    wwArtillerySetAttackRadius(wwArtilleryGetAttackRadius() + 0.1 * evt.button)
    artilleryAttackRaduis.set(wwArtilleryGetAttackRadius())
  }
}

return {
  actionsLayer
}
