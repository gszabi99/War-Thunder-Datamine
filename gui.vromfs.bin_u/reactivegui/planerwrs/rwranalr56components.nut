from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsTriggers, rwrTargets, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let {ThreatType, settings} = require("rwrAnAlr56ThreatsLibrary.nut")

let color = Color(10, 202, 10, 250)

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
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  let newTargetFontSizeMultRwr = Computed(@() (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))
  local targetType = @()
    styleText.__merge({
      watch = newTargetFontSizeMultRwr
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      fontSize = styleText.fontSize * objectStyle.fontScale * newTargetFontSizeMultRwr.get()
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  local icon = null
  if (directionGroup != null && directionGroup?.type == ThreatType.AI) {
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
    launch = @() {
      watch = attackOpacityRwr
      color = color
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_ELLIPSE,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0,
          iconRadiusRel * 100.0,
          iconRadiusRel * 100.0]
       ]
    }
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          icon,
          launch
        ]
      },
      targetType
    ]
  }
}

function createRwrPriorityTarget(objectStyle) {
  local priorityTarget = null
  for (local i = 0; i < rwrTargets.len(); ++i) {
    let target = rwrTargets[i]
    if (target.valid && target?.priority) {
      priorityTarget = target
    }
  }
  if (priorityTarget == null || !priorityTarget.valid || priorityTarget.groupId == null)
    return @() { }

  let priorityTargetRadiusRel = calcRwrTargetRadius(priorityTarget)

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale
  local priority = @() {
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
    fillColor = 0
    size = flex()
    pos = [pw(0), ph(0)]
    commands = [
      [ VECTOR_POLY,
        priorityTarget.x * priorityTargetRadiusRel * 100.0 - iconRadiusRel * 100.0,
        priorityTarget.y * priorityTargetRadiusRel * 100.0,
        priorityTarget.x * priorityTargetRadiusRel * 100.0,
        priorityTarget.y * priorityTargetRadiusRel * 100.0 - iconRadiusRel * 100.0,
        priorityTarget.x * priorityTargetRadiusRel * 100.0 + iconRadiusRel * 100.0,
        priorityTarget.y * priorityTargetRadiusRel * 100.0,
        priorityTarget.x * priorityTargetRadiusRel * 100.0,
        priorityTarget.y * priorityTargetRadiusRel * 100.0 + iconRadiusRel * 100.0 ]
    ]
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          priority
        ]
      }
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

let rwrPriorityTargetComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers ]
    size = flex()
    children = createRwrPriorityTarget(objectStyle)
  }
}

return {
  color,
  baseLineWidth,
  styleText,
  settings,
  calcRwrTargetRadius,
  rwrTargetsComponent,
  rwrPriorityTargetComponent
}