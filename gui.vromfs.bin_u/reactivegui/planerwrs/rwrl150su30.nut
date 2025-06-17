from "%rGui/globals/ui_library.nut" import *

let { format } = require("string")
let { sin, cos } = require("math")
let { degToRad } = require("%sqstd/math_ex.nut")

let { CompassValue } = require("%rGui/planeState/planeFlyState.nut")
let { FlaresCount, ChaffsCount } = require("%rGui/airState.nut")

let { rwrTargetsTriggers, rwrTargets, rwrTargetsOrder } = require("%rGui/twsState.nut")

let { color, iconColorSearch, iconColorTrack, iconColorLaunch, baseLineWidth, styleText, settings, createCompass, rwrTargetsComponent} = require("rwrL150Components.nut")

let ecmSector = degToRad(120.0)
let ecmHalfSectorSin = sin(ecmSector * 0.5)
let ecmHalfSectorCos = cos(ecmSector * 0.5)

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
          [VECTOR_ELLIPSE,  0,  0,  35,  35],
          [VECTOR_ELLIPSE,  0,  0,  70,  70],
          [VECTOR_LINE,     10 * ecmHalfSectorSin,  10 * ecmHalfSectorCos,  80 * ecmHalfSectorSin,  80 * ecmHalfSectorCos],
          [VECTOR_LINE,     10 * ecmHalfSectorSin, -10 * ecmHalfSectorCos,  80 * ecmHalfSectorSin, -80 * ecmHalfSectorCos],
          [VECTOR_LINE,    -10 * ecmHalfSectorSin,  10 * ecmHalfSectorCos, -80 * ecmHalfSectorSin,  80 * ecmHalfSectorCos],
          [VECTOR_LINE,    -10 * ecmHalfSectorSin, -10 * ecmHalfSectorCos, -80 * ecmHalfSectorSin, -80 * ecmHalfSectorCos]
        ]
      }
    ]
  }
}

let obdFontScale = 2.0

function makeTargetButtonColorAndText(priority) {
  let index = rwrTargetsOrder.len() - priority - 1
  let target = index >= 0 && index < rwrTargetsOrder.len() ? rwrTargets[rwrTargetsOrder[index]] : null
  if (target != null && target.valid) {
    local iconColor = iconColorSearch
    let directionGroup = settings.get().directionGroups?[target.groupId]
    if (target.track)
      iconColor = iconColorTrack
    if (target.launch)
      iconColor = iconColorLaunch
    return {
      color = iconColor,
      text  = format("%d\r\n%s", priority + 1, directionGroup != null ? directionGroup.text : settings.get().unknownText)
    }
  }
  else {
    return {
      color = iconColorSearch,
      text  = ""
    }
  }
}

