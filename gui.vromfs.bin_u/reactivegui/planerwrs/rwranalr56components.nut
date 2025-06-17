from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let {ThreatType, settings} = require("rwrAnAlr56ThreatsLibrary.nut")

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.5
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

let iconRadiusBaseRel = 0.2

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)
  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  let newTargetFontSizeMultRwr = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))

  local targetTypeText = styleText.__merge({
    watch = newTargetFontSizeMultRwr
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    color = color
    fontSize = styleText.fontSize * objectStyle.fontScale * newTargetFontSizeMultRwr.get()
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = 2
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backgroundColor
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[1])]
    children = @() targetTypeText
  }

  local background = null

  local icon = null
  if (directionGroup != null && directionGroup?.type == ThreatType.AI) {
    if (!target.launch && !target.priority)
      background = @() {
        watch = newTargetFontSizeMultRwr
        color = backgroundColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
        fillColor = backgroundColor
        size = flex()
        commands = [
          [ VECTOR_POLY,
            target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
            target.x * targetRadiusRel * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
            target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
            target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0 ]
         ]
      }
    icon = @() {
      color = color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0 ]
      ]
    }
  }

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local launch = null
  if (target.launch) {
    let launchCommands = [
      [ VECTOR_ELLIPSE,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0,
        iconRadiusRel * 125.0,
        iconRadiusRel * 125.0]
     ]
    if (!target.priority)
      background = @() {
        watch = newTargetFontSizeMultRwr
        color = backgroundColor
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
        fillColor = backgroundColor
        size = flex()
        commands = launchCommands
      }
    launch = @() {
      watch = attackOpacityRwr
      color = color
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = flex()
      commands = launchCommands
    }
  }

  local priority = null
  if (target.priority) {
    let priorityCommands = [
      [ VECTOR_POLY,
        target.x * targetRadiusRel * 100.0 - iconRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0 - iconRadiusRel * 100.0,
        target.x * targetRadiusRel * 100.0 + iconRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0 + iconRadiusRel * 100.0 ]
    ]
    background = @() {
      color = backgroundColor
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
      fillColor = backgroundColor
      size = flex()
      pos = [pw(0), ph(0)]
      commands = priorityCommands
    }
    priority = @() {
      color = color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = flex()
      pos = [pw(0), ph(0)]
      commands = priorityCommands
    }
  }

  return @() {
    pos = [pw(50), ph(50)]
    size = flex()
    children = [
      background,
      targetType,
      icon,
      launch,
      priority
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

return {
  color,
  backgroundColor,
  baseLineWidth,
  styleText,
  settings,
  calcRwrTargetRadius,
  rwrTargetsComponent
}