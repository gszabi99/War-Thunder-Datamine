from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, RwrNewTargetHoldTimeInv, CurrentTime } = require("%rGui/twsState.nut")

let ThreatType = {
  AI = 0,
  WEAPON = 1
}

let color = Color(10, 202, 10, 250)

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, hdpx(90))
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.5
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

let iconRadiusBaseRel = 0.2

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
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
      text = directionGroup != null ? directionGroup.text : settings.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  local icon = null
  if (directionGroup != null && directionGroup?.type == ThreatType.AI) {
    icon = @() {
      color = color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4 * objectStyle.lineWidthScale)
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
      lineWidth = hdpx(4 * objectStyle.lineWidthScale)
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

function targetRangeSmaller(left, right, settings) {
  let leftDirectionGroup = left.groupId >= 0 && left.groupId < settings.directionGroups.len() ? settings.directionGroups[left.groupId] : null
  let rightDirectionGroup = right.groupId >= 0 && right.groupId < settings.directionGroups.len() ?
    settings.directionGroups[right.groupId] : null
  if (leftDirectionGroup != null && leftDirectionGroup?.lethalRangeRel != null &&
      rightDirectionGroup != null && rightDirectionGroup?.lethalRangeRel != null) {
    let leftOutsideLethalRangeRel = left.rangeRel - leftDirectionGroup.lethalRangeRel
    let rightOutsideLethalRangeRel = right.rangeRel - rightDirectionGroup.lethalRangeRel
    if (leftOutsideLethalRangeRel < 0.0 && rightOutsideLethalRangeRel < 0.0)
      return left.rangeRel < right.rangeRel
    else
      return leftOutsideLethalRangeRel < rightOutsideLethalRangeRel
  }
  else if ( leftDirectionGroup != null && leftDirectionGroup?.type == ThreatType.WEAPON &&
            rightDirectionGroup != null && rightDirectionGroup?.type == ThreatType.WEAPON)
    return left.rangeRel < right.rangeRel
  else if(leftDirectionGroup != null && (leftDirectionGroup?.lethalRangeRel != null || leftDirectionGroup?.type == ThreatType.WEAPON) &&
          !(rightDirectionGroup != null && (rightDirectionGroup?.lethalRangeRel != null || rightDirectionGroup?.type == ThreatType.WEAPON)))
    return true;
  else if(!(leftDirectionGroup != null && (leftDirectionGroup?.lethalRangeRel != null || leftDirectionGroup?.type == ThreatType.WEAPON)) &&
          rightDirectionGroup != null && (rightDirectionGroup?.lethalRangeRel != null || rightDirectionGroup?.type == ThreatType.WEAPON))
    return false
  else
    return left.rangeRel < right.rangeRel
}

function targetPriorityGreater(left, right, settings) {
  if (left.launch && !right.launch)
    return true
  else if (left.launch && right.launch)
    return targetRangeSmaller(left, right, settings)
  else if (!left.launch && right.launch)
    return false
  else if (left.track && !right.track)
    return true
  else if (left.track && right.track)
    return targetRangeSmaller(left, right, settings)
  else if (!left.track && right.track)
    return false
  else
    return targetRangeSmaller(left, right, settings)
}

function createRwrPriorityTarget(settings, objectStyle) {
  local priorityTarget = null
  for (local i = 0; i < rwrTargets.len(); ++i) {
    let target = rwrTargets[i]
    if (target.valid && target.groupId != null) {
      if (priorityTarget == null || targetPriorityGreater(target, priorityTarget, settings))
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
    lineWidth = hdpx(4 * objectStyle.lineWidthScale)
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

let directionGroups = [
  {
    text = "F",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 5000.0
  },
  {
    text = "A",
    type = ThreatType.AI,
    originalName = "hud/rwr_threat_attacker",
    lethalRangeMax = 8000.0
  },
  {
    text = "21",
    type = ThreatType.AI,
    originalName = "M21"
    lethalRangeMax = 5000.0
  },
  {
    text = "23",
    type = ThreatType.AI,
    originalName = "M23",
    lethalRangeMax = 40000.0
  },
  {
    text = "29",
    type = ThreatType.AI,
    originalName = "M29",
    lethalRangeMax = 40000.0
  },
  {
    text = "F4",
    type = ThreatType.AI,
    originalName = "F4",
    lethalRangeMax = 40000.0
  },
  {
    text = "F5",
    type = ThreatType.AI,
    originalName = "F5",
    lethalRangeMax = 5000.0
  },
  {
    text = "14",
    type = ThreatType.AI,
    originalName = "F14",
    lethalRangeMax = 40000.0
  },
  {
    text = "15",
    type = ThreatType.AI,
    originalName = "F15",
    lethalRangeMax = 40000.0
  },
  {
    text = "16",
    type = ThreatType.AI,
    originalName = "F16",
    lethalRangeMax = 40000.0
  },
  {
    text = "18",
    type = ThreatType.AI,
    originalName = "F18",
    lethalRangeMax = 40000.0
  },
  {
    text = "HR",
    type = ThreatType.AI,
    originalName = "HRR",
    lethalRangeMax = 5000.0
  },
  {
    text = "T",
    type = ThreatType.AI,
    originalName = "TRF",
    lethalRangeMax = 30000.0
  },
  {
    text = "20",
    type = ThreatType.AI,
    originalName = "M2K",
    lethalRangeMax = 40000.0
  },
  //






  {
    text = "3",
    originalName = "S125",
    lethalRangeMax = 16000.0
  },
  {
    text = "8",
    originalName = "93",
    lethalRangeMax = 12000.0
  },
  {
    text = "15",
    originalName = "9K3",
    lethalRangeMax = 12000.0
  },
  {
    text = "RO",
    originalName = "RLD",
    lethalRangeMax = 12000.0
  },
  {
    text = "CR",
    originalName = "CRT",
    lethalRangeMax = 12000.0
  },
  {
    text = "19",
    originalName = "2S6",
    lethalRangeMax = 8000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    lethalRangeMax = 4000.0
  },
  {
    text = "S",
    originalName = "hud/rwr_threat_naval",
    lethalRangeMax = 16000.0
  },
  {
    text = "M",
    originalName = "MSL",
    type = ThreatType.WEAPON
  }
]

let settings = Computed(function() {
  let directionGroupOut = array(rwrSetting.get().direction.len())
  for (local i = 0; i < rwrSetting.get().direction.len(); ++i) {
    let direction = rwrSetting.get().direction[i]
    let directionGroupIndex = directionGroups.findindex(@(directionGroup) loc(directionGroup.originalName) == direction.text)
    if (directionGroupIndex != null) {
      let directionGroup = directionGroups[directionGroupIndex]
      directionGroupOut[i] = {
        text = directionGroup.text
        type = directionGroup?.type
        lethalRangeRel = directionGroup?.lethalRangeMax != null ? (directionGroup.lethalRangeMax - rwrSetting.get().range.x) / (rwrSetting.get().range.y - rwrSetting.get().range.x) : null
      }
    }
  }
  return { directionGroups = directionGroupOut, unknownText = "U" }
})


let rwrTargetsComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

let rwrPriorityTargetComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = createRwrPriorityTarget(settings.get(), objectStyle)
  }
}

return {
  color
  settings
  rwrTargetsComponent
  rwrPriorityTargetComponent
}