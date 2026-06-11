from "%rGui/globals/ui_library.nut" import *
let fontsState = require("%rGui/style/fontsState.nut")
let { withTooltip, tooltipDetach } = require("%rGui/components/tooltip.nut")
let { graphPlayerParams } = require("%rGui/weapons/bulletsGraphState.nut")
let { get_time_msec } = require("dagor.time")
let { secondsToMilliseconds } = require("%sqstd/time.nut")
let { lerp } = require("%sqstd/math.nut")
let { abs } = require("math")

const MARK_COUNT_Y = 9
const MARK_COUNT_X = 35
const MAX_POINTS_COUNT_WITH_TOOLTIP = 25

const graphGridColor = 0xFF576C83
const graphGridOpacityColor = 0x4C1A2027
const graphPointBackgroundColor = 0xFFFFFFFF

let graphNestPadding = fpx(5)
let graphGridPadding = fpx(35)
let graphGridTextMaxWidth = graphGridPadding
let graphGridTextPadding = fpx(18)
let graphGridBottomIndent = fpx(60)
let graphGridLineThickness = dp(1)
let graphLineThickness = dp(2)
let graphGridLineLength = fpx(12)
let graphGridLineShortRelativeLength = 58
let graphPointFullSize = fpx(11)
let graphPointCenterRelativeRadius = 27.3
let leftGraphPadding = graphGridTextMaxWidth + graphGridTextPadding

let axisLabelParams = {
  distance = {
    locId = "options/measure_units_dist"
    measureLocId = "measureUnits/meters_alt"
  }
  penetration = {
    locId = "bullet_properties/armorPiercing"
    measureLocId = "measureUnits/mm"
  }
  altitude = {
    locId = "options/measure_units_alt"
    measureLocId = "measureUnits/meters_alt"
  }
  flightTime = {
    locId = "flightTime"
    measureLocId = "measureUnits/seconds"
  }
  speed = {
    locId = "options/measure_units_speed"
    measureLocId = "measureUnits/metersPerSecond_climbSpeed"
  }
  horizontalDistance = {
    locId = "horizontalDistance"
    measureLocId = "measureUnits/meters_alt"
  }
}

let mkPointCanvas = @(graphColor, radius) {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth = graphLineThickness
  color = graphColor
  fillColor = graphColor
  commands = [[VECTOR_ELLIPSE, 50, 50, radius, radius]]
}

function mkGraphPoint(pointPosX, pointPosY, graphColor, tooltipContent) {
  let pos = [pointPosX - 0.5*graphPointFullSize, pointPosY - 0.5*graphPointFullSize]
  let stateFlag = Watched(0)
  let key = {}
  let hoverPoint = mkPointCanvas(graphPointBackgroundColor, 50)
  let constPoint = mkPointCanvas(graphColor, graphPointCenterRelativeRadius)
  return @() {
    key
    watch = stateFlag
    pos
    size = graphPointFullSize
    skipDirPadNav = true
    behavior = Behaviors.Button
    onElemState = withTooltip(stateFlag, key, @() {
      content = tooltipContent
      key
      bgOvr = { borderColor = graphColor }
    })
    onDetach = tooltipDetach(stateFlag, key)
    children = [
      (stateFlag.get() & S_HOVER) != 0 ? hoverPoint : null,
      constPoint
    ]
  }
}

function getCurPlayFlightTime(playerParams) {
  let { startPlayingTimeMs, curPlayTimeMs, maxPlayTimeMs } = playerParams
  return startPlayingTimeMs != 0 ? get_time_msec() - startPlayingTimeMs
    : curPlayTimeMs == 0 ? maxPlayTimeMs
    : curPlayTimeMs
}

function isVisibleByTime(flightTimeMs, playerParams) {
  let curFlightTimeMs = getCurPlayFlightTime(playerParams)
  return flightTimeMs <= curFlightTimeMs
}

function mkGraphPointByTime(pointPosX, pointPosY, graphColor, tooltipContent, playerParams, graphPoint) {
  let key = {}
  let graphPointComp = mkGraphPoint(0, 0, graphColor, tooltipContent)
  let flightTimeMs = secondsToMilliseconds(graphPoint.flightTime).tointeger()
  let isVisible = Watched(false)
  let updateIsVisible = @(playerParamsValue) isVisible.set(isVisibleByTime(flightTimeMs, playerParamsValue))
  return @() {
    key
    watch = isVisible
    pos = [pointPosX, pointPosY]
    size = [graphPointFullSize, graphPointFullSize]
    behavior = Behaviors.RtPropUpdate
    function update() {
      if (!isVisible.get())
        updateIsVisible(playerParams.get())
    }
    onAttach = @() playerParams.subscribe(updateIsVisible)
    onDetach = @() playerParams.unsubscribe(updateIsVisible)
    children = isVisible.get() ? graphPointComp : null
  }
}

