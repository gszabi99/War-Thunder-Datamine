import "DataBlock" as DataBlock
import "%rGui/style/fontsState.nut" as fontsState
from "%rGui/wwMap/wwMapStates.nut" import loadedTransport, isShiftPressed
from "%rGui/wwMap/wwOperationStates.nut" import isPlayerSide, isOperationPausedWatch
from "%rGui/wwMap/wwArmyGroups.nut" import getArmyGroupsInfo
from "%rGui/wwMap/wwOperationConfiguration.nut" import convertToRelativeMapCoords, activeAreaBounds, mapZoom
from "%rGui/wwMap/wwMapUtils.nut" import convertColor4, getMapColor
from "%rGui/wwMap/wwArmyStates.nut" import selectedArmy, hoveredArmy, getArmyIcon, armiesList, armiesData, isShowArmiesIndex, movingArmiesPositions
  , newPartOfArmyPath, getArmyByName
from "%appGlobals/worldWar/wwArtilleryStatus.nut" import artilleryReadyState
from "%rGui/wwMap/wwTransportUtils.nut" import isTransport, getLoadedArmyType
from "%appGlobals/worldWar/wwSettings.nut" import getSettings
from "%rGui/wwMap/wwUtils.nut" import calcAngleBetweenVectors, even
from "%rGui/wwMap/wwArtilleryStrikeStates.nut" import artilleryStrikesInfo, samStrikesInfo
from "%appGlobals/worldWar/wwMapFilters.nut" import isShowPathForSelectedArmyFilter
from "math" import sin, cos, PI, floor, sqrt
from "worldwar" import wwGetOperationTimeMillisec
from "dagor.workcycle" import resetTimeout, clearTimer
from "%rGui/globals/ui_library.nut" import *

let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")

let entrenchIconColors = {
  spriteColor = 0
  blinkColor = 0
}

let isMoving = @(army) army?.pathTracker.status == "ES_MOVING_BY_PATH"

function isOnlyMoved(prev, army) {
  if (!isMoving(prev) || !isMoving(army))
    return false
  let probe = DataBlock()
  probe.setFrom(army)
  probe.pathTracker.setPoint2("pos", prev.pathTracker.pos)
  return probe.isEqual(prev)
}


function getArmyPosNow(pathTracker) {
  let { status, nextPathIdx, path, pos } = pathTracker
  if (status != "ES_MOVING_BY_PATH" || nextPathIdx < 1)
    return pos
  let points = path.points % "item"
  let from = points[nextPathIdx - 1]
  let to = points[nextPathIdx]
  let k = (wwGetOperationTimeMillisec() - path.startTime - from.arrivalTimeShift).tofloat()
    / max(to.arrivalTimeShift - from.arrivalTimeShift, 1)
  return from.pos + (to.pos - from.pos) * clamp(k, 0, 1)
}

function mkArmyNewPartOfPath(areaBounds) {
  return function() {
    if (newPartOfArmyPath.get() == null || !isShiftPressed.get())
      return {
        watch = [newPartOfArmyPath, mapZoom, isShiftPressed]
      }
    let { areaWidth, areaHeight } = areaBounds
    let { armyName, newPos } = newPartOfArmyPath.get()
    local firstPoint
    let lastPoint = newPos

    let armyData = getArmyByName(armyName)
    if (armyData.pathTracker.status != "ES_MOVING_BY_PATH")
      firstPoint = convertToRelativeMapCoords(armyData.pathTracker.pos)
    else {
      let points = armyData.pathTracker.path.points % "item"
      let point = points[points.len() - 1]
      firstPoint = convertToRelativeMapCoords(point.pos)
    }

    let armySide = zoneSideType[armyData.owner.side]
    let arrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArmyColorArrowNew" : "enemiesArmyColorArrowNew")
    let endArrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArrowLastCircleColor" : "enemiesArrowLastCircleColor")
    let radius = even(armyData.specs.battleStartRadiusN * mapZoom.get())
    let arrowSize = 25

    let commands = [[VECTOR_LINE, 100 * firstPoint.x, 100 * firstPoint.y, 100 * lastPoint.x, 100 * lastPoint.y]]

    return {
      watch = [newPartOfArmyPath, mapZoom, isShiftPressed]
      rendObj = ROBJ_VECTOR_CANVAS
      color = arrowColor
      size = [areaWidth, areaHeight]
      lineWidth = 2 * radius
      commands
      children = {
        rendObj = ROBJ_BOX
        borderColor = arrowColor
        pos = [areaWidth * lastPoint.x - radius, areaHeight * lastPoint.y - radius]
        size = [2 * radius, 2 * radius]
        fillColor = endArrowColor
        borderWidth = hdpx(2)
        borderRadius = radius
        transform = {
          rotate = calcAngleBetweenVectors(lastPoint, firstPoint).deg
        }
        children = {
          rendObj = ROBJ_VECTOR_CANVAS
          size = FLEX
          color = arrowColor
          fillColor = arrowColor
          commands = [
            [VECTOR_POLY, arrowSize + 50, 50, -arrowSize * 0.5 + 50, arrowSize * 0.866 + 50, -arrowSize * 0.5 + 50, -arrowSize * 0.866 + 50]
          ]
        }
      }
    }
  }
}

