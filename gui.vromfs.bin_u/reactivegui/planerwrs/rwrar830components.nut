from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { sin, cos, PI } = require("math")

let { rwrTargets, rwrTargetsOrder, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")
let { CompassValue } = require("%rGui/planeState/planeFlyState.nut")

let ThreatType = {
  AI = 0,
  SAM = 1,
  AAA = 2,
  MSL = 3
}

let baseLineWidth = LINE_WIDTH * 0.5

function createCompass(gridStyle, color, backGroundColor, styleText) {
  let markAngleStep = 5.0
  let markAngle = PI * markAngleStep / 180.0
  let markDashCount = 360.0 / markAngleStep
  let indicatorRadius = 45
  let azimuthMarkLength = 2

  let commands = array(markDashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + cos(i * markAngle) * (indicatorRadius - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + sin(i * markAngle) * (indicatorRadius - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + cos(i * markAngle) * indicatorRadius,
    50 + sin(i * markAngle) * indicatorRadius
  ])

  let textAngleStep = 30.0
  let textDashCount = 360.0 / textAngleStep
  local azimuthMarks = []
  for (local i = 0; i < textDashCount; ++i) {
    azimuthMarks.append({
      rendObj = ROBJ_TEXT
      pos = [0, ph(-0.5)],
      size = flex(),
      color = color,
      font = styleText.font,
      fontSize = gridStyle.fontScale * styleText.fontSize,
      text = (i * textAngleStep).tointeger(),
      halign = ALIGN_CENTER,
      transform = {
        rotate = i * textAngleStep,
        pivot = [0.5, 0.5 + 0.005 ]
      }
    })
  }

  return {
    size = [pw(100), ph(100)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale
    fillColor = backGroundColor
    commands = commands
    children = azimuthMarks
    behavior = Behaviors.RtPropUpdate
    update = @() {
      transform = {
        rotate = -CompassValue.get()
      }
    }
  }
}

function createRwrGrid(gridStyle, color, backGroundColor) {
  return {
    pos = [pw(50), ph(50)],
    size = [pw(100), ph(100)],
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = color,
        lineWidth = baseLineWidth * 3 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 50, 50],
          [VECTOR_ELLIPSE, 0, 0, 25, 25],
          [VECTOR_LINE, 0, -50, 0, -25],
          [VECTOR_LINE, 0,  50, 0,  25],
          [VECTOR_LINE, -50, 0, -25, 0],
          [VECTOR_LINE,  50, 0,  25, 0],
          [VECTOR_LINE, 0, 0, 4, 10, -4, 10, 0, 0, 0, -5]
        ]
      },
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = backGroundColor,
        lineWidth = baseLineWidth * 90,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE, 0, 0, 65.0, 65.0]
        ]
      }
    ]
  }
}

function createRwrGridMarks(gridStyle, styleText, settings) {
  let gridFontSizeMult = 1.5
  return {
    size = flex(),
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [0, ph(22.5)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001 * 0.5)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [0, ph(47.5)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settings.rangeMax * 0.001)
      })
    ]
  }
}

function calcRwrTargetRadius(target, settings) {
  return settings.rangeMinRel + target.rangeRel * (1.0 - settings.rangeMinRel)
}

function makeRwrTargetIconCommands(pos, sizeMult, targetType) {
  if (targetType == ThreatType.AI)
    return [
      [ VECTOR_SECTOR,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0,
        180, 360 ],
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0,
        (pos[0] + 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0 ] ]
  else if (targetType == ThreatType.SAM)
    return [
      [ VECTOR_ELLIPSE,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0 ] ]
  else if ( targetType == ThreatType.AAA ||
            targetType == null)
    return [
      [ VECTOR_SECTOR,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 50.0,
        0, 180 ],
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0,
        (pos[0] + 0.5 * sizeMult) * 50.0,
        pos[1] * 50.0 ] ]
  else if (targetType == ThreatType.MSL)
    return [
      [ VECTOR_ELLIPSE,
        pos[0] * 50.0,
        pos[1] * 50.0,
        sizeMult * 0.5 * 50.0,
        sizeMult * 0.5 * 50.0] ]
  else
    return null
}

function createRwrTarget(index, settingsIn, objectStyle, iconColor, backGroundColor, styleText) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settingsIn.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target, settingsIn)

  let targetTypeFontSizeMult = 1.5
  let iconSizeMult = 0.075 * objectStyle.scale

  let newTargetFontSizeMultRwr = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))
  local targetTypeText = styleText.__merge({
    watch = newTargetFontSizeMultRwr
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    color = iconColor
    fontSize = styleText.fontSize * objectStyle.fontScale * targetTypeFontSizeMult * newTargetFontSizeMultRwr.get()
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = [2, 2]
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backGroundColor
    pos = [pw(target.x * 50.0 * targetRadiusRel - 0.2 * targetTypeTextSize[0]), ph(target.y * 50.0 * targetRadiusRel + iconSizeMult * 1.5 * 50.0 - 0.2 * targetTypeTextSize[1])]
    children = @() targetTypeText
  }

  let iconCommands = makeRwrTargetIconCommands([target.x * targetRadiusRel, target.y * targetRadiusRel], iconSizeMult, directionGroup?.type)
  let attackOpacityRwr = Computed(@() ( (target.track || target.launch) && ((CurrentTime.get() * (target.launch ? 4.0 : 2.0)).tointeger() % 2) == 0 ? 0.0 : 1.0))

  let background = @() {
    watch = attackOpacityRwr
    color = backGroundColor
    opacity = attackOpacityRwr.get()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * (4 + 6) * objectStyle.lineWidthScale
    fillColor = backGroundColor
    size = flex()
    commands = iconCommands
  }

  let icon = @() {
    watch = attackOpacityRwr
    color = iconColor
    opacity = attackOpacityRwr.get()
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    fillColor = 0
    size = flex()
    commands = iconCommands
  }

  let killRadius = directionGroup != null && directionGroup?.lethalRangeRel != null ?
    @() {
      color = iconColor,
      rendObj = ROBJ_VECTOR_CANVAS,
      lineWidth = baseLineWidth * 2 * objectStyle.lineWidthScale,
      fillColor = 0,
      size = flex(),
      commands = [
        [ VECTOR_ELLIPSE,
          target.x * 50.0 * targetRadiusRel,
          target.y * 50.0 * targetRadiusRel,
          directionGroup.lethalRangeRel * 50.0,
          directionGroup.lethalRangeRel * 50.0] ]
    } : null

  return @() {
    pos = [pw(50), ph(50)]
    size = flex()
    children = [
      background,
      targetType,
      icon,
      killRadius
    ]
  }
}

return {
  ThreatType,
  baseLineWidth,
  createCompass,
  createRwrGrid,
  createRwrGridMarks,
  createRwrTarget
}