let mkGraphLine = @(commands, graphColor, lineWidth = graphLineThickness) {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth
  color = graphColor
  fillColor = graphColor
  commands
}

function makeLineCommandByTime(lineCommand, graphPoints, curFlightTimeMs) {
  let nextIdx = graphPoints.findindex(
    @(point) secondsToMilliseconds(point.flightTime).tointeger() > curFlightTimeMs)
  if (nextIdx == null)
    return lineCommand

  if (nextIdx == 0)
    return []

  let fullLineIdx = (nextIdx - 1) * 2 + 1
  let nextLineIdx = fullLineIdx + 2
  let fullLine = (clone lineCommand).resize(fullLineIdx + 2)
  let lastPointFlightTime = secondsToMilliseconds(graphPoints[nextIdx - 1].flightTime).tointeger()
  let nextPointFlightTime = secondsToMilliseconds(graphPoints[nextIdx].flightTime).tointeger()
  let posX = lerp(lastPointFlightTime, nextPointFlightTime,
    lineCommand[fullLineIdx], lineCommand[nextLineIdx], curFlightTimeMs)
  let posY = lerp(lastPointFlightTime, nextPointFlightTime,
    lineCommand[fullLineIdx + 1], lineCommand[nextLineIdx + 1], curFlightTimeMs)
  return fullLine.append(posX, posY)
}

function mkGraphLineByTime(lineCommand, graphColor, playerParams, graphPoints) {
  return {
    size = flex()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = graphLineThickness
    color = graphColor
    fillColor = graphColor
    commands = []
    behavior = Behaviors.RtPropUpdate
    update = @() {
      commands = [
        makeLineCommandByTime(lineCommand, graphPoints, getCurPlayFlightTime(playerParams.get()))
      ]
    }
  }
}

function mkGraph(graphWidth, graphHeight, children) {
  return {
    size = [graphWidth, graphHeight]
    margin = [0, 0, 0, leftGraphPadding]
    children
  }
}

let mkGraphText = @(text, ovr = {}) {
  rendObj = ROBJ_TEXT
  text
  color = graphGridColor
  font = fontsState.get("tiny")
}.__update(ovr)

function mkHorizontalGridLine(topPos, color, text) {
  return {
    pos = [0, topPos]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    gap = graphGridTextPadding
    children = [
      {
        pos = [0, ph(-50)]
        size = [graphGridTextMaxWidth, SIZE_TO_CONTENT]
        halign = ALIGN_RIGHT
        children = mkGraphText(text)
      }
      mkGraphLine([[VECTOR_LINE, 0, 0, 100, 0]], color, graphGridLineThickness)
    ]
  }
}

function mkVerticalMeasureGridLine(idx, leftPosVeticalLine, xStep, startValueX) {
  let isEven = idx % 2 == 0
  return {
    pos = [idx * leftPosVeticalLine, 0]
    flow = FLOW_VERTICAL
    gap = fpx(6)
    children = [
      {
        size = [graphGridLineThickness, graphGridLineLength]
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = graphGridLineThickness
        color = graphGridColor
        fillColor = graphGridColor
        commands = [[VECTOR_LINE, 0, 0, 0, isEven ? 100 : graphGridLineShortRelativeLength]]
      }
      isEven ? mkGraphText((startValueX + idx * xStep).tostring(), { pos = [pw(-50), 0] }) : null
    ]
  }
}

function mkHorizontalMeasureGridLine(topPos, leftPosVeticalLine, xStep, startValueX) {
  return {
    pos = [0, topPos]
    size = FLEX_H
    flow = FLOW_HORIZONTAL
    padding = [0, 0, 0, graphGridTextMaxWidth + graphGridTextPadding]
    children = {
      size = flex()
      flow = FLOW_VERTICAL
      children = [
        mkGraphLine([[VECTOR_LINE, 0, 0, 100, 0]], graphGridColor, graphGridLineThickness)
        {
          size = FLEX_H
          children = array(MARK_COUNT_X + 1, null).map(@(_, idx)
            mkVerticalMeasureGridLine(idx, leftPosVeticalLine, xStep, startValueX))
        }
      ]
    }
  }
}

function mkGraphGrid(graphWidth, graphHeight, absLenX, absLenY,
    startValueX, startValueY) {
  let topPosHorizontalLine = graphHeight / MARK_COUNT_Y
  let leftPosVeticalLine = graphWidth / MARK_COUNT_X
  let xStep = absLenX / MARK_COUNT_X
  let yStep = absLenY / MARK_COUNT_Y
  let horizontalLine = array(MARK_COUNT_Y+1, null).map(@(_, idx)
    mkHorizontalGridLine(idx * topPosHorizontalLine,
      graphGridOpacityColor, $"{absLenY - idx * yStep + startValueY}"))
  horizontalLine.append(
    mkHorizontalMeasureGridLine(MARK_COUNT_Y * topPosHorizontalLine + 0.7*topPosHorizontalLine,
      leftPosVeticalLine, xStep, startValueX))
  return {
    size = flex()
    children = horizontalLine
  }
}

