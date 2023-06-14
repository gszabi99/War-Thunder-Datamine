from "%rGui/globals/ui_library.nut" import *

let { IlsPosSize, IlsMask, IsIlsEnabled, IndicatorsVisible, IsMfdEnabled, SecondaryMask, HudColor } = require("airState.nut")
let { paramsTable, horSpeed, vertSpeed, rocketAim, taTarget } = require("airHudElems.nut")
let compass = require("compass.nut")
let { hudFontHgt, fontOutlineColor, fontOutlineFxFactor } = require("style/airHudStyle.nut")

let styleLineForeground = {
  fillColor = Color(0, 0, 0, 0)
  lineWidth = max(hdpx(LINE_WIDTH), LINE_WIDTH)
  font = Fonts.hud
  fontFxColor = fontOutlineColor
  fontFxFactor = fontOutlineFxFactor
  fontFx = FFT_GLOW
  fontSize = hudFontHgt * 2
}

let pilotSh = @(h) h * IlsPosSize[3] / 100

let pilotSw = @(w) w * IlsPosSize[2] / 100

let pilotHdpx = @(px) px * IlsPosSize[3] / 1024

let mfdPilotParamsTablePos = Watched([0, 300])

let mfdPilotParamsTable = paramsTable(IlsMask, SecondaryMask,
  800, 50,
  mfdPilotParamsTablePos,
  10,  false)

let function compassComponent(style, size, pos) {
  return @() {
    pos
    watch = HudColor
    children = compass(size, HudColor.value, style)
  }
}

let function ilsHud(elemStyle) {
  let ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = HudColor.value
    fontSize = getFontDefHt("hud") * 2
  })
  return @() {
    watch = [IsIlsEnabled, HudColor]
    pos = [IlsPosSize[0], IlsPosSize[1]]
    children = IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(HudColor, false, ilsStyle)
      vertSpeed(pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), HudColor.value, ilsStyle)
      horSpeed(HudColor.value, pilotSw(50), pilotSh(80), pilotHdpx(100), ilsStyle)
      compassComponent(ilsStyle, [pilotSw(100), pilotSh(13)], [pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15)])
    ]
    : null
  }
}

let function ilsMovingMarks(style) {
  let ilsStyle = style.__merge({
    lineWidth = LINE_WIDTH * 3
    color = HudColor.value
  })
  return @() {
    watch = [IsIlsEnabled, HudColor]
    children = IsIlsEnabled.value ?
    [
      rocketAim(pilotSw(4), pilotSh(8), HudColor.value, ilsStyle)
      taTarget(pilotSw(25), pilotSh(25))
    ]
    : null
  }
}

let function ilsHUD(style) {
  return [
    ilsHud(style)
    ilsMovingMarks(style)
  ]
}

let function Root() {
  let children = ilsHUD(styleLineForeground)

  return {
    watch = [
      IndicatorsVisible
      IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = (IndicatorsVisible.value || IsMfdEnabled.value) ? children : null
  }
}


return Root