function makeTargetButton(style, pos, priority) {
  return @()
    styleText.__merge({
      watch = rwrTargetsTriggers
      pos = pos,
      rendObj = ROBJ_TEXTAREA,
      behavior = Behaviors.TextArea
      fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
      halign = ALIGN_LEFT,
      valign = ALIGN_CENTER,
    }).__merge(makeTargetButtonColorAndText(priority))
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
            size = const [pw(100), ph(100)],
            children = [
              rwrTargetsComponent(style.object, 70.0),
              createRwrGrid(style.grid)
            ]
          },
          createCompass(style.grid, 70)
        ]
      },
      
      @()
        styleText.__merge({
          watch = CompassValue
          rendObj = ROBJ_TEXTAREA
          behavior = Behaviors.TextArea
          pos = [pw(45), ph(-40)]
          size = const [pw(15), ph(10)]
          halign = ALIGN_CENTER
          valign = ALIGN_TOP
          fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
          text = format("%d", CompassValue.get() > 0.0 ? CompassValue.get() : 360.0 + CompassValue.get())
          children = {
            size = flex()
            rendObj = ROBJ_BOX
            fillColor = Color(0, 0, 0, 0)
            borderColor = color
            borderWidth = baseLineWidth * 1 * style.grid.lineWidthScale
            borderRadius = hdpx(2)
          }
        }),
      
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(120), ph(125)]
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
        text = "ДО"
      }),
      @()
        styleText.__merge({
          watch = ChaffsCount
          rendObj = ROBJ_TEXT
          pos = [pw(135), ph(125)]
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
          text = format("%d", ChaffsCount.get())
        }),
      styleText.__merge({
        rendObj = ROBJ_TEXT
        pos = [pw(120), ph(135)]
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
        text = "ТЦ"
      }),
      @()
        styleText.__merge({
          watch = FlaresCount
          rendObj = ROBJ_TEXT
          pos = [pw(135), ph(135)]
          halign = ALIGN_RIGHT
          valign = ALIGN_CENTER
          fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
          text = format("%d", FlaresCount.get())
        }),
      
      makeTargetButton(style, [pw(-50), ph(-45)], 0),
      makeTargetButton(style, [pw(-50), ph(-10)], 1),
      makeTargetButton(style, [pw(-50), ph( 25)], 2),
      makeTargetButton(style, [pw(-50), ph( 60)], 3),
      makeTargetButton(style, [pw(-50), ph( 95)], 4),
      makeTargetButton(style, [pw(-50), ph(130)], 5),
      
      styleText.__merge({
        pos = [pw(-30), ph(-50)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "ПИЛ",
        halign = ALIGN_CENTER,
        valign = ALIGN_TOP,
      }),
      styleText.__merge({
        pos = [pw(10), ph(-50)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "ТО",
        halign = ALIGN_CENTER,
        valign = ALIGN_TOP,
      }),
      styleText.__merge({
        pos = [pw(40), ph(-50)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "РЭП",
        halign = ALIGN_CENTER,
        valign = ALIGN_TOP,
      }),
      styleText.__merge({
        pos = [pw(75), ph(-50)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "КИСС",
        halign = ALIGN_CENTER,
        valign = ALIGN_TOP,
      }),
      styleText.__merge({
        pos = [pw(110), ph(-50)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "ОПС",
        halign = ALIGN_CENTER,
        valign = ALIGN_TOP,
      }),
      
      styleText.__merge({
        pos = [pw(145), ph(-30)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "Р\r\nЯ\r\nД\r\n1",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(145), ph(10)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "П\r\nП\r\nС",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(145), ph(45)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "З\r\nП\r\nС",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(145), ph(85)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "И\r\nЗ",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      styleText.__merge({
        pos = [pw(145), ph(115)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = "А\r\nВ\r\nТ",
        halign = ALIGN_RIGHT,
        valign = ALIGN_CENTER,
      }),
      
      {
        pos = [pw(-20), ph(145)],
        size = flex(),
        children = [
          {
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS,
            color = color,
            lineWidth = baseLineWidth * 1 * style.grid.lineWidthScale,
            fillColor = color,
            commands = [
              [VECTOR_POLY,  -2,  0,  0,  5, 2, 0]
            ]
          }
        ]
      },
      styleText.__merge({
        pos = [pw(-10), ph(145)],
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale,
        text = format("%.f", settings.get().rangeMax * 0.001)
        halign = ALIGN_CENTER,
        valign = ALIGN_BOTTOM,
      }),
      {
        pos = [pw(10), ph(145)],
        size = flex(),
        children = [
          {
            size = flex()
            rendObj = ROBJ_VECTOR_CANVAS,
            color = color,
            lineWidth = baseLineWidth * 1 * style.grid.lineWidthScale,
            fillColor = color,
            commands = [
              [VECTOR_POLY,  -2,  5,  0,  0, 2, 5]
            ]
          }
        ]
      },
      styleText.__merge({
        pos = [pw(35), ph(145)]
        size = const [pw(25), ph(10)]
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
        text = "СПР"
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = {
          size = flex()
          rendObj = ROBJ_BOX
          fillColor = Color(0, 0, 0, 0)
          borderColor = color
          borderWidth = baseLineWidth * 1 * style.grid.lineWidthScale
          borderRadius = hdpx(2)
        }
      }),
      styleText.__merge({
        pos = [pw(70), ph(145)]
        size = const [pw(25), ph(10)]
        rendObj = ROBJ_TEXTAREA,
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
        text = "ОБЗ",
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = {
          size = flex()
          rendObj = ROBJ_BOX
          fillColor = Color(0, 0, 0, 0)
          borderColor = color
          borderWidth = baseLineWidth * 1 * style.grid.lineWidthScale
          borderRadius = hdpx(2)
        }
      }),
      styleText.__merge({
        pos = [pw(105), ph(145)]
        size = const [pw(25), ph(10)]
        rendObj = ROBJ_TEXTAREA
        behavior = Behaviors.TextArea
        fontSize = style.grid.fontScale * styleText.fontSize * obdFontScale
        text = "НЕОП",
        halign = ALIGN_CENTER
        valign = ALIGN_BOTTOM
        children = {
          size = flex()
          rendObj = ROBJ_BOX
          fillColor = Color(0, 0, 0, 0)
          borderColor = color
          borderWidth = baseLineWidth * 1 * style.grid.lineWidthScale
          borderRadius = hdpx(2)
        }
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