function mkArmyPaths(armyWatch, areaBounds) {
  let hasPathTracker = Computed(@() armyWatch.get()?.pathTracker.status == "ES_MOVING_BY_PATH"
    && ([selectedArmy.get(), hoveredArmy.get()].contains(armyWatch.get().name) || !isShowPathForSelectedArmyFilter.get()))

  let isShowArrow = Computed(@() !(selectedArmy.get() == armyWatch.get()?.name) || (newPartOfArmyPath.get() == null || !isShiftPressed.get()))
  let pathLook = Computed(@(prev) isOnlyMoved(prev, armyWatch.get()) ? prev : armyWatch.get())

  return function() {
    let watch = [hasPathTracker, pathLook, mapZoom, isShowArrow, isOperationPausedWatch]
    if (!hasPathTracker.get())
      return { watch }
    let armyData = pathLook.get()
    let { areaWidth, areaHeight } = areaBounds
    let armySide = zoneSideType[armyData.owner.side]

    let arrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArmyColorArrow" : "enemiesArmyColorArrow")
    let endArrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArrowLastCircleColor" : "enemiesArrowLastCircleColor")
    let radius = even(armyData.specs.battleStartRadiusN * mapZoom.get())

    let { nextPathIdx, path } = armyData.pathTracker
    let points = (path.points % "item").slice(nextPathIdx)
    let preLastPoint = {}

    let firstPoint = convertToRelativeMapCoords(getArmyPosNow(armyData.pathTracker))
    let lastPoint = {}

    let lineIndent = [VECTOR_LINE_INDENT_PX, hdpx(4), 0]
    let command = points.reduce(function(res, p) {
      let nextPoint = convertToRelativeMapCoords(p.pos)
      res.append(100 * nextPoint.x, 100 * nextPoint.y)
      preLastPoint.__update(lastPoint)
      lastPoint.__update(nextPoint)
      return res
    }, [VECTOR_LINE])
    let arrowSize = 25
    if(preLastPoint.len() == 0)
      preLastPoint.__update(firstPoint)

    let nextPoint = convertToRelativeMapCoords(points[0].pos)
    let segment = { x = areaWidth * (nextPoint.x - firstPoint.x), y = areaHeight * (nextPoint.y - firstPoint.y) }
    let segmentLength = sqrt(segment.x * segment.x + segment.y * segment.y)
    let timeLeft = (points[0].arrivalTimeShift + path.startTime - wwGetOperationTimeMillisec()) / 1000.0
    let isPaused = isOperationPausedWatch.get()

    
    let currentSegment = {
      key = {}
      rendObj = ROBJ_VECTOR_CANVAS
      color = arrowColor
      pos = [areaWidth * nextPoint.x - segmentLength, areaHeight * nextPoint.y - radius]
      size = [segmentLength, 2 * radius]
      lineWidth = 2 * radius
      commands = [lineIndent, const [VECTOR_LINE, 0, 50, 100, 50]]
      transform = {
        pivot = const [1, 0.5]
        rotate = calcAngleBetweenVectors(segment).deg
        scale = [isPaused ? 1 : 0, 1]
      }
      animations = [{ prop = AnimProp.scale, from = const [1, 1], to = const [0, 1], duration = timeLeft, play = !isPaused }]
    }

    return {
      watch
      rendObj = ROBJ_VECTOR_CANVAS
      color = arrowColor
      size = [areaWidth, areaHeight]
      lineWidth = 2 * radius
      commands = points.len() > 1 ? [lineIndent, command] : null
      children = [currentSegment, isShowArrow.get() ? {
        rendObj = ROBJ_BOX
        borderColor = arrowColor
        pos = [areaWidth * lastPoint.x - radius, areaHeight * lastPoint.y - radius]
        size = [2 * radius, 2 * radius]
        fillColor = endArrowColor
        borderWidth = hdpx(2)
        borderRadius = radius
        transform = {
          rotate = calcAngleBetweenVectors(lastPoint, preLastPoint).deg
        }
        children = {
          rendObj = ROBJ_VECTOR_CANVAS
          size = FLEX
          color = arrowColor
          fillColor = arrowColor
          commands = [
            [VECTOR_POLY, arrowSize + 50, 50, -arrowSize * 0.5 + 50, arrowSize * 0.866 + 50, -arrowSize * 0.5 + 50, -arrowSize * 0.866 + 50]
          ]
        }
      }
      : null]
    }
  }
}

