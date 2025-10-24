from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")

let { color, baseLineWidth, styleText, settings, createCompass, rwrTargetsComponent} = require("%rGui/planeRwrs/rwrL150Components.nut")

function createRwrGrid(gridStyle) {
  return {
    pos = [pw(50), ph(50)],
    size = flex(),
    children = [
      {
        size = flex()
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
  let gridFontSizeMult = 2.0
  return {
    size = flex(),
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(30), ph(10)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.333)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(64), ph(20)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.667)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [ph(95), ph(30)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 1.0)
      })
    ]
  }
}

function rwrGridMarksComponent(gridStyle) {
  return @() {
    watch = settings
    size = flex()
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
        pos = [pw(7), ph(0)],
        size = const [pw(90), ph(90)],
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