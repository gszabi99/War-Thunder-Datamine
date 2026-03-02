from "%rGui/globals/ui_library.nut" import *
let fontsState = require("%rGui/style/fontsState.nut")
let { withTooltip, tooltipDetach } = require("%rGui/components/tooltip.nut")

const MARK_COUNT_Y = 9
const MARK_COUNT_X = 35
const MAX_POINTS_COUNT_WITH_TOOLTIP = 25

const graphGridColor = 0xFF576C83
const graphGridOpacityColor = 0x4C1A2027
const graphPointBackgroundColor = 0xFFFFFFFF

let graphGridTextMaxWidth = fpx(40)
let graphGridTextPadding = fpx(18)
let graphGridBottomIndent = fpx(60)
let graphGridLineThickness = dp(1)
let graphLineThickness = dp(2)
let graphGridLineLength = fpx(12)
let graphGridLineShortRelativeLength = 58
let graphPointFullSize = fpx(11)
let graphPointCenterRelativeRadius = 27.3
let leftGraphPadding = graphGridTextMaxWidth + graphGridTextPadding

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
    size = [graphPointFullSize, graphPointFullSize]
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

let mkGraphLine = @(commands, graphColor, lineWidth = graphLineThickness) {
  size = flex()
  rendObj = ROBJ_VECTOR_CANVAS
  lineWidth
  color = graphColor
  fillColor = graphColor
  commands
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

function mkVerticalMeasureGridLine(idx, leftPosVeticalLine, xStep) {
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
      isEven ? mkGraphText((idx * xStep).tostring(), { pos = [pw(-50), 0] }) : null
    ]
  }
}

function mkHorizontalMeasureGridLine(topPos, leftPosVeticalLine, xStep) {
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
          children = array(MARK_COUNT_X + 1, null).map(@(_, idx) mkVerticalMeasureGridLine(idx, leftPosVeticalLine, xStep))
        }
      ]
    }
  }
}

function mkGraphGrid(graphWidth, graphHeight, maxValueX, maxValueY, measureLocText) {
  let topPosHorizontalLine = graphHeight / MARK_COUNT_Y
  let leftPosVeticalLine = graphWidth / MARK_COUNT_X
  let xStep = maxValueX / MARK_COUNT_X
  let yStep = maxValueY / MARK_COUNT_Y
  let horizontalLine = array(MARK_COUNT_Y+1, null).map(@(_, idx)
    mkHorizontalGridLine(idx * topPosHorizontalLine,
      graphGridOpacityColor, $"{maxValueY - idx * yStep}{measureLocText}"))
  horizontalLine.append(
    mkHorizontalMeasureGridLine(MARK_COUNT_Y * topPosHorizontalLine + 0.7*topPosHorizontalLine,
      leftPosVeticalLine, xStep))
  return {
    size = flex()
    children = horizontalLine
  }
}

let roundedStepValues = [5000, 4500, 4000, 3500, 3000, 2500, 2000, 1500, 1000, 500, 250, 100, 50, 25, 10, 5, 2]

function roundingValueDivisionByMarksCount(value, marksCount) {
  local step = (value + 0.5).tointeger() / marksCount + 1
  step = roundedStepValues.findvalue(@(v, idx) step <= v && step > (roundedStepValues?[idx + 1] ?? 1)) ?? 1
  return marksCount * step
}

function calcGraphLineComp(bulletsConfig, graphWidth, graphHeight, getValueX, getValueY, getPointsCount, mkTooltipText) {
  local maxValueX = 0
  local maxValueY = 0
  foreach (bullet in bulletsConfig) {
    let pointsCount = getPointsCount(bullet)
    for (local i = 0; i < pointsCount; i++) {
      maxValueX = max(maxValueX, getValueX(bullet, i))
      maxValueY = max(maxValueY, getValueY(bullet, i))
    }
  }

  maxValueX = roundingValueDivisionByMarksCount(maxValueX, MARK_COUNT_X)
  maxValueY = roundingValueDivisionByMarksCount(maxValueY, MARK_COUNT_Y)

  let graphPoints = []
  let graphLines = []
  foreach (bullet in bulletsConfig) {
    let { graphColor } = bullet
    let pointsCount = getPointsCount(bullet)
    if (pointsCount <= 1) 
      continue

    let haveTooManyPoints = pointsCount > MAX_POINTS_COUNT_WITH_TOOLTIP
    let lineCommand = [VECTOR_LINE]
    for (local i = 0; i < pointsCount; i++) {
      let valueX = getValueX(bullet, i)
      let valueY = getValueY(bullet, i)
      let pointPosX = maxValueX == 0 ? 0 : valueX.tofloat() / maxValueX
      let pointPosY = maxValueY == 0 ? 0
        : valueY == 0 ? 1
        : clamp(1 - valueY / maxValueY, 0, 1) 
                                                
      if (!haveTooManyPoints || (i % 2) == 0 || i == (pointsCount - 1))
        graphPoints.append(mkGraphPoint(pointPosX * graphWidth, pointPosY * graphHeight,
          graphColor, mkTooltipText(bullet, i)))
      lineCommand.append(pointPosX * 100, pointPosY * 100)
    }
    graphLines.append(mkGraphLine([lineCommand], graphColor))
  }
  return {
    maxValueX
    maxValueY
    bulletsGraphComp = mkGraph(graphWidth, graphHeight, graphLines.extend(graphPoints))
  }
}

