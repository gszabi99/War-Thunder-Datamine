from "%rGui/globals/ui_library.nut" import *

let { sin, cos, PI, floor } = require("math")
let { wwGetOperationTimeMillisec } = require("worldwar")
let { loadedTransport, isShiftPressed } = require("%rGui/wwMap/wwMapStates.nut")
let { isPlayerSide, isOperationPausedWatch } = require("%rGui/wwMap/wwOperationStates.nut")
let { getArmyGroupsInfo } = require("%rGui/wwMap/wwArmyGroups.nut")
let { zoneSideType } = require("%rGui/wwMap/wwMapTypes.nut")
let { convertToRelativeMapCoords, activeAreaBounds, mapZoom } = require("%rGui/wwMap/wwOperationConfiguration.nut")
let { convertColor4, getMapColor } = require("%rGui/wwMap/wwMapUtils.nut")
let { selectedArmy, hoveredArmy, getArmyIcon, armiesList, armiesData, isShowArmiesIndex,
  movingArmiesPositions, newPartOfArmyPath, getArmyByName } = require("%rGui/wwMap/wwArmyStates.nut")
let { artilleryReadyState } = require("%appGlobals/worldWar/wwArtilleryStatus.nut")
let { isTransport, getLoadedArmyType } = require("%rGui/wwMap/wwTransportUtils.nut")
let { getSettings } = require("%appGlobals/worldWar/wwSettings.nut")
let { calcAngleBetweenVectors, even } = require("%rGui/wwMap/wwUtils.nut")
let { artilleryStrikesInfo } = require("%rGui/wwMap/wwArtilleryStrikeStates.nut")
let fontsState = require("%rGui/style/fontsState.nut")
let { setTimeout } = require("dagor.workcycle")
let { isShowPathForSelectedArmyFilter } = require("%appGlobals/worldWar/wwMapFilters.nut")

let entrenchIconColors = {
  spriteColor = 0
  blinkColor = 0
}

