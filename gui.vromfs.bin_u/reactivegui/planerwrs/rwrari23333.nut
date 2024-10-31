from "%rGui/globals/ui_library.nut" import *

let rwrSetting = require("%rGui/rwrSetting.nut")

let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let color = Color(10, 202, 10, 250)

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, hdpx(90))
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 1.8
}

let outerCircle = 0.5
let middleCircle = 0.3
let innerCircle = 0.1

function createRwrMark(gridStyle) {
  return styleText.__merge({
    rendObj = ROBJ_TEXT
    pos = [pw(85), ph(-90)]
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    fontSize = gridStyle.fontScale * styleText.fontSize
    text = "RWR"
  })
}

function makeGridCommands() {
  let commands = [
    [VECTOR_ELLIPSE, 0, 0, 100.0, 100.0],
    [VECTOR_ELLIPSE, 0, 0, outerCircle  * 100.0, outerCircle  * 100.0],
    [VECTOR_ELLIPSE, 0, 0, middleCircle * 100.0, middleCircle * 100.0],
    [VECTOR_ELLIPSE, 0, 0, innerCircle  * 100.0, innerCircle  * 100.0] ]
  for (local az = 0.0; az < 360.0; az += 30)
    commands.append([ VECTOR_LINE,
                      math.sin(degToRad(az)) * 100.0, math.cos(degToRad(az)) * 100.0,
                      math.sin(degToRad(az)) * 0.85 * 100.0, math.cos(degToRad(az)) * 0.85 * 100.0])
  return commands
}

let gridCommands = makeGridCommands()

function createGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)]
    size = [pw(100 * gridStyle.scale), ph(100 * gridStyle.scale)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = hdpx(4 * gridStyle.lineWidthScale)
    fillColor = 0
    commands = gridCommands
  }
}

let lethalThreatsRadius = (1.0 + outerCircle) * 0.5
let ambiguousThreatsRadius = (outerCircle + middleCircle) * 0.5
let nonLethalThreatsRadius = (middleCircle + innerCircle) * 0.5

function calcRwrTargetRadius(target, directionGroup) {
  if (directionGroup != null) {
    if (directionGroup?.lethalRangeRel != null) {
      if (target.rangeRel < 0.75 * directionGroup.lethalRangeRel)
        return lethalThreatsRadius
      else if (target.rangeRel < 1.5 * directionGroup.lethalRangeRel)
        return ambiguousThreatsRadius
      else
        return nonLethalThreatsRadius
    }
    else if (directionGroup?.isWeapon)
      return lethalThreatsRadius
    else
      return lethalThreatsRadius - (lethalThreatsRadius - nonLethalThreatsRadius) * target.rangeRel
  }
  else
    return nonLethalThreatsRadius
}

function createRwrTarget(index, settings, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let iconSizeMult = 0.1 * objectStyle.scale

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

  local track = null
  if (target.track) {
    track = @() {
      color = color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4 * objectStyle.lineWidthScale)
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_POLY,
          target.x * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 1.0 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 1.0 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 1.0 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 1.0 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 1.0 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 1.0 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 - 1.0 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.5 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 - 1.0 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.5 * iconSizeMult * 100.0 ]
      ]
    }
  }

  let launchOpacityRwr = Computed(@() (((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local launch = null
  if (target.launch) {
    launch = @() {
      watch = launchOpacityRwr
      color = color
      opacity = launchOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = hdpx(4 * objectStyle.lineWidthScale)
      fillColor = 0
      size = flex()
      commands = [
        [ VECTOR_LINE,
          target.x * targetRadiusRel * 100.0 - 0.67 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.33 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.67 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.33 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 - 0.33 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.67 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.33 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.67 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.67 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 + 0.33 * iconSizeMult * 100.0,
          target.x * targetRadiusRel * 100.0 + 0.67 * iconSizeMult * 100.0,
          target.y * targetRadiusRel * 100.0 - 0.33 * iconSizeMult * 100.0 ]
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
          track,
          launch
        ]
      },
      targetType
    ]
  }
}

let directionGroups = [
  {
    text = "F",
    originalName = "hud/rwr_threat_ai",
    lethalRangeMax = 40000.0
  },
  {
    text = "L",
    originalName = "hud/rwr_threat_pd",
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
    text = "19",
    originalName = "2S6",
    lethalRangeMax = 8000.0
  },    {
    text = "M",
    originalName = "hud/rwr_threat_sam",
    lethalRangeMax = 12000.0
  },
  {
    text = "A",
    originalName = "hud/rwr_threat_aaa",
    lethalRangeMax = 4000.0
  },
  {
    text = "Z",
    originalName = "Z23",
    lethalRangeMax = 2500.0
  },    {
    text = "W",
    originalName = "ARH",
    isWeapon = true
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
        isWeapon = directionGroup?.isWeapon
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
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      createRwrMark(style.grid),
      {
        size = [pw(85), ph(85)]
        children = [
          createGrid(style.grid),
          rwrTargetsComponent(style.object)
        ]
      }
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