let mkArmyEntrenchIcon = @(armyData, areaBounds, mpZoom) function() {
  let { iconName, blinkPeriod } = getSettings("entrenchIcon")
  let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
  let endBlinkTime = armyData.entrenchEndMillisec

  if (endBlinkTime == 0)
    return null

  let isBlinking = endBlinkTime > wwGetOperationTimeMillisec()
  let { areaWidth, areaHeight } = areaBounds
  let entrenchIconWidth = even(armyData.specs.battleStartRadiusN * mpZoom * 2.2)
  let entrenchIconHeight = floor(entrenchIconWidth * 36 / 32)
  let pos = [areaWidth * armyPos.x - entrenchIconWidth / 2, areaHeight * armyPos.y - entrenchIconHeight / 2 + hdpx(1.5)]
  let duration = (endBlinkTime - wwGetOperationTimeMillisec()) / 1000.0
  let blinkTrigger = $"entrench_{armyData.name}"

  return {
    key = $"{blinkTrigger}_{endBlinkTime}"
    rendObj = ROBJ_IMAGE
    pos
    size = [entrenchIconWidth, entrenchIconHeight]
    subPixel = true
    image = Picture($"{iconName}:{entrenchIconWidth}:{entrenchIconHeight}")
    color = entrenchIconColors.spriteColor
    animations = [{ prop = AnimProp.color, from = entrenchIconColors.blinkColor, to = entrenchIconColors.spriteColor,
      duration = blinkPeriod, loop = true, easing = CosineFull, play = isBlinking, trigger = blinkTrigger,
      globalTimer = true }]
    onAttach = isBlinking ? @() resetTimeout(duration, @() anim_request_stop(blinkTrigger), blinkTrigger) : null
    onDetach = isBlinking ? @() clearTimer(blinkTrigger) : null
  }
}

let mkArmyIcon = @(armyData) function() {
  let icon = getArmyIcon(armyData)
  let armyIconSize = even(armyData.specs.battleStartRadiusN * mapZoom.get() * 1.7)
  let readyState = artilleryReadyState.get()?[armyData.name] ?? true
  local iconName = readyState ? icon?.iconNameReady ?? icon.iconName : icon.iconName

  if (loadedTransport.get() != null && isTransport(armyData)) {
    let loadedArmyType = getLoadedArmyType(armyData, loadedTransport.get())
    if (loadedArmyType == "UT_INFANTRY")
      iconName = icon.iconNameLoadedInfantry
    else if (loadedArmyType == "UT_ARTILLERY")
      iconName = icon.iconNameLoadedArtillery
    else if (loadedArmyType == "UT_GROUND")
      iconName = icon.iconNameLoadedGround
  }

  let { groupIdxs = [], isShow = false } = isShowArmiesIndex.get()

  return {
    watch = [artilleryReadyState, loadedTransport, isShowArmiesIndex, mapZoom]
    rendObj = ROBJ_IMAGE
    subPixel = true
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    size = armyIconSize
    image = Picture($"{iconName}:{armyIconSize}:{armyIconSize}")
    color = Color(0, 0, 0)
    transform = {
      rotate = icon?.iconRotate ?? 0
    }
    children = isShow && groupIdxs.contains(armyData.owner.armyGroupIdx)
      ? {
          padding = const [hdpx(2), 0, 0, hdpx(2)]
          vplace = ALIGN_CENTER
          hplace = ALIGN_CENTER
          rendObj = ROBJ_TEXT
          subPixel = true
          text = armyData.owner.armyGroupIdx
          color = getMapColor("armyGroupTextColor")
          font = fontsState.get("bigBold")
          fontSize = armyIconSize
        }
      : null
  }
}