let roundedStepValues = [5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 500, 250, 100, 50, 25, 10, 5, 2]

function roundingValueDivisionByMarksCount(maxValue, minValue, marksCount) {
  let value = abs(maxValue) + abs(minValue)
  let notRoundStep = (value + 0.5).tointeger() / marksCount + 1
  let roundStep = notRoundStep > roundedStepValues[0] ? ((notRoundStep / 1000) + 1) * 1000
    : roundedStepValues.findvalue(@(v, idx) notRoundStep <= v && notRoundStep > (roundedStepValues?[idx + 1] ?? 1)) ?? 1
  return {
    absLen = marksCount * roundStep
    startValue = minValue == 0 ? 0
      : (minValue.tointeger() / roundStep - 1) * roundStep
  }
}

function calcGraphLineComp(bulletsConfig, graphWidth, graphHeight, keyX, keyY, mkTooltipText, playerParams) {
  local maxValueX = 0
  local maxValueY = 0
  local minValueX = 0
  local minValueY = 0
  foreach (bullet in bulletsConfig) {
    let { graphData } = bullet
    let pointsCount = graphData.len()
    for (local i = 0; i < pointsCount; i++) {
      let graphPoint = graphData[i]
      let pointX = graphPoint[keyX]
      let pointY = graphPoint[keyY]
      maxValueX = max(maxValueX, pointX)
      maxValueY = max(maxValueY, pointY)
      minValueX = min(minValueX, pointX)
      minValueY = min(minValueY, pointY)
    }
  }

  let hasPlayerParams = playerParams != null
  let valuesX = roundingValueDivisionByMarksCount(maxValueX, minValueX, MARK_COUNT_X)
  let absLenX = valuesX.absLen
  let startValueX = valuesX.startValue
  let valuesY = roundingValueDivisionByMarksCount(maxValueY, minValueY, MARK_COUNT_Y)
  let absLenY = valuesY.absLen
  let startValueY = valuesY.startValue
  let graphPoints = []
  let graphLines = []
  foreach (bullet in bulletsConfig) {
    let { graphColor, graphData } = bullet
    let pointsCount = graphData.len()
    if (pointsCount <= 1) 
      continue

    let haveTooManyPoints = pointsCount > MAX_POINTS_COUNT_WITH_TOOLTIP
    let lineCommand = [VECTOR_LINE]
    for (local i = 0; i < pointsCount; i++) {
      let graphPoint = graphData[i]
      let valueX = graphPoint[keyX] - startValueX
      let valueY = graphPoint[keyY] - startValueY
      let pointPosX = absLenX == 0 ? 0 : valueX.tofloat() / absLenX
      let pointPosY = absLenY == 0 ? 0
        : valueY == 0 ? 1
        : clamp(1 - valueY / absLenY, 0, 1) 
                                                
      if (!haveTooManyPoints || (i % 2) == 0 || i == (pointsCount - 1))
        if (hasPlayerParams)
          graphPoints.append(mkGraphPointByTime(pointPosX * graphWidth, pointPosY * graphHeight,
            graphColor, mkTooltipText(graphPoint), playerParams, graphPoint))
        else
          graphPoints.append(mkGraphPoint(pointPosX * graphWidth, pointPosY * graphHeight,
            graphColor, mkTooltipText(graphPoint)))
      lineCommand.append(pointPosX * 100, pointPosY * 100)
    }
    let graphLineComp = !hasPlayerParams ? mkGraphLine([lineCommand], graphColor)
      : mkGraphLineByTime(lineCommand, graphColor, playerParams, graphData)

    graphLines.append(graphLineComp)
  }
  return {
    absLenX
    absLenY
    startValueX
    startValueY
    bulletsGraphComp = mkGraph(graphWidth, graphHeight, graphLines.extend(graphPoints))
  }
}

function getLabelText(labelId) {
  let { locId, measureLocId } = axisLabelParams[labelId]
  return loc("ui/comma").concat(loc(locId), loc(measureLocId))
}

function mkAxisXLabel(labelId) {
  return mkGraphText(getLabelText(labelId),
    {
      font = fontsState.get("normal")
      hplace = ALIGN_CENTER
      vplace = ALIGN_BOTTOM
    })
}

