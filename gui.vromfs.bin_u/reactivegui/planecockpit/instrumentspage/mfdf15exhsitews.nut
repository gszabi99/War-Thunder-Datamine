from "%rGui/utils/cacheDasScriptForView.nut" import getDasScriptByPath
from "%rGui/planeRwrs/rwrAnAlr56Components.nut" import color, backgroundColor, baseLineWidth, calcRwrTargetRadius, styleText
from "%rGui/planeRwrs/rwrAnAlr56ThreatsLibrary.nut" import settings
from "%rGui/twsState.nut" import rwrTargetsTriggers, RwrNewTargetHoldTimeInv, CurrentTime, rwrTargets
from "%rGui/planeState/planeFlyState.nut" import CompassValue
from "%rGui/airState.nut" import FlaresCount, ChaffsCount
from "string" import format
from "math" import sin, cos, PI
from "%sqstd/math_ex.nut" import degToRad
from "dagor.math" import E3DCOLOR
from "%rGui/globals/ui_library.nut" import *

const gridFontSizeMult = 0.5

let tewsStyle = {
  grid   = { scale = 0.5, lineWidthScale = 0.7, fontScale = 0.7 }
  object = { scale = 1.0, lineWidthScale = 0.7, fontScale = 0.7 }
}

function createOuterGrid(gridStyle) {
  return {
    pos = const [pw(50), ph(50)]
    size = FLEX
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = color
    commands = [
      [ VECTOR_POLY,   -5, -100,    5, -100,   0, -95 ],
      [ VECTOR_POLY,   -5,  100,    5,  100,   0,  95 ],
      [ VECTOR_POLY, -100,   -5, -100,    5, -95,   0 ],
      [ VECTOR_POLY,  100,   -5,  100,    5,  95,   0 ]
    ]
  }
}

function makeInnerGridCommands() {
  let commands = [
    [VECTOR_LINE, -10,   0, -5,  0],
    [VECTOR_LINE,   5,   0, 10,  0],
    [VECTOR_LINE,   0, -10,  0, -5],
    [VECTOR_LINE,   0,   5,  0, 10]
  ]
  for (local az = 15.0; az < 360.0; az += 30)
    commands.append([VECTOR_ELLIPSE, sin(degToRad(az)) * 90.0, cos(degToRad(az)) * 90.0, 1, 1])
  return commands
}

let innerGridCommands = makeInnerGridCommands()

function createInnerGrid(gridStyle) {
  return {
    rendObj = ROBJ_VECTOR_CANVAS
    pos = const [pw(50), ph(50)]
    size = FLEX
    color = color
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = color
    commands = innerGridCommands
  }
}

