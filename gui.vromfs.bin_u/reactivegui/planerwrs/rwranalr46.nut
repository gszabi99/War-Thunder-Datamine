from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, CurrentTime } = require("%rGui/twsState.nut")

let ThreatType = {
  AIRBORNE_PULSE = 0,
  AIRBORNE_PULSE_DOPPLER = 1,
  SHIP = 2
}

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 3.0
}

function calcRwrTargetRadius(target) {
  return 0.2 + target.rangeRel * 0.8
}

let iconRadiusBaseRel = 0.15

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)
  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  local targetType = null
  if (directionGroup == null || directionGroup?.text != null) {
    local targetTypeText = styleText.__merge({
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      color = color
      fontSize = objectStyle.fontScale * styleText.fontSize
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
      padding = [2, 2]
    })
    let targetTypeTextSize = calc_comp_size(targetTypeText)
    targetType = @() {
      rendObj = ROBJ_SOLID
      color = backgroundColor
      pos = [pw(target.x * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - 0.125 * targetTypeTextSize[1])]
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
          color = color
          rendObj = ROBJ_VECTOR_CANVAS
          lineWidth = baseLineWidth * (4 + 5) * objectStyle.lineWidthScale
          fillColor = 0
          size = flex()
          commands = iconCommands
        }
      icon = @() {
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
        fillColor = 0
        size = flex()
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
        color = backgroundColor
        opacity = attackOpacityRwr.get()
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
  },
  {
    type = ThreatType.SHIP,
    originalName = "hud/rwr_threat_naval",
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
  return { directionGroups = directionGroupOut, unknownText = "U" }
})

function rwrTargetsComponent(objectStyle) {
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