function mkAxisYLabel(labelId) {
  return mkGraphText(getLabelText(labelId),
    {
      pos = [elemw(-50), elemh(50)]
      font = fontsState.get("normal")
      hplace = ALIGN_LEFT
      vplace = ALIGN_CENTER
      transform = {
        pivot = [0.5, 0]
        rotate = -90
      }
    })
}

let roundingSizeDivisionByMarksCount = @(size, marksCount) size - (size % marksCount)

function mkGridAndGraphComp(graphConfig, size, keyX, keyY, getTooltipText,
    labelAxisX = null, labelAxisY = null, playerParams = null) {
  let paddingSize = 2 * graphNestPadding + 2 * graphGridPadding
  let width = size[0] - leftGraphPadding - paddingSize
  let height = size[1] - graphGridBottomIndent - paddingSize
  let graphHeight = roundingSizeDivisionByMarksCount(height, MARK_COUNT_Y)
  let graphWidth = roundingSizeDivisionByMarksCount(width, MARK_COUNT_X)
  let { absLenX, absLenY, startValueX, startValueY, bulletsGraphComp
  } = calcGraphLineComp(graphConfig, graphWidth, graphHeight, keyX, keyY, getTooltipText, playerParams)
  return {
    size = flex()
    padding = graphNestPadding
    children = [
      mkAxisXLabel(labelAxisX ?? keyX)
      mkAxisYLabel(labelAxisY ?? keyY)
      {
        size = flex()
        padding = graphGridPadding
        children = [
          mkGraphGrid(graphWidth, graphHeight, absLenX, absLenY,
            startValueX, startValueY)
          {
            size = flex()
            children = bulletsGraphComp
          }
        ]
      }
    ]
  }
}


let mkTextValue = @(titleLocId, value, measureLocId) loc("ui/space").concat(
  $"{loc(titleLocId)}{loc("ui/colon")}", (value + 0.5).tointeger(), loc(measureLocId))

let getBulletPenetrationTooltip = @(graphPoint) "\n".concat(
  mkTextValue("bullet_properties/armorPiercing", graphPoint.penetration, "measureUnits/mm"),
  mkTextValue("options/measure_units_dist", graphPoint.distance, "measureUnits/meters_alt")
)

let mkBulletsArmorPiercingGraph = @(bulletsConfig, size)
  mkGridAndGraphComp(bulletsConfig, size, "distance", "penetration",
    getBulletPenetrationTooltip)

function getBulletBallisticTooltip(graphPoint) {
  let { distance, altitude, speed, flightDistance, flightTime } = graphPoint
  return "\n".concat(
    mkTextValue("options/measure_units_dist", distance, "measureUnits/meters_alt"),
    mkTextValue("options/measure_units_alt", altitude, "measureUnits/meters_alt"),
    mkTextValue("options/measure_units_speed", speed, "measureUnits/metersPerSecond_climbSpeed"),
    mkTextValue("flightDistance", flightDistance, "measureUnits/meters_alt"),
    mkTextValue("flightTime", flightTime, "measureUnits/seconds")
  )
}

let mkBulletsBallisticTrajectoryGraph = @(bulletsConfig, size)
  mkGridAndGraphComp(bulletsConfig, size, "distance", "altitude",
    getBulletBallisticTooltip)

function getMissileTooltip(graphPoint) {
  let { distance, altitude, speed, flightDistance, flightTime } = graphPoint
  return "\n".concat(
    mkTextValue("flightTime", flightTime, "measureUnits/seconds")
    mkTextValue("options/measure_units_speed", speed, "measureUnits/metersPerSecond_climbSpeed"),
    mkTextValue("options/measure_units_dist", flightDistance, "measureUnits/meters_alt"),
    loc("ui/space").concat(loc("graph/missleTooltip/position"),
      loc("ui/comma").concat(mkTextValue("X", distance, "measureUnits/meters_alt"),
        mkTextValue("Y", altitude, "measureUnits/meters_alt")
      )
    )
  )
}

let mkMissileTrajectoryGraph = @(bulletsConfig, size)
  mkGridAndGraphComp(bulletsConfig, size, "distance", "altitude",
    getMissileTooltip, "horizontalDistance", "altitude",
    graphPlayerParams)

let mkMissileTelemetryDistanceGraph = @(bulletsConfig, size)
  mkGridAndGraphComp(bulletsConfig, size, "flightTime", "flightDistance",
    getMissileTooltip, "flightTime", "distance")

let mkMissileTelemetrySpeedGraph = @(bulletsConfig, size)
  mkGridAndGraphComp(bulletsConfig, size, "flightTime", "speed",
    getMissileTooltip)

return {
  mkBulletsArmorPiercingGraph
  mkBulletsBallisticTrajectoryGraph
  mkMissileTelemetryDistanceGraph
  mkMissileTelemetrySpeedGraph
  mkMissileTrajectoryGraph
}
