from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let { color, baseLineWidth, outerCircle,  middleCircle, innerCircle } = require("rwrAnAlr67Parameters.nut")

let ThreatType = {
  AI = 0,
  AAA = 1,
  SAM = 2,
  SHIP = 3,
  WEAPON = 4
}

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.5
}

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

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target, directionGroup)

  local targetType = @()
    styleText.__merge({
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      fontSize = objectStyle.fontScale * styleText.fontSize
      text = directionGroup != null ? directionGroup.text : settings.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local attack = null
  if (target.track || target.launch) {
    attack = @() {
      watch = attackOpacityRwr
      color = color
      opacity = attackOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_SECTOR,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0,
          0.50 * iconRadiusRel * 100.0,
          0.50 * iconRadiusRel * 100.0,
          0, 180]
       ]
    }
  }

  local icon = null
  if (directionGroup != null && directionGroup?.type != null) {
    local commands = null
    if (directionGroup.type == ThreatType.AI)
      commands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.AAA)
      commands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.40 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.60 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.40 * iconRadiusRel * 100.0 ],
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.10 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 1.00 * iconRadiusRel * 100.0 ],
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.10 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 1.00 * iconRadiusRel * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.SAM)
      commands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.75 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.50 * iconRadiusRel * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.50 * iconRadiusRel * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.25 * iconRadiusRel * 100.0 ]
      ]
    else if (directionGroup.type == ThreatType.SHIP)
      commands = [
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
    if (commands != null)
      icon = @() {
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
        fillColor = 0
        size = flex()
        commands = commands
      }
  }

  return @() {
    size = flex()
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          attack,
          icon
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

  let priorityDirectionGroup = priorityTarget.groupId >= 0 && priorityTarget.groupId < settings.directionGroups.len() ? settings.directionGroups[priorityTarget.groupId] : null
  let priorityTargetRadiusRel = calcRwrTargetRadius(priorityTarget, priorityDirectionGroup)
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

let directionGroups = [
  {
    text = "F",
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_attacker",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "21",
    originalName = "M21",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "23",
    originalName = "M23",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "29",
    originalName = "M29",
    type = ThreatType.AI,
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
    originalName = "F5",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "14",
    originalName = "F14",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "15",
    originalName = "F15",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "16",
    originalName = "F16",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "18",
    originalName = "F18",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "HR",
    originalName = "HRR",
    type = ThreatType.AI,
    lethalRangeMax = 5000.0
  },
  {
    text = "T",
    originalName = "TRF",
    type = ThreatType.AI,
    lethalRangeMax = 30000.0
  },
  {
    text = "20",
    originalName = "M2K",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "39",
    originalName = "J39",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  {
    text = "JF",
    originalName = "J17",
    type = ThreatType.AI,
    lethalRangeMax = 40000.0
  },
  //







  {
    text = "3",
    originalName = "S125",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "8",
    originalName = "93",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "15",
    originalName = "9K3",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "RO",
    originalName = "RLD",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "CR",
    originalName = "CRT",
    type = ThreatType.SAM,
    lethalRangeMax = 12000.0
  },
  {
    text = "19",
    originalName = "2S6",
    lethalRangeMax = 8000.0
  },
  {
    text = "AD",
    originalName = "ADS",
    lethalRangeMax = 8000.0
  },
  {
    text = "AR",
    originalName = "ASR",
    lethalRangeMax = 8000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    type = ThreatType.AAA,
    lethalRangeMax = 4000.0
  },
  {
    originalName = "hud/rwr_threat_sam",
    type = ThreatType.SAM,
    lethalRangeMax = 16000.0
  },
  {
    text = "S",
    originalName = "hud/rwr_threat_naval",
    type = ThreatType.SHIP,
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
        text = directionGroup?.text
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
  color,
  baseLineWidth,
  outerCircle,
  middleCircle,
  innerCircle,
  rwrTargetsComponent,
  rwrPriorityTargetComponent
}