let samTargetNames = Computed(@() samStrikesInfo.get().map(@(s) s.forcedTargetArmyName))

function onArmyMove(x, armyName, from, to) {
  if (!samTargetNames.get().contains(armyName))
    return x
  let deltaX = to.x - from.x
  let deltaY = to.y - from.y
  movingArmiesPositions.mutate(@(t) t[armyName] <- { x = (from.x + deltaX * x), y = (from.y + deltaY * x) })
  return x
}

function onArmyMoveFinish(armyName) {
  if (armyName in movingArmiesPositions.get())
    movingArmiesPositions.mutate(@(t) t.$rawdelete(armyName))
}

function mkArmyBack(armyData, areaBounds, isArmySelected, isArmyHovered, isPaused) {
  return function() {
    let children = []
    let animations = []
    let armyGroupsInfo = getArmyGroupsInfo()
    let armyPos = convertToRelativeMapCoords(getArmyPosNow(armyData.pathTracker))
    let armySide = zoneSideType[armyData.owner.side]
    let { areaWidth, areaHeight } = areaBounds
    let armyBorderSize = even(armyData.specs.battleStartRadiusN * mapZoom.get()) * 2
    let armyBorderPos = [areaWidth * armyPos.x - armyBorderSize / 2, areaHeight * armyPos.y - armyBorderSize / 2]
    local translate = armyBorderPos
    local borderColor = getMapColor("armyOutlineColor")

    let { groupIdxs = [], isShow = false } = isShowArmiesIndex.get()

    if (isArmySelected.get())
      borderColor = getMapColor("selectedArmyOutlineColor")
    else if (isArmyHovered.get() || (isShow && groupIdxs.contains(armyData.owner.armyGroupIdx)))
      borderColor = Color(240, 240, 240)

    let fillColorKey = !isPlayerSide(armySide) ? "enemiesArmyColor"
      : armyGroupsInfo[armyData.owner.armyGroupIdx].side == armyData.owner.side ? "ownedArmyColor"
      : "alliesArmyColor"

    let fillColor = getMapColor(fillColorKey)
    let arrowSize = even(armyData.specs.battleStartRadiusN * mapZoom.get())

    if (armyData.pathTracker.status == "ES_MOVING_BY_PATH") {
      let nextPathIdx = armyData.pathTracker.nextPathIdx
      let points = armyData.pathTracker.path.points % "item"
      let nextPoint = points[nextPathIdx]
      let timeLeft = (nextPoint.arrivalTimeShift + armyData.pathTracker.path.startTime - wwGetOperationTimeMillisec()) / 1000.0
      let nextPointPos = convertToRelativeMapCoords(nextPoint.pos)
      let nextArmyPos = [areaWidth * nextPointPos.x - armyBorderSize / 2, areaHeight * nextPointPos.y - armyBorderSize / 2]
      animations.append({ prop = AnimProp.translate, from = armyBorderPos, to = nextArmyPos, duration = timeLeft,
        play = !isPaused, easing = @(x) onArmyMove(x, armyData.name, armyPos, nextPointPos),
        onFinish = @() onArmyMoveFinish(armyData.name) })
      if (!isPaused)
        translate = nextArmyPos 

      if (!isArmySelected.get() && !isArmyHovered.get()) {
        let pointTo = { x = points[nextPathIdx].pos.x - armyData.pathTracker.pos.x, y = points[nextPathIdx].pos.y - armyData.pathTracker.pos.y }
        let angle = calcAngleBetweenVectors(pointTo).rad

        const delta = PI * 30 / 180
        let point0 = { x = cos(angle), y = sin(angle) }
        let point1 = { x = cos(angle - delta), y = sin(angle - delta) }
        let point2 = { x = cos(angle + delta), y = sin(angle + delta) }

        let r = floor(100 * (armyBorderSize / 2) / (armyBorderSize / 2 + hdpx(2)))
        let commands = [[VECTOR_POLY,
          r * 1.7 * point0.x, r * 1.7 * point0.y,
          r * point1.x, r * point1.y,
          r * point0.x, r * point0.y,
          r * point2.x, r * point2.y]]

        children.append({
          rendObj = ROBJ_VECTOR_CANVAS
          subPixel = true
          color = borderColor
          pos = [armyBorderSize / 2, armyBorderSize / 2]
          size = arrowSize
          fillColor
          lineWidth = hdpx(2)
          commands
        })
      }
    }

    children.append({
      rendObj = ROBJ_BOX
      subPixel = true
      borderColor
      size = armyBorderSize
      fillColor
      borderWidth = hdpx(2)
      borderRadius = armyBorderSize / 2
    })

    children.append(mkArmyIcon(armyData))

    return {
      watch = [isArmySelected, isArmyHovered, isShowArmiesIndex, mapZoom]
      key = {}
      children
      transform = {
        translate
      }
      animations
    }
  }
}

