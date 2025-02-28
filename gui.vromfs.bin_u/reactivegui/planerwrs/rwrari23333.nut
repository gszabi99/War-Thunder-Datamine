from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let math = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder, CurrentTime } = require("%rGui/twsState.nut")

let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")

let { settings } = require("rwrAri23333ThreatsLibrary.nut")

let color = Color(10, 202, 10, 250)
let backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud")
}

let outerCircle = 0.65
let middleCircle = 0.43
let innerCircle = 0.18

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

function createRwrTarget(index, settingsIn, objectStyle) {
  let target = rwrTargets[rwrTargetsOrder[index]]

  if (!target.valid || target.groupId == null)
    return @() { }

  let iconSizeMult = 0.085 * objectStyle.scale

  let directionGroup = target.groupId >= 0 && target.groupId < settingsIn.directionGroups.len() ? settingsIn.directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target, directionGroup)

  let background = {
    color = backgroundColor
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * objectStyle.lineWidthScale
    fillColor = backgroundColor
    size = flex()
    commands = [
      [ VECTOR_ELLIPSE,
        target.x * targetRadiusRel * 100.0,
        target.y * targetRadiusRel * 100.0,
        iconSizeMult * 100.0,
        iconSizeMult * 100.0]
     ]
  }

  local targetTypeText = styleText.__merge({
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    color = color
    fontSize = styleText.fontSize * objectStyle.fontScale
    text = directionGroup != null ? directionGroup.text : settingsIn.unknownText
    padding = [2, 2]
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backgroundColor
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.16 * targetTypeTextSize[0]), ph(target.y * 100.0 * targetRadiusRel - 0.16 * targetTypeTextSize[1])]
    children = @() targetTypeText
  }

  local track = null
  if (target.track) {
    track = @() {
      color = color
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * objectStyle.lineWidthScale
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

  let launchOpacityRwr = Computed(@() (((CurrentTime.get() * 4.0).tointeger() % 2) == 0 ? 0.0 : 1.0))
  local launch = null
  if (target.launch) {
    launch = @() {
      watch = launchOpacityRwr
      color = color
      opacity = launchOpacityRwr.get()
      rendObj = ROBJ_VECTOR_CANVAS
      lineWidth = baseLineWidth * objectStyle.lineWidthScale
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
    pos = [pw(50), ph(50)]
    size = flex()
    children = [
      background,
      targetType,
      track,
      launch
    ]
  }
}

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
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(60), ph(-80)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "RWR"
      }),
      {
        pos = [pw(10), ph(15)]
        size = [pw(85 * style.grid.scale), ph(85 * style.grid.scale)]
        children = [
          createGrid(style.grid),
          rwrTargetsComponent(style.object)
        ]
      },
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-60)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "CHF"
      }),
      @()
        styleText.__merge({
          watch = ChaffsCount
          rendObj = ROBJ_TEXT
          pos = [pw(-100), ph(-50)]
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize
          text = format("%d", ChaffsCount.get())
        }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-100), ph(-25)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "FLR"
      }),
      @()
        styleText.__merge({
          watch = FlaresCount
          rendObj = ROBJ_TEXT
          pos = [pw(-100), ph(-15)]
          size = flex()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize
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