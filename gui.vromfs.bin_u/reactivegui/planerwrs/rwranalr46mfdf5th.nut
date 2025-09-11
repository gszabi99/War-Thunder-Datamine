from "%rGui/globals/ui_library.nut" import *

let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")
let rwrTargetsComponent = require("%rGui/planeRwrs/rwrAnAlr46Components.nut")
let { MfdRwrFontScale } = require("%rGui/planeState/planeToolsState.nut")

let color = Color(10, 100, 250, 255)
let textColor = Color(10, 255, 10, 255)
let backgroundColor = Color(0, 0, 0, 255)
let baseLineWidth = LINE_WIDTH * 0.6
let osbFontSizeMult = 1.0
let cmsFontSizeMult = 1.3
let iconRadiusBaseRel = 0.15
let styleText = {
  color = textColor
  font = Fonts.hud
  fontFxColor = Color(0, 0, 0, 255)
  fontFxFactor = max(70, baseLineWidth * 90)
  fontFx = FFT_GLOW
  fontSize = getFontDefHt("hud")
}
let gridScale = 0.6

function createNumScale(ringStyle, gridStyle) {
  let numScaleStyle = {
    rendObj = ROBJ_TEXT
    size = flex()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    color = color
    fontSize = gridStyle.fontScale * styleText.fontSize * 1.2 * (MfdRwrFontScale.get() > 0.0 ? MfdRwrFontScale.get() : 1.0)
  }
  return [
    numScaleStyle.__merge({
      pos = [pw(-50), ph(ringStyle.outerCircle * 100.0 - 50.0)]
      text = "30"
    }),
    numScaleStyle.__merge({
      pos = [pw(-50), ph(ringStyle.middleCircle * 100.0 - 50.0)]
      text = "10"
    }),
    numScaleStyle.__merge({
      pos = [pw(-50), ph(ringStyle.innerCircle * 100.0 - 50.0)]
      text = "2"
    }),
  ]
}

function createGrid(gridStyle) {
  let ringStyle = {
    outerCircle  = 1.3
    middleCircle = 0.7
    innerCircle  = 0.3
    diamond      = 0.02
  }
  return {
    pos = [pw(50), ph(50)]
    size = static [pw(100), ph(100)]
    color = color
    rendObj = ROBJ_VECTOR_CANVAS
    lineWidth = baseLineWidth * gridStyle.lineWidthScale
    fillColor = 0
    commands = [
        [VECTOR_ELLIPSE, 0, 0, ringStyle.outerCircle * 100, ringStyle.outerCircle * 100],
        [VECTOR_ELLIPSE, 0, 0, ringStyle.middleCircle * 100, ringStyle.middleCircle * 100],
        [VECTOR_ELLIPSE, 0, 0, ringStyle.innerCircle * 100, ringStyle.innerCircle * 100],
        [VECTOR_ELLIPSE, 0, 0, ringStyle.innerCircle * 100, ringStyle.innerCircle * 100],
        [VECTOR_LINE, 0, ringStyle.outerCircle * 100, 0, ringStyle.middleCircle * 100],
        [VECTOR_LINE, 0, -ringStyle.outerCircle * 100, 0, -ringStyle.middleCircle * 100],
        [VECTOR_LINE, ringStyle.outerCircle * 100, 0, ringStyle.middleCircle * 100, 0],
        [VECTOR_LINE, -ringStyle.outerCircle * 100, 0, -ringStyle.middleCircle * 100, 0],
        [VECTOR_FILL_COLOR, color],
        [VECTOR_POLY, 0, -ringStyle.diamond * 100, ringStyle.diamond * 100, 0, 0, ringStyle.diamond * 100, -ringStyle.diamond * 100, 0]
    ]
    children = createNumScale(ringStyle, gridStyle)
  }
}

function calcRwrTargetRadius(target) {
  return clamp(target.rangeRel, 0.1, 1.0)
}

function scope(scale, style) {
  let styleArgs = {
    calcRwrTargetRadius,
    iconRadiusBaseRel,
    color,
    backgroundColor,
    baseLineWidth,
    styleText
  }
  let fontScale = MfdRwrFontScale.get() > 0.0 ? MfdRwrFontScale.get() : 1.0
  let gridPos = (1.0 - gridScale) * 0.5 * 100
  return @(){
    size = [pw(scale), ph(scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        pos = [(pw(gridPos)), ph(gridPos)]
        size = [pw(100.0 * gridScale * style.grid.scale), ph(100.0 * gridScale * style.grid.scale)]
        children = [
          rwrTargetsComponent(style.object, styleArgs),
          createGrid(style.grid)
        ]
      },
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(32), ph(-55)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_TOP
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * fontScale
        text = "STR\n1"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(65), ph(-55)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_TOP
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * fontScale
        text = "PFM\n1"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-55), ph(-65)]
        size = flex()
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "PRI"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(55), ph(-65)]
        size = flex()
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "EVENT\nMARK"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(55), ph(32)]
        size = flex()
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "CH/F\nWARN\n00/00"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(55), ph(85)]
        size = flex()
        halign = ALIGN_RIGHT
        valign = ALIGN_CENTER
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "MAN\nPROG\n01"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXTAREA
        pos = [pw(-55), ph(32)]
        size = flex()
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "CH/F\nMAN"
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-55), ph(-32)]
        size = flex()
        halign = ALIGN_LEFT
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * osbFontSizeMult * fontScale
        text = "TRCK"
      }),
      @() styleText.__merge({
        rendObj = ROBJ_FRAME
        pos = [pw(-60), ph(95)]
        size = [pw(30), style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        borderWidth = baseLineWidth * 2.0
        children = @(){
          watch = ChaffsCount
          size = flex()
          rendObj = ROBJ_TEXT
          color = Color(10, 255, 10, 255)
          fontSize = style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale
          padding = static [0, 2]
          text = ChaffsCount.get().tostring()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
        }
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(-60), ph(80)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale
        text = "CH"
      }),
      @() styleText.__merge({
        rendObj = ROBJ_FRAME
        pos = [pw(63), ph(95)]
        size = [pw(30), style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        borderWidth = baseLineWidth * 2.0
        children = @(){
          watch = FlaresCount
          size = flex()
          rendObj = ROBJ_TEXT
          color = Color(10, 255, 10, 255)
          fontSize = style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale
          padding = static [0, 2]
          text = FlaresCount.get().tostring()
          halign = ALIGN_CENTER
          valign = ALIGN_CENTER
        }
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(60), ph(80)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale
        text = "F"
      }),
      @() styleText.__merge({
        watch = [FlaresCount, ChaffsCount]
        rendObj = ROBJ_TEXT
        pos = [pw(0), ph(95)]
        size = flex()
        color = FlaresCount.get() + ChaffsCount.get() > 0 ? textColor : Color(255, 255, 10, 255)
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * cmsFontSizeMult * fontScale
        text = FlaresCount.get() + ChaffsCount.get() > 0 ? "CH/F - ARM" : "CH/F - SAFE"
      }),
    ]
  }
}

function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched, MfdRwrFontScale]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(scale, style)
  }
}

return tws