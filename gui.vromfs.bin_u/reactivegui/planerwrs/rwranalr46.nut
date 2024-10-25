from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let ThreatType = {
  AIRBORNE_PULSE = 0,
  AIRBORNE_PULSE_DOPPLER = 1
}

let color = Color(10, 202, 10, 250)

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, hdpx(90))
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 1.5
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

let iconRadiusRel = 0.2

function createRwrTarget(index, settings, fontSizeMult) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  local targetType = null
  if (directionGroup == null || directionGroup?.text != null)
    targetType = @()
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = fontSizeMult * styleText.fontSize
        text = directionGroup != null ? directionGroup.text : "U"
      })

  local icon = null
  if (directionGroup != null && directionGroup?.type != null) {
    local commands = null
    if (directionGroup.type == ThreatType.AIRBORNE_PULSE)
      commands = [
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
      commands = [
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
    if (commands != null)
      icon = @() {
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = hdpx(4)
        fillColor = 0
        size = flex()
        commands = commands
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
      lineWidth = hdpx(4)
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
  else if (leftDirectionGroup != null && leftDirectionGroup?.lethalRangeRel != null &&
          !(rightDirectionGroup != null && rightDirectionGroup?.lethalRangeRel != null))
    return true
  else if (!(leftDirectionGroup != null && leftDirectionGroup?.lethalRangeRel != null) &&
          rightDirectionGroup != null && rightDirectionGroup?.lethalRangeRel != null)
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

function createRwrPriorityTarget(settings) {
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

  local priority = @() {
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4)
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
    originalName = "hud/rwr_threat_ai",
    type = ThreatType.AIRBORNE_PULSE,
    lethalRangeMax = 20000.0
  },
  {
    originalName = "hud/rwr_threat_pd",
    type = ThreatType.AIRBORNE_PULSE_DOPPLER,
    lethalRangeMax = 40000.0
  },
  //






  {
    text = "3",
    originalName = "S125",
    lethalRangeMax = 16000.0
  },
  {
    text = "15",
    originalName = "9K3",
    lethalRangeMax = 12000.0
  },
  {
    text = "R",
    originalName = "RLD",
    lethalRangeMax = 12000.0
  },
  {
    text = "C",
    originalName = "CRT",
    lethalRangeMax = 12000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    lethalRangeMax = 4000.0
  }
]

let settings = Computed(function() {
  let directionGroupOut = array(rwrSetting.get().direction.len())
  directionGroupOut.resize(rwrSetting.get().direction.len())
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
  return { directionGroups = directionGroupOut }
})

function rwrTargetsComponent(fontSizeMult) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), fontSizeMult))
  }
}

function rwrPriorityTargetComponent() {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = createRwrPriorityTarget(settings.get())
  }
}

function scope(scale, fontSizeMult) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      rwrTargetsComponent(fontSizeMult),
      rwrPriorityTargetComponent()
    ]
  }
}

let function tws(posWatched, sizeWatched, scale, fontSizeMult) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, fontSizeMult)
  }
}

return tws