let function mkArmyNewPartOfPath(areaBounds) {
  return function() {
    if (newPartOfArmyPath.get() == null || !isShiftPressed.get())
      return {
        watch = [newPartOfArmyPath, mapZoom, isShiftPressed]
      }
    let { areaWidth, areaHeight } = areaBounds
    let { armyName, newPos } = newPartOfArmyPath.get()
    local firstPoint = { x = 0, y = 0 }
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
          size = flex()
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

let function mkArmyPaths(armyWatch, areaBounds) {
  let hasPathTracker = Computed(@() armyWatch.get()?.pathTracker.status == "ES_MOVING_BY_PATH"
    && ([selectedArmy.get(), hoveredArmy.get()].contains(armyWatch.get().name) || !isShowPathForSelectedArmyFilter.get()))

  let isShowArrow = Computed(@() !(selectedArmy.get() == armyWatch.get()?.name) || (newPartOfArmyPath.get() == null || !isShiftPressed.get()))

  return function() {
    if (!hasPathTracker.get())
      return {
        watch = [hasPathTracker, armyWatch, mapZoom, isShowArrow]
      }
    let armyData = armyWatch.get()
    let { areaWidth, areaHeight } = areaBounds
    let armySide = zoneSideType[armyData.owner.side]

    let arrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArmyColorArrow" : "enemiesArmyColorArrow")
    let endArrowColor = getMapColor(isPlayerSide(armySide) ? "alliesArrowLastCircleColor" : "enemiesArrowLastCircleColor")
    let radius = even(armyData.specs.battleStartRadiusN * mapZoom.get())

    let nextPathIdx = armyData.pathTracker.nextPathIdx
    let points = (armyData.pathTracker.path.points % "item").slice(nextPathIdx)
    let preLastPoint = {}

    let firstPoint = convertToRelativeMapCoords(armyData.pathTracker.pos)
    let lastPoint = {}

    let commands = [[VECTOR_LINE_INDENT_PX, hdpx(4), 0]]
    let command = points.reduce(function(res, p) {
      let nextPoint = convertToRelativeMapCoords(p.pos)
      res.append(100 * nextPoint.x, 100 * nextPoint.y)
      preLastPoint.__update(lastPoint)
      lastPoint.__update(nextPoint)
      return res
    }, [VECTOR_LINE, 100 * firstPoint.x, 100 * firstPoint.y])
    let arrowSize = 25
    commands.append(command)
    if(preLastPoint.len() == 0)
      preLastPoint.__update(firstPoint)

    return {
      watch = [hasPathTracker, armyWatch, mapZoom, isShowArrow]
      rendObj = ROBJ_VECTOR_CANVAS
      color = arrowColor
      size = [areaWidth, areaHeight]
      lineWidth = 2 * radius
      commands = commands
      children = isShowArrow.get() ? {
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
          size = flex()
          color = arrowColor
          fillColor = arrowColor
          commands = [
            [VECTOR_POLY, arrowSize + 50, 50, -arrowSize * 0.5 + 50, arrowSize * 0.866 + 50, -arrowSize * 0.5 + 50, -arrowSize * 0.866 + 50]
          ]
        }
      }
      : null
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
  let duration = (endBlinkTime - wwGetOperationTimeMillisec()) / 1000
  if (isBlinking)
    setTimeout(duration, @() anim_request_stop($"entrench_{armyData.name}"))

  return {
    rendObj = ROBJ_IMAGE
    pos
    size = [entrenchIconWidth, entrenchIconHeight]
    subPixel = true
    image = Picture($"{iconName}:{entrenchIconWidth}:{entrenchIconHeight}")
    color = entrenchIconColors.spriteColor
    animations = [{ prop = AnimProp.color, from = entrenchIconColors.blinkColor, to = entrenchIconColors.spriteColor,
      duration = blinkPeriod, loop = true, easing = CosineFull, play = isBlinking, trigger = $"entrench_{armyData.name}",
      globalTimer = true }]
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
    size = [armyIconSize, armyIconSize]
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

function onArmyMove(x, armyName, from, to) {
  let deltaX = to.x - from.x
  let deltaY = to.y - from.y
  movingArmiesPositions.mutate(@(t) t[armyName] <- { x = (from.x + deltaX * x), y = (from.y + deltaY * x) })
  return x
}

function onArmyMoveFinish(armyName) {
  movingArmiesPositions.mutate(@(t) t.rawdelete(armyName))
}

function mkArmyBack(armyData, areaBounds) {
  let isArmySelected = Computed(@() selectedArmy.get() == armyData.name)
  let isArmyHovered = Computed(@() hoveredArmy.get() == armyData.name)
  let animation = { prop = AnimProp.translate, from = [0, 0], to = [0, 0], duration = 0, play = false, onFinish = @() onArmyMoveFinish(armyData.name)}
  return function() {
    let children = []
    let armyGroupsInfo = getArmyGroupsInfo()
    let armyPos = convertToRelativeMapCoords(armyData.pathTracker.pos)
    let armySide = zoneSideType[armyData.owner.side]
    let { areaWidth, areaHeight } = areaBounds
    let armyBorderSize = even(armyData.specs.battleStartRadiusN * mapZoom.get()) * 2
    let armyBorderPos = [areaWidth * armyPos.x - armyBorderSize / 2, areaHeight * armyPos.y - armyBorderSize / 2]
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
      animation.__update({ from = armyBorderPos, to = nextArmyPos, duration = timeLeft, play = !isOperationPausedWatch.get(), easing = @(x) onArmyMove(x, armyData.name, armyPos, nextPointPos) })

      if (!isArmySelected.get() && !isArmyHovered.get()) {
        let pointTo = { x = points[nextPathIdx].pos.x - armyData.pathTracker.pos.x, y = points[nextPathIdx].pos.y - armyData.pathTracker.pos.y }
        let angle = calcAngleBetweenVectors(pointTo).rad

        let delta = PI * 30 / 180
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
          size = [arrowSize, arrowSize]
          fillColor
          lineWidth = hdpx(2)
          commands
        })
      }
    }
    else
      onArmyMoveFinish(armyData.name)

    children.append({
      rendObj = ROBJ_BOX
      subPixel = true
      borderColor
      size = [armyBorderSize, armyBorderSize]
      fillColor
      borderWidth = hdpx(2)
      borderRadius = armyBorderSize / 2
    })

    children.append(mkArmyIcon(armyData))

    return {
      watch = [isArmySelected, isArmyHovered, isShowArmiesIndex, mapZoom, isOperationPausedWatch]
      key = {}
      children
      transform = {
        translate = armyBorderPos
      }
      animations = [
        animation
      ]
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
    size = [fireIconSize, fireIconSize]
    image = Picture($"{getSettings("artilleryStrike").fireTexture}:{fireIconSize}:{fireIconSize}")
    color = Color(255, 0, 0, 192)
  }
}

let mkArmy = @(armyWatch, areaBounds) function() {
  let armyData = armyWatch.get()

  return {
    watch = [armyWatch, mapZoom]
    children = [
      mkArmyEntrenchIcon(armyData, areaBounds, mapZoom.get()),
      mkArtilleryFire(armyData, areaBounds, Computed(@() artilleryStrikesInfo.get().findindex(@(as) as.army.name == armyData.name) != null)),
      mkArmyBack(armyData, areaBounds)
    ]
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
    .sort(@(army1, army2) isPlayerSide(army1.owner.side) <=> isPlayerSide(army2.owner.side) || army2.specs.unitType <=> army1.specs.unitType)
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

return {
  mkArmies
}