function createCompass(gridStyle) {
  const compassColor = Color(5, 100, 5, 250)
  const markAngleStep = 5.0
  const markAngle = PI * markAngleStep / 180.0
  let markDashCount = (360.0 / markAngleStep).tointeger()
  const azimuthMarkLength = 4

  let commands = array(markDashCount).map(@(_, i) [
    VECTOR_LINE,
    50 + cos(i * markAngle) * (100 - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + sin(i * markAngle) * (100 - ((i % 2 == 0) ? 1.0 : 0.5) * azimuthMarkLength),
    50 + cos(i * markAngle) * 100,
    50 + sin(i * markAngle) * 100
  ])

  const textAngleStep = 30.0
  const textMarkAngle = PI * textAngleStep / 180.0
  const textDashCount = 360.0 / textAngleStep
  local azimuthMarks = []
  for (local i = 0; i < textDashCount; ++i) {
    let labelAngle = i * textAngleStep
    azimuthMarks.append({
      rendObj = ROBJ_TEXT
      pos = [pw(sin(i * textMarkAngle) * 91), ph(-cos(i * textMarkAngle) * 91)]
      size = FLEX
      color = compassColor
      font = styleText.font
      fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
      text = (labelAngle * 0.1).tointeger()
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      behavior = Behaviors.RtPropUpdate
      update = @() { transform = { rotate = CompassValue.get() } }
    })
  }

  return {
    rendObj = ROBJ_VECTOR_CANVAS
    size = FLEX
    color = compassColor
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = 0
    commands = commands
    children = azimuthMarks
    behavior = Behaviors.RtPropUpdate
    update = @() { transform = { rotate = -CompassValue.get() } }
  }
}

function createRwrTarget(index, objectStyle) {
  let target = rwrTargets[index]
  if (!target.valid || target.groupId == null)
    return @() { }

  let directionGroup = target.groupId >= 0 && target.groupId < settings.get().directionGroups.len()
    ? settings.get().directionGroups[target.groupId] : null
  let targetRadiusRel = calcRwrTargetRadius(target)
  let iconRadiusRel = 0.2 * objectStyle.scale

  let newTargetFontSizeMultRwr = Computed(@()
    (target.age0 * RwrNewTargetHoldTimeInv.get() < 1.0 && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 1.5 : 1.0))

  local targetTypeText = styleText.__merge({
    watch = newTargetFontSizeMultRwr
    rendObj = ROBJ_TEXT
    size = SIZE_TO_CONTENT
    fontSize = styleText.fontSize * objectStyle.fontScale * newTargetFontSizeMultRwr.get()
    text = directionGroup != null ? directionGroup.text : settings.get().unknownText
    padding = 2
  })
  let targetTypeTextSize = calc_comp_size(targetTypeText)
  local targetType = @() {
    rendObj = ROBJ_SOLID
    color = backgroundColor
    pos = [pw(target.x * 100.0 * targetRadiusRel - 0.25 * targetTypeTextSize[0]),
           ph(target.y * 100.0 * targetRadiusRel - 0.25 * targetTypeTextSize[1])]
    children = @() targetTypeText
  }

  let attackOpacityRwr = Computed(@()
    (target.launch && ((CurrentTime.get() * 2.0).tointeger() % 2) == 0 ? 0.0 : 1.0))

  local launch = null
  local background = null
  if (target.launch) {
    let launchCmds = [[VECTOR_ELLIPSE,
      target.x * targetRadiusRel * 100.0, target.y * targetRadiusRel * 100.0,
      iconRadiusRel * 100.0, iconRadiusRel * 100.0]]
    background = @() {
      watch = attackOpacityRwr
      rendObj = ROBJ_VECTOR_CANVAS
      size = FLEX
      lineWidth = baseLineWidth * 9 * objectStyle.lineWidthScale
      color = backgroundColor
      fillColor = backgroundColor
      opacity = attackOpacityRwr.get()
      commands = launchCmds
    }
    launch = @() {
      watch = attackOpacityRwr
      rendObj = ROBJ_VECTOR_CANVAS
      size = FLEX
      lineWidth = baseLineWidth * 4 * objectStyle.lineWidthScale
      color = color
      fillColor = 0
      opacity = attackOpacityRwr.get()
      commands = launchCmds
    }
  }

  return @() {
    pos = const [pw(50), ph(50)]
    size = FLEX
    children = [background, targetType, launch]
  }
}

let rwrTargetsComponent = @(objectStyle) @() {
  watch = [rwrTargetsTriggers, settings]
  size = FLEX
  children = rwrTargets.map(@(_, i) createRwrTarget(i, objectStyle))
}

function makeTewsScope(size) {
  let gs = tewsStyle.grid
  let os = tewsStyle.object
  let minSide = (size[0] < size[1] ? size[0] : size[1]).tointeger()
  let scopeSide = (minSide * gs.scale).tointeger()
  let labelFontSize = gs.fontScale * styleText.fontSize * gridFontSizeMult
  return {
    size
    clipChildren = true
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      {
        size = [scopeSide, scopeSide]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          createOuterGrid(gs)
          {
            pos = const [pw(5), ph(5)]
            size = const [pw(90), ph(90)]
            children = [
              createCompass(gs)
              {
                pos = const [pw(5), ph(5)]
                size = const [pw(90), ph(90)]
                children = [createInnerGrid(gs), rwrTargetsComponent(os)]
              }
            ]
          }
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(-35), ph(-102)]
            size = FLEX
            halign = ALIGN_LEFT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "PWR"
          })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(-70)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "D" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(-64)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "C" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(-58)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "L" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(42)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "A" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(48)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "U" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(54)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "T" })
          styleText.__merge({ rendObj = ROBJ_TEXT  pos = const [pw(-95), ph(60)]  size = FLEX  halign = ALIGN_CENTER  valign = ALIGN_CENTER  fontSize = labelFontSize  text = "O" })
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(35), ph(-102)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "CHF"
          })
          @() styleText.__merge({
            watch = ChaffsCount
            rendObj = ROBJ_TEXT
            pos = const [pw(48), ph(-102)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = format("%d", ChaffsCount.get())
          })
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(35), ph(-92)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "FLR"
          })
          @() styleText.__merge({
            watch = FlaresCount
            rendObj = ROBJ_TEXT
            pos = const [pw(48), ph(-92)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = format("%d", FlaresCount.get())
          })
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(48), ph(-79)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "CMD"
          })
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(48), ph(-69)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "SEMI"
          })
          styleText.__merge({
            rendObj = ROBJ_TEXT
            pos = const [pw(48), ph(-59)]
            size = FLEX
            halign = ALIGN_RIGHT
            valign = ALIGN_CENTER
            fontSize = labelFontSize
            text = "BOTH"
          })
        ]
      }
    ]
  }
}

function makeHsi(pos, size) {
  let side = (size[0] < size[1] ? size[0] : size[1]).tointeger()
  return {
    pos
    size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    clipChildren = true
    children = {
      size = [side, side]
      hplace = ALIGN_CENTER
      vplace = ALIGN_CENTER
      rendObj   = ROBJ_DAS_CANVAS
      script    = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/hsi.das")
      drawFunc  = "render"
      setupFunc = "setup"
      lineColor = E3DCOLOR(0xFFFFFFFF)
      fontId    = Fonts.hud
      fontSize  = 14
      lineWidth = 1.5
    }
  }
}

function mfdF15exHsiTews(pos, size) {
  let w = size[0]
  let h = size[1]
  let tewsH = (h * 0.60).tointeger()
  let hsiH  = h - tewsH
  return {
    pos
    size
    clipChildren = true
    children = [
      makeTewsScope([w, tewsH])
      makeHsi([0, tewsH], [w, hsiH])
    ]
  }
}

return mfdF15exHsiTews
