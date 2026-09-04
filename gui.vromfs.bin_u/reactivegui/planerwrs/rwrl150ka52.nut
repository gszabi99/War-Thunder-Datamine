from "%rGui/airState.nut" import FlaresCount, ChaffsCount
from "%rGui/planeRwrs/rwrL150Components.nut" import color, settings, createCompass, rwrTargetsComponent
from "string" import format
from "%rGui/globals/ui_library.nut" import *

let { styleText } = require("%rGui/planeRwrs/rwrL150Components.nut")

const baseColor = Color(10, 255, 10)
const baseLineWidth = 3
const baseFontSize = 15
const whiteColor = Color(255, 255, 255)

function createRwrGrid(gridStyle) {
  return {
    pos = const [pw(50), ph(50)],
    size = FLEX,
    children = [
      {
        size = FLEX
        rendObj = ROBJ_VECTOR_CANVAS,
        color = color,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE,  0,    0,  33,  33],
          [VECTOR_ELLIPSE,  0,    0,  67,  67],
          [VECTOR_ELLIPSE,  0,    0, 100, 100],
          [VECTOR_LINE,     0, -100,   0, 100],
          [VECTOR_LINE,  -100,    0, 100,   0]
        ]
      }
    ]
  }
}

function createRwrGridMarks(gridStyle, settingsIn) {
  const gridFontSizeMult = 2.0
  return {
    size = FLEX,
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [ph(22), ph(8)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult * 0.7
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.333)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [ph(58), ph(8)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult * 0.7
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.667)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [ph(92), ph(8)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult * 0.7
        text = format("%.f", settingsIn.rangeMax * 0.001 * 1.0)
      })
    ]
  }
}

function rwrGridMarksComponent(gridStyle) {
  return @() {
    watch = settings
    size = FLEX
    children = createRwrGridMarks(gridStyle, settings.get())
  }
}

function scope(scale, style) {
  return {
    size = [pw(scale * style.grid.scale), ph(scale * style.grid.scale)]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        pos = const [pw(22), ph(17)],
        size = const [pw(70), ph(70)],
        children = [
          {
            size = const [ph(100), ph(100)],
            children = [
              rwrTargetsComponent(style.object, 100.0),
              createRwrGrid(style.grid),
              rwrGridMarksComponent(style.grid)
            ]
          },
          createCompass(style.grid, 100.0)
        ]
      }
    ]
  }
}

let labels = {
  size = FLEX
  children = [
    {
      rendObj = ROBJ_VECTOR_CANVAS
      pos = const [pw(-14), ph(-13)]
      size = const [pw(100), ph(100)]
      color = whiteColor
      fillColor = Color(0, 0, 0, 0)
      lineWidth = 1
      commands = [
        [VECTOR_RECTANGLE, 0, 0, 130, 130]
      ]
    }
    {
      rendObj = ROBJ_SOLID
      color = baseColor
      size = const [pw(6), ph(3)]
      pos = const [pw(100), ph(2)]
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(-3), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ПЛТ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(13), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "НВГ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(30), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ОВО"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(46), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "БКО"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(63), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ОПС"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(80), ph(-20)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "АСП"
    }
    {
      rendObj = ROBJ_SOLID
      color = baseColor
      size = const [pw(8), ph(3)]
      pos = const [pw(82), ph(95)]
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(10), ph(119)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ДР"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(23), ph(119)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "КОНТР"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(88), ph(-5)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ЛТЦ"
    }
    {
      rendObj = ROBJ_TEXT
      size = SIZE_TO_CONTENT
      pos = const [pw(88), ph(8)]
      color = whiteColor
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "ДО"
    }
  ]
}

let chaff = {
  rendObj = ROBJ_FRAME
  size = const [pw(15), ph(10)]
  pos = const [pw(55), ph(-40)]
  borderColor = color
  borderWidth = baseLineWidth
  borderRadius = hdpx(5)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "CHAFF"
    }
    @(){
      watch = ChaffsCount
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ils31
      fontSize = baseFontSize
      text = ChaffsCount.get().tostring()
    }
  ]
}

let flare = {
  rendObj = ROBJ_FRAME
  size = const [pw(15), ph(10)]
  pos = const [pw(55), ph(-53)]
  borderColor = color
  borderWidth = baseLineWidth
  borderRadius = hdpx(10)
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = [
    {
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ils31
      fontSize = baseFontSize
      text = "FLARE"
    }
    @(){
      watch = FlaresCount
      rendObj = ROBJ_TEXT
      color = color
      font = Fonts.ils31
      fontSize = baseFontSize
      text = FlaresCount.get().tostring()
    }
  ]
}

function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
     scope(scale, style)
     labels
     chaff
     flare
    ]
  }
}

return tws