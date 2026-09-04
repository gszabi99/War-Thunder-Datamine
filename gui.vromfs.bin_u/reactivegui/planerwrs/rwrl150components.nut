from "%rGui/twsState.nut" import rwrTargetsTriggers, CurrentTime
from "%rGui/planeState/planeFlyState.nut" import CompassValue
from "%rGui/planeRwrs/rwrL150ThreatsLibrary.nut" import settings
from "%rGui/planeIlses/ilsConstants.nut" import degToRad
from "math" import sin, cos, PI
from "%rGui/globals/ui_library.nut" import *

let { rwrTargets, rwrTargetsOrder } = require("%rGui/twsState.nut")


let { ThreatType } = require("%rGui/planeRwrs/rwrL150ThreatsLibrary.nut")


const backGroundColor = Color(0, 0, 0, 255)
const color = Color(10, 202, 10, 255)
const iconColorSearch = Color(250, 250, 0, 255)
const iconColorTrack = Color(220, 120, 60, 255)
const iconColorLaunch = Color(230, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontSize = 10
}

function createCompass(gridStyle, radius, useFlexSize = false) {
  const compassFontSizeMult = 2.0

  const markAngleStep = 10.0
  const markAngle = PI * markAngleStep / 180.0
  let markDashCount = (360.0 / markAngleStep).tointeger()
  const azimuthMarkLength = 4

  const textAngleStep = 30.0
  const textMarkAngle = PI * textAngleStep / 180.0
  const textDashCount = 360.0 / textAngleStep

  return function() {
    let compassOffsetRad = -CompassValue.get() * degToRad

    let commands = array(markDashCount).map(@(_, i) [
      VECTOR_LINE,
      50 + cos(i * markAngle + compassOffsetRad) * (radius + azimuthMarkLength),
      50 + sin(i * markAngle + compassOffsetRad) * (radius + azimuthMarkLength),
      50 + cos(i * markAngle + compassOffsetRad) * radius,
      50 + sin(i * markAngle + compassOffsetRad) * radius
    ])

    local azimuthMarks = []
    for (local i = 0; i < textDashCount; ++i) {
      azimuthMarks.append({
        rendObj = ROBJ_TEXT
        pos = [pw(sin(i * textMarkAngle + compassOffsetRad) * (radius + 10)), ph(-cos(i * textMarkAngle + compassOffsetRad) * (radius + 10))],
        size = FLEX,
        color = color,
        font = styleText.font,
        fontSize = gridStyle.fontScale * styleText.fontSize * compassFontSizeMult,
        text = (i * textAngleStep * 0.1).tointeger(),
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        behavior = Behaviors.RtPropUpdate,
      })
    }

    return {
      watch = CompassValue
      rendObj = ROBJ_VECTOR_CANVAS,
      size = useFlexSize ? FLEX : [ph(100), ph(100)]
      color = color,
      lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
      fillColor = backGroundColor,
      commands = commands,
      children = azimuthMarks,
      behavior = Behaviors.RtPropUpdate,
    }
  }
}

function calcRwrTargetRadius(target) {
  return 0.1 + target.rangeRel * 0.9
}

function makeRwrTargetIconCommands(pos, sizeMult, targetType, radius) {
  if (targetType == ThreatType.AI)
    return [
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * radius,
        (pos[1] - 0.5 * sizeMult) * radius,
        (pos[0] + 0.5 * sizeMult) * radius,
        (pos[1] - 0.5 * sizeMult) * radius ],
      [ VECTOR_LINE,
        pos[0] * radius,
        (pos[1] - 0.50 * sizeMult) * radius,
        pos[0] * radius,
        (pos[1] - 0.75 * sizeMult) * radius ]
    ]
  else if ( targetType == ThreatType.SAM ||
            targetType == ThreatType.AAA ||
            targetType == null)
    return [
      [ VECTOR_LINE,
        (pos[0] - 0.5 * sizeMult) * radius,
        (pos[1] + 0.5 * sizeMult) * radius,
        (pos[0] + 0.5 * sizeMult) * radius,
        (pos[1] + 0.5 * sizeMult) * radius ],
      [ VECTOR_LINE,
        pos[0] * radius,
        (pos[1] + 0.50 * sizeMult) * radius,
        pos[0] * radius,
        (pos[1] + 0.75 * sizeMult) * radius ]
    ]
  else if (targetType == ThreatType.MSL)
    return [
      [ VECTOR_LINE,
        (pos[0] - 0.25 * sizeMult) * radius,
        (pos[1] - 0.50 * sizeMult) * radius,
        (pos[0] + 0.25 * sizeMult) * radius,
        (pos[1] - 0.50 * sizeMult) * radius ] ]
  else
    return null
}

function createRwrTarget(index, settingsIn, objectStyle, radius) {
  if (index >= rwrTargetsOrder.len())
    return null
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return null

  let directionGroup = settingsIn.directionGroups?[target.groupId]
  let targetRadiusRel = calcRwrTargetRadius(target)

  let targetSizeMult = target.priority ? 1.5 : 1.0
  let iconSizeMult = 0.15 * objectStyle.scale * targetSizeMult

  const targetTypeFontSizeMult = 2.0

  local iconColor = iconColorSearch
  if (target.track)
    iconColor = iconColorTrack
  if (target.launch)
    iconColor = iconColorLaunch

  local targetTypeText = styleText.__merge({
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    color = iconColor
    fontSize = objectStyle.fontScale * styleText.fontSize * targetTypeFontSizeMult * targetSizeMult
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = 2
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backGroundColor
    pos = [pw(target.x * radius * targetRadiusRel - 0.25 * targetTypeTextSize[0]), ph(target.y * radius * targetRadiusRel - 0.25 * targetTypeTextSize[1])]
    children = targetTypeText
  }

  let iconCommands = makeRwrTargetIconCommands([target.x * targetRadiusRel, target.y * targetRadiusRel], iconSizeMult, directionGroup?.type, radius)

  let launchOpacityRwr = Computed(@() target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0)
  let background = @() {
    watch = launchOpacityRwr
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = backGroundColor
    opacity = launchOpacityRwr.get()
    fillColor = backGroundColor
    lineWidth = baseLineWidth * (4 + 6) * objectStyle.lineWidthScale
    commands = iconCommands
  }
  let icon = @() {
    watch = launchOpacityRwr
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = iconColor
    opacity = launchOpacityRwr.get()
    fillColor = 0
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    commands = iconCommands
  }

  return @() {
    pos = const [pw(50), ph(50)],
    size = FLEX,
    children = [
      background,
      targetType,
      icon
    ]
  }
}

function rwrTargetsComponent(objectStyle, radius) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = FLEX
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle, radius))
  }
}

return {
  color,
  backGroundColor,
  iconColorSearch,
  iconColorTrack,
  iconColorLaunch,
  baseLineWidth,
  styleText,
  settings,
  calcRwrTargetRadius,
  createCompass,
  rwrTargetsComponent
}