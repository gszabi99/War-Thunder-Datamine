local {IlsPosSize, IlsMask, IsIlsEnabled, IndicatorsVisible, IsMfdEnabled, SecondaryMask} = require("airState.nut")
local {paramsTable, compassElem, horSpeed, vertSpeed, rocketAim, taTarget} = require("airHudElems.nut")

local pilotSh = @(h) h * IlsPosSize[3] / 100

local pilotSw = @(w) w * IlsPosSize[2] / 100

local pilotHdpx = @(px) px * IlsPosSize[3] / 1024

local mfdPilotParamsTablePos = Watched([50, 550])

local mfdPilotParamsTable = paramsTable(IlsMask, SecondaryMask,
  600, 50,
  mfdPilotParamsTablePos,
  10,  false, true)

local function ilsHud(isBackground) {
  return @(){
    watch = IsIlsEnabled
    pos = [IlsPosSize[0], IlsPosSize[1]]
    children = IsIlsEnabled.value ?
    [
      mfdPilotParamsTable(isBackground)
      vertSpeed(pilotSh(5), pilotSh(40), pilotSw(50) + pilotHdpx(330), pilotSh(45), isBackground)
      horSpeed(isBackground, pilotSw(50), pilotSh(80), pilotHdpx(100))
      compassElem(isBackground, [pilotSw(100), pilotSh(13)], [pilotSw(50) - 0.5 * pilotSw(100), pilotSh(15)])
    ]
    : null
  }
}

local function ilsMovingMarks(isBackground) {
  return @(){
    watch = IsIlsEnabled
    children = IsIlsEnabled.value ?
    [
      rocketAim(pilotSw(4), pilotSh(8), isBackground)
      taTarget(pilotSw(25), pilotSh(25), isBackground)
    ]
    : null
  }
}

local function ilsHUD(isBackground) {
  return [
    ilsHud(isBackground)
    ilsMovingMarks(isBackground)
  ]
}

local function Root() {
  local children = ilsHUD(true)
  children.extend(ilsHUD(false))

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