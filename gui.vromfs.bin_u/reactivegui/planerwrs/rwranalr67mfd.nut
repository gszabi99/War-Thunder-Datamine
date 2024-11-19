from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")

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
  fontSize = getFontDefHt("hud") * 2.0 * 0.5
}

let outerCircle = 0.8
let middleCircle = 0.65
let innerCircle = 0.2

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
    size = [pw(100), ph(100)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = 0
    commands = gridCommands
  }
}

let iconRadiusBaseRel = 0.135

function calcRwrTargetRadiusBetween(target, inner, outer) {
  return (1.0 - target.rangeRel) * (inner + iconRadiusBaseRel * 0.5) + target.rangeRel * (outer - iconRadiusBaseRel * 0.5)
}

function calcRwrTargetRadius(target, directionGroup) {
  if (target.launch)
    return calcRwrTargetRadiusBetween(target, innerCircle, middleCircle)
  else if (target.track) {
    if (directionGroup?.type == ThreatType.SAM ||
        directionGroup?.type == ThreatType.AI)
      return calcRwrTargetRadiusBetween(target, middleCircle, outerCircle)
    else
      return calcRwrTargetRadiusBetween(target, innerCircle, middleCircle)
  }
  else if (directionGroup != null) {
    if (directionGroup?.lethalRangeRel != null)
      return target.rangeRel < directionGroup.lethalRangeRel ? calcRwrTargetRadiusBetween(target, middleCircle, outerCircle) :
        calcRwrTargetRadiusBetween(target, outerCircle, 1.0)
    else if (directionGroup?.type == ThreatType.WEAPON)
      return calcRwrTargetRadiusBetween(target, innerCircle, middleCircle)
    else
      return calcRwrTargetRadiusBetween(target, outerCircle, 1.0)
  }
  else
    return calcRwrTargetRadiusBetween(target, outerCircle, 1.0)
}

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
      fontSize = styleText.fontSize * objectStyle.fontScale
      text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    })

  let iconRadiusRel = iconRadiusBaseRel * objectStyle.scale

  let launchOpacityRwr = Computed(@() (target.launch && ((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local attack = null
  if (target.track || target.launch) {
    attack = @() {
      watch = launchOpacityRwr
      color = color
      opacity = launchOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * objectStyle.lineWidthScale
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
        lineWidth = baseLineWidth * objectStyle.lineWidthScale
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

let rwrTargetsComponent = function(objectStyle) {
  return @() {
    watch = [ rwrTargetsTriggers, settings ]
    size = flex()
    children = rwrTargets.map(@(_, i) createRwrTarget(i, settings.get(), objectStyle))
  }
}

let counterMeasureFontSizeMult = 1.0

function scope(scale, style) {
  return {
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(65), ph(-95)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "RWR"
      }),
      {
        pos = [pw(10), ph(10)]
        size = [pw(100.0 * 0.8 * style.grid.scale), ph(100.0 * 0.8 * style.grid.scale)]
        children = [
          createGrid(style.grid),
          rwrTargetsComponent(style.object)
        ]
      },
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-65)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * counterMeasureFontSizeMult
        text = "CHF"
      }),
      @() styleText.__merge({
        watch = ChaffsCount
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-55)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * counterMeasureFontSizeMult
        text = format("%d", ChaffsCount.get())
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-32)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * counterMeasureFontSizeMult
        text = "FLR"
      }),
      @() styleText.__merge({
        watch = FlaresCount
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-22)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * counterMeasureFontSizeMult
        text = format("%d", FlaresCount.get())
      })
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