from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, CurrentTime } = require("%rGui/twsState.nut")

let {ThreatType, settings} = require("rwrAnAlr67ThreatsLibrary.nut")

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.0
}

let outerCircle = 0.8
let middleCircle = 0.55
let innerCircle = 0.15

let nonLethalThreatsRadius = (1.0 + outerCircle) * 0.5
let lethalThreatsRadius = (outerCircle + middleCircle) * 0.5
let criticalThreatsRadius = (middleCircle + innerCircle) * 0.5

function calcRwrTargetRadius(target, directionGroup) {
  if (target.launch)
    return criticalThreatsRadius
  else if (target.track) {
    if (directionGroup?.type == ThreatType.SAM ||
        directionGroup?.type == ThreatType.AI)
      return lethalThreatsRadius
    else
      return criticalThreatsRadius
  }
  else if (directionGroup != null) {
    if (directionGroup?.lethalRangeRel != null)
      return target.rangeRel < directionGroup.lethalRangeRel ? lethalThreatsRadius : nonLethalThreatsRadius
    else if (directionGroup?.type == ThreatType.WEAPON)
      return criticalThreatsRadius
    else
      return nonLethalThreatsRadius
  }
  else
    return nonLethalThreatsRadius
}

let iconRadiusBaseRel = 0.2

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target, directionGroup)

  local targetTypeText = styleText.__merge({
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    fontSize = styleText.fontSize * objectStyle.fontScale
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = 5
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backgroundColor
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.16 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - 0.16 * targetTypeTextSize[1])]
    children = targetTypeText
  }

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  local background = null

  local icon = null
  if (directionGroup != null && directionGroup?.type != null) {
    local backgroundCommands = null
    local iconCommands = null
    if (directionGroup.type == ThreatType.AI) {
      backgroundCommands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0 ]
      ]
      iconCommands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0 ]
      ]
    }
    else if (directionGroup.type == ThreatType.SHIP) {
      backgroundCommands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0 - 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.40 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.40 * iconRadiusRel * 100.0 ]
      ]
      iconCommands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.40 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.40 * iconRadiusRel * 100.0 ]
      ]
    }
    if (backgroundCommands != null)
      background = @() {
        rendObj = ROBJ_VECTOR_CANVAS
        color = backgroundColor
        fillColor = backgroundColor
        lineWidth = baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
        size = flex()
        commands = backgroundCommands
      }
    if (iconCommands != null)
      icon = @() {
        rendObj = ROBJ_VECTOR_CANVAS
        color = color
        fillColor = 0
        lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
        size = flex()
        commands = iconCommands
      }
  }

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))

  return @() {
    watch = attackOpacityRwr,
    size = flex(),
    opacity = attackOpacityRwr.get(),
    pos = [pw(50), ph(50)]
    children = [
      background,
      targetType,
      icon
    ]
  }
}

let rwrTargetsComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      rwrTargetsComponent(style.object)
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style)
  }
}

return tws