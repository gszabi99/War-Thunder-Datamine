from "%rGui/globals/ui_library.nut" import *

let { rwrTargetsTriggers, rwrTargets, CurrentTime } = require("%rGui/twsState.nut")

let {ThreatType, settings} = require("rwrAnAlr67ThreatsLibrary.nut")

let color = Color(10, 202, 10, 250)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud") * 2.0
}

let outerCircle = 0.8
let middleCircle = 0.55
let innerCircle = 0.15

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

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[index]

  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target, directionGroup)

  local targetType = @()
    styleText.__merge({
      rendObj = ROBJ_TEXT
      pos = [pw(target.x * 100.0 * targetRadiusRel), ph(target.y * 100.0 * targetRadiusRel)]
      size = flex()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      fontSize = objectStyle.fontScale * styleText.fontSize
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

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
        rendObj = ROBJ_VECTOR_CANVAS
        color = color
        fillColor = 0
        lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
        size = flex()
        commands = commands
      }
  }

  let attackOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))

  return @() {
    watch = attackOpacityRwr,
    size = flex(),
    opacity = attackOpacityRwr.get(),
    children = [
      {
        pos = [pw(50), ph(50)]
        size = flex()
        children = [
          icon
        ]
      },
      targetType
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