from "%rGui/twsState.nut" import rwrTargetsTriggers, CurrentTime
from "%rGui/planeRwrs/rwrAnAlr46ThreatsLibrary.nut" import settings
from "%rGui/globals/ui_library.nut" import *

let { rwrTargets, rwrTargetsOrder } = require("%rGui/twsState.nut")
let { ThreatType } = require("%rGui/planeRwrs/rwrAnAlr46ThreatsLibrary.nut")

function createRwrTarget(index, settingsIn, objectStyle, args) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = args.calcRwrTargetRadius(target)
  let iconRadiusRel = args.iconRadiusBaseRel * objectStyle.scale

  local targetType = null
  if (directionGroup == null || directionGroup?.text != null) {
    local targetTypeText = args.styleText.__merge({
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(-50), ph(-50)]
      color = args.color
      fontSize = objectStyle.fontScale * args.styleText.fontSize
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
      padding = 2
    })
    targetType = @() {
      rendObj = ROBJ_SOLID
      size = SIZE_TO_CONTENT
      color = args.backgroundColor
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      children = targetTypeText
    }
  }

  local background = null

  local icon = null
  if (directionGroup != null && directionGroup?.type != null) {
    local iconCommands = null
    if (directionGroup.type == ThreatType.AIRBORNE_PULSE)
      iconCommands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.10 * iconRadiusRel * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.AIRBORNE_PULSE_DOPPLER)
      iconCommands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.75 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.10 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.25 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.10 * iconRadiusRel * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.SHIP)
      iconCommands = []
    if (iconCommands != null) {
      if (!target.launch && !target.priority)
        background = @() {
          color = args.color
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = args.baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
          fillColor = 0
          size = FLEX
          commands = iconCommands
        }
      icon = @() {
        color = args.color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = args.baseLineWidth * 4 * objectStyle.lineWidthScale
        fillColor = 0
        size = FLEX
        commands = iconCommands
      }
    }
  }

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local launch = null
  if (target.launch) {
    let launchCommands = [
      [ VECTOR_ELLIPSE,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0,
        iconRadiusRel * 100.0,
        iconRadiusRel * 100.0 ]
    ]
    if (!target.priority)
      background = @() {
        watch = attackOpacityRwr
        color = args.backgroundColor
        opacity = attackOpacityRwr.get()
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = args.baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
        fillColor = args.backgroundColor
        size = FLEX
        commands = launchCommands
      }
    launch = @() {
      watch = attackOpacityRwr
      color = args.color
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = args.baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = FLEX
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
      color = args.backgroundColor
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = args.baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
      fillColor = args.backgroundColor
      size = FLEX
      pos = const [pw(0), ph(0)]
      commands = priorityCommands
    }
    priority = @() {
      color = args.color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = args.baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = FLEX
      pos = const [pw(0), ph(0)]
      commands = priorityCommands
    }
  }

  return @() {
    pos = const [pw(50), ph(50)]
    size = FLEX
    children = [
      background,
      targetType,
      icon,
      launch,
      priority
    ]
  }
}

function rwrTargetsComponent(objectStyle, styleArgs) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = FLEX
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle, styleArgs))
  }
}

return rwrTargetsComponent