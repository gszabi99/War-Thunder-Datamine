from "%rGui/globals/ui_library.nut" import *

let { IlsPosSize, IlsMask, IsIlsEnabled, IndicatorsVisible, IsMfdEnabled, SecondaryMask, HudColor } = require("%rGui/airState.nut")
let { paramsTable, horSpeed, vertSpeed, rocketAim, taTarget } = require("%rGui/airHudElems.nut")
let compass = require("%rGui/compass.nut")
let { hudFontHgt, fontOutlineColor, fontOutlineFxFactor } = require("%rGui/style/airHudStyle.nut")

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

function compassComponent(style, size, pos) {
  return @() {
    pos
    watch = HudColor
    children = compass(size, HudColor.get(), style)
  }
}

function ilsHud(elemStyle) {
  let ilsStyle = elemStyle.__merge({
    lineWidth = LINE_WIDTH * 3
    color = HudColor.get()
    fontSize = getFontDefHt("hud") * 2
  })
  return @() {
    watch = [IsIlsEnabled, HudColor]
    pos = [IlsPosSize[0], IlsPosSize[1]]
    children = IsIlsEnabled.get() ?
    [
      mfdPilotParamsTable(HudColor, false, ilsStyle)
      vertSpeed(pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), HudColor.get(), ilsStyle)
      horSpeed(HudColor.get(), pilotSw(50), pilotSh(80), pilotHdpx(100), ilsStyle)
      compassComponent(ilsStyle, [pilotSw(100), pilotSh(13)], [pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15)])
    ]
    : null
  }
}

function ilsMovingMarks(style) {
  let ilsStyle = style.__merge({
    lineWidth = LINE_WIDTH * 3
    color = HudColor.get()
  })
  return @() {
    watch = [IsIlsEnabled, HudColor]
    children = IsIlsEnabled.get() ?
    [
      rocketAim(pilotSw(4), pilotSh(8), HudColor.get(), ilsStyle)
      taTarget(pilotSw(25), pilotSh(25), true)
    ]
    : null
  }
}

function ilsHUD(style) {
  return [
    ilsHud(style)
    ilsMovingMarks(style)
  ]
}

function Root() {
  let children = ilsHUD(styleLineForeground)

  return @(){
    watch = [
      IndicatorsVisible
      IsMfdEnabled
    ]
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = static [sw(100), sh(100)]
    children = (IndicatorsVisible.get() || IsMfdEnabled.get()) ? children : null
  }
}


return Root