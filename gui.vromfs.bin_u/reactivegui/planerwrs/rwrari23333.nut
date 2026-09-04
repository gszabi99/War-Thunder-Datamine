import "math" as math
from "%rGui/twsState.nut" import rwrTargetsTriggers, CurrentTime
from "%rGui/airState.nut" import FlaresCount, ChaffsCount
from "%rGui/planeRwrs/rwrAri23333ThreatsLibrary.nut" import settings
from "string" import format
from "%sqstd/math_ex.nut" import degToRad
from "%rGui/globals/ui_library.nut" import *

let { rwrTargets, rwrTargetsOrder } = require("%rGui/twsState.nut")



const color = Color(10, 202, 10, 250)
const backgroundColor = Color(0, 0, 0, 255)

let baseLineWidth = LINE_WIDTH * 0.5

let styleText = {
  color = color
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud")
}

const outerCircle = 0.65
const middleCircle = 0.43
const innerCircle = 0.18

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
    pos = const [pw(50), ph(50)]
    size = const [pw(100), ph(100)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = 0
    commands = gridCommands
  }
}

const lethalThreatsRadius = (1.0 + outerCircle) * 0.5
const ambiguousThreatsRadius = (outerCircle + middleCircle) * 0.5
const nonLethalThreatsRadius = (middleCircle + innerCircle) * 0.5

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
    size = FLEX
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
    padding = 2
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
      size = FLEX
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
      size = FLEX
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
    pos = const [pw(50), ph(50)]
    size = FLEX
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
    size = FLEX
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
        pos = const [pw(67), ph(-115)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "GUN"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(67), ph(-100)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "RWR"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = const [pw(110), ph(-68)]
        size = FLEX
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "O\nF\nS\nT"
        behavior = Behaviors.TextArea
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = const [pw(110), ph(-25)]
        size = FLEX
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "P\nR\nI"
        behavior = Behaviors.TextArea
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = const [pw(110), ph(15)]
        size = FLEX
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "L\nI\nM"
        behavior = Behaviors.TextArea
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = const [pw(110), ph(55)]
        size = FLEX
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "B\nI\nT"
        behavior = Behaviors.TextArea
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(0), ph(120)]
        size = FLEX
        halign = ALIGN_CENTER,
        valign = ALIGN_CENTER,
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "MENU"
        behavior = Behaviors.TextArea
      }),
      {
        pos = const [pw(10), ph(15)]
        size = [pw(85 * style.grid.scale), ph(85 * style.grid.scale)]
        children = [
          createGrid(style.grid),
          rwrTargetsComponent(style.object)
        ]
      },
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(-100), ph(-60)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "CHF"
      }),
      @()
        styleText.__merge({
          watch = ChaffsCount
          rendObj = ROBJ_TEXT
          pos = const [pw(-100), ph(-50)]
          size = FLEX
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize
          text = format("%d", ChaffsCount.get())
        }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(-100), ph(-25)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize
        text = "FLR"
      }),
      @()
        styleText.__merge({
          watch = FlaresCount
          rendObj = ROBJ_TEXT
          pos = const [pw(-100), ph(-15)]
          size = FLEX
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize
          text = format("%d", FlaresCount.get())
        })
    ]
  }
}

function tws(posWatched, sizeWatched, scale, style) {
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