let mkArtilleryFire = @(armyData, areaBounds, armyStrike) function() {
  if(!armyStrike.get())
    return {
      watch = [armyStrike, mapZoom]
    }

  let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
  let armySize = even(armyData.specs.battleStartRadiusN * mapZoom.get()) * 2

  let fireIconSize = armySize
  let { areaWidth, areaHeight } = areaBounds
  let armyIconPos = [areaWidth * armyPos.x + armySize / 2 - hdpx(7) , areaHeight * armyPos.y - armySize - hdpx(1)]

  return {
    watch = [armyStrike, mapZoom]
    rendObj = ROBJ_IMAGE
    keepAspect = true
    pos = armyIconPos
    size = fireIconSize
    image = Picture($"{getSettings("artilleryStrike").fireTexture}:{fireIconSize}:{fireIconSize}")
    color = Color(255, 0, 0, 192)
  }
}

function mkArmy(armyWatch, areaBounds) {
  let armyStrike = Computed(@() artilleryStrikesInfo.get().findindex(@(as) as.army.name == armyWatch.get()?.name) != null)
  let isArmySelected = Computed(@() selectedArmy.get() == armyWatch.get()?.name)
  let isArmyHovered = Computed(@() hoveredArmy.get() == armyWatch.get()?.name)
  
  let armyLook = Computed(function(prev) {
    let army = armyWatch.get()
    return (isOnlyMoved(prev, army) && army.entrenchEndMillisec == 0 && !armyStrike.get()) ? prev : army
  })
  return function() {
    let armyData = armyLook.get()

    return {
      watch = [armyLook, mapZoom, isOperationPausedWatch]
      children = [
        mkArmyEntrenchIcon(armyData, areaBounds, mapZoom.get()),
        mkArtilleryFire(armyData, areaBounds, armyStrike),
        mkArmyBack(armyData, areaBounds, isArmySelected, isArmyHovered, isOperationPausedWatch.get())
      ]
    }
  }
}

let mkArmies = function() {
  if (armiesList.get().len() == 0)
    return {
      watch = armiesList
    }
  let { spriteColor, blinkColor } = getSettings("entrenchIcon")
  entrenchIconColors.spriteColor = convertColor4(spriteColor)
  entrenchIconColors.blinkColor = convertColor4(blinkColor)

  let armies = armiesData.get()
    .map(@(_army, idx) mkArmy(Computed(@() armiesData.get()?[idx]), activeAreaBounds.get()))

  let armiesPaths = armiesData.get()
    .map(@(_army, idx) mkArmyPaths(Computed(@() armiesData.get()?[idx]), activeAreaBounds.get()))


  let children = armiesPaths
  children.append(mkArmyNewPartOfPath(activeAreaBounds.get()))
  children.extend(armies)
  return {
    watch = [armiesList, activeAreaBounds]
    size = activeAreaBounds.get().size
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children
  }
}

return freeze({
  mkArmies
})