let mkTextValue = @(titleLocId, value, measureLocId) loc("ui/space").concat(
  $"{loc(titleLocId)}{loc("ui/colon")}", (value + 0.5).tointeger(), loc(measureLocId))

let roundingSizeDivisionByMarksCount = @(size, marksCount) size - (size % marksCount)

let getBulletPenetrationValueX = @(bullet, idx) bullet.armorPiercingDist[idx]
let getBulletPenetrationValueY = @(bullet, idx) bullet.armorPiercing[idx]
let getBulletPenetrationPointsCount = @(bullet) bullet.armorPiercingDist.len()
let getBulletPenetrationTooltip = @(bullet, idx) "\n".concat(
  mkTextValue("bullet_properties/armorPiercing", bullet.armorPiercing[idx], "measureUnits/mm"),
  mkTextValue("options/measure_units_dist", bullet.armorPiercingDist[idx], "measureUnits/meters_alt")
)

function mkBulletsArmorPiercingGraph(bulletsConfig, size) {
  let graphHeight = roundingSizeDivisionByMarksCount(size[1] - graphGridBottomIndent, MARK_COUNT_Y)
  let graphWidth = roundingSizeDivisionByMarksCount(size[0] - leftGraphPadding, MARK_COUNT_X)
  let { maxValueX, maxValueY, bulletsGraphComp
  } = calcGraphLineComp(bulletsConfig, graphWidth, graphHeight, getBulletPenetrationValueX,
    getBulletPenetrationValueY, getBulletPenetrationPointsCount, getBulletPenetrationTooltip)
  return {
    size = flex()
    children = [
      mkGraphGrid(graphWidth, graphHeight, maxValueX, maxValueY, loc("measureUnits/mm"))
      bulletsGraphComp
    ]
  }
}

let getBulletBallisticValueX = @(bullet, idx) bullet.ballisticsData[idx].distance
let getBulletBallisticValueY = @(bullet, idx) bullet.ballisticsData[idx].altitude
let getBulletBallisticPointsCount = @(bullet) bullet.ballisticsData.len()
function getBulletBallisticTooltip(bullet, idx) {
  let { distance, altitude, speed, flightDistance, flightTime } = bullet.ballisticsData[idx]
  return "\n".concat(
    mkTextValue("options/measure_units_dist", distance, "measureUnits/meters_alt"),
    mkTextValue("options/measure_units_alt", altitude, "measureUnits/meters_alt"),
    mkTextValue("options/measure_units_speed", speed, "measureUnits/metersPerSecond_climbSpeed"),
    mkTextValue("flightDistance", flightDistance, "measureUnits/meters_alt"),
    mkTextValue("flightTime", flightTime, "measureUnits/seconds")
  )
}

function mkBulletsBallisticTrajectoryGraph(bulletsConfig, size) {
  let graphHeight = roundingSizeDivisionByMarksCount(size[1] - graphGridBottomIndent, MARK_COUNT_Y)
  let graphWidth = roundingSizeDivisionByMarksCount(size[0] - leftGraphPadding, MARK_COUNT_X)
  let { maxValueX, maxValueY, bulletsGraphComp
  } = calcGraphLineComp(bulletsConfig, graphWidth, graphHeight, getBulletBallisticValueX,
    getBulletBallisticValueY, getBulletBallisticPointsCount, getBulletBallisticTooltip)
  return {
    size = flex()
    children = [
      mkGraphGrid(graphWidth, graphHeight, maxValueX, maxValueY, loc("measureUnits/meters_alt"))
      bulletsGraphComp
    ]
  }
}

return {
  mkBulletsArmorPiercingGraph
  mkBulletsBallisticTrajectoryGraph
}
