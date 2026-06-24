from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")

let { color, baseLineWidth, styleText, settings, createCompass, rwrTargetsComponent} = require("%rGui/planeRwrs/rwrL150Components.nut")

function createRwrGrid(gridStyle) {
  return {
    size = flex()
    children = [
      {
        size = flex()
        rendObj = ROBJ_VECTOR_CANVAS,
        color = color,
        lineWidth = baseLineWidth * 1 * gridStyle.lineWidthScale,
        fillColor = 0,
        commands = [
          [VECTOR_ELLIPSE,  50,    50,  33,  33],
          [VECTOR_ELLIPSE,  50,    50,  67,  67],
          [VECTOR_ELLIPSE,  50,    50, 100, 100],
          [VECTOR_LINE,     50,   -50,  50, 150],
          [VECTOR_LINE,    -50,    50, 150,  50]
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
        pos = [pw(30), ph(10)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.333)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(64), ph(20)]
        size = flex()
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.667)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(95), ph(30)]
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

function scope(size, scale, style) {
  let verticalScale = style?.verticalScale ?? 1.0
  let isWidthMin = size[0] <= size[1]
  let sizeFunc = isWidthMin ? pw : ph
  let compSize = sizeFunc(scale * style.grid.scale)
  let compSizeVert = sizeFunc(scale * style.grid.scale * verticalScale)
  return {
    size = [compSize, compSizeVert]
    vplace = ALIGN_CENTER
    hplace = ALIGN_CENTER
    children = [
      {
        size = [pw(90), ph(90)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          {
            size = flex()
            children = [
              rwrTargetsComponent(style.object, 100.0),
              createRwrGrid(style.grid),
              rwrGridMarksComponent(style.grid)
            ]
          },
          createCompass(style.grid, 100.0, true)
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
    children = scope(sizeWatched.get(), scale, style)
  }
}

return tws