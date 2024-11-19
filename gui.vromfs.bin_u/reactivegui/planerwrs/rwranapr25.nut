from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")

let ThreatType = {
  BAND_E = 0,
  BAND_G = 1,
  BAND_I = 2
}

function calcRwrTargetRadius(target) {
  return 1.0 - 0.8 * target.rangeRel
}

let color = Color(10, 202, 10, 250)

let baseLineWidth = LINE_WIDTH * 0.5

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  local azimuth = null
  if (directionGroup != null && directionGroup?.type != null) {
    local commands = null
    if (directionGroup.type == ThreatType.BAND_E)
      commands = [ [ VECTOR_LINE, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0] ]
    else if (directionGroup.type == ThreatType.BAND_G)
      commands = [ [ VECTOR_LINE_DASHED, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 10, 20] ]
    else if (directionGroup.type == ThreatType.BAND_I)
      commands = [ [ VECTOR_LINE_DASHED, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 20, 40] ]
    if (commands != null)
      azimuth = @() {
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 20 * objectStyle.lineWidthScale
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
        children = azimuth
      }
    ]
  }
}

let directionGroups = [
  {
    originalName = "E",
    type = ThreatType.BAND_E
  },
  {
    originalName = "G",
    type = ThreatType.BAND_G
  },
  {
    originalName = "I",
    type = ThreatType.BAND_I
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
        type = directionGroup?.type
      }
    }
  }
  return { directionGroups = directionGroupOut }
})

let rwrTargetsComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale * 0.85 * style.grid.scale), ph(scale * 0.85 * style.grid.scale)]
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