from "%rGui/planeRwrs/rwrL150Components.nut" import color, baseLineWidth, settings, createCompass, rwrTargetsComponent
from "string" import format
from "%rGui/globals/ui_library.nut" import *

let { styleText } = require("%rGui/planeRwrs/rwrL150Components.nut")

function createRwrGrid(gridStyle) {
  return {
    size = FLEX
    children = [
      {
        size = FLEX
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
  const gridFontSizeMult = 2.0
  return {
    size = FLEX,
    children = [
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(30), ph(10)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.333)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(64), ph(20)]
        size = FLEX
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = gridStyle.fontScale * styleText.fontSize * gridFontSizeMult
        text = format("%.f", settingsIn.rangeMax * 0.001 * 0.667)
      }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = const [pw(95), ph(30)]
        size = FLEX
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
    size = FLEX
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
        size = const [pw(90), ph(90)]
        vplace = ALIGN_CENTER
        hplace = ALIGN_CENTER
        children = [
          {
            size = FLEX
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

function tws(posWatched, sizeWatched, scale, style) {
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = scope(sizeWatched.get(), scale, style)
  }
}

return { tws, scope }
