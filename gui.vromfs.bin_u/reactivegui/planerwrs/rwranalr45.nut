from "%rGui/globals/ui_library.nut" import *

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let rwrSetting = require("%rGui/rwrSetting.nut")

let { rwrTargetsTriggers, rwrTargets } = require("%rGui/twsState.nut")

let color = Color(10, 202, 10, 250)

let baseLineWidth = LINE_WIDTH * 0.5

function makeGridCommands() {
  let commands = []
  let step = 0.15
  for (local r = step; r < step * 3.5; r += step)
    commands.append([ VECTOR_ELLIPSE, 0, 0, r * 100.0, r * 100.0 ])
  for (local az = 0.0; az < 360.0; az += 10)
    commands.append([ VECTOR_LINE,
                      math.sin(degToRad(az)) * 100.0, math.cos(degToRad(az)) * 100.0,
                      math.sin(degToRad(az)) * 0.85 * 100.0, math.cos(degToRad(az)) * 0.85 * 100.0])
  return commands
}

let gridCommands = makeGridCommands()

function createGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = flex()
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * 2 * gridStyle.lineWidthScale
    fillColor = 0
    commands = gridCommands
  }
}

let ThreatType = {
  BAND_LOW = 0,
  BAND_MID = 1,
  BAND_HI = 2
}

function calcRwrTargetRadius(target) {
  return 1.0 - 0.85 * target.rangeRel
}

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.directionGroups.len() ? settings.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)

  local azimuth = null
  if (directionGroup != null && directionGroup?.type != null) {
    local commands = null
    if (directionGroup.type == ThreatType.BAND_LOW)
      commands = [ [ VECTOR_LINE, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0] ]
    else if (directionGroup.type == ThreatType.BAND_MID)
      commands = [ [ VECTOR_LINE_DASHED, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 5, 20] ]
    else if (directionGroup.type == ThreatType.BAND_HI)
      commands = [ [ VECTOR_LINE_DASHED, 0, 0, target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0, 20, 40] ]
    if (commands != null)
      azimuth = @() {
        color = color
        rendObj = ROBJ_VECTOR_CANVAS
        lineWidth = baseLineWidth * 10 * objectStyle.lineWidthScale
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
    originalName = "LO",
    type = ThreatType.BAND_LOW
  },
  {
    originalName = "MID",
    type = ThreatType.BAND_MID
  },
  {
    originalName = "HI",
    type = ThreatType.BAND_HI
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
      createGrid(style.grid),
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