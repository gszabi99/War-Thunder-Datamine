from "%rGui/globals/ui_library.nut" import *

let { E3DCOLOR } = require("dagor.math")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

enum AzimuthScaleType {
  gates = 0
  lines = 1
  dots  = 2
}

enum CenterMarkType {
  cross     = 0
  plane     = 1
  circle    = 2
  heli      = 3
  triangle  = 4
}

enum Orient {
  hdgUp   = 0
  northUp = 1
}

let pages = {
  hsd = "%rGui/planeCockpit/hsd.das"
  
}

let hsdSettings = Watched({
  scriptPath = pages.hsd
  color = E3DCOLOR(255, 255, 255, 255)
  fontId = Fonts.hud
  fontSize = 10
  lineWidth = 1.0
  lineColor = E3DCOLOR(255, 255, 255, 255)
  orient = Orient.hdgUp
  centerMarkType = CenterMarkType.cross
  centerMarkFillColor = E3DCOLOR(255, 255, 255, 255)
  centerMarkLineColor = E3DCOLOR(255, 255, 255, 255)
  centerMarkScale = 0.1
  centerMarkSpeed = true
  spi = true
  spiColor = E3DCOLOR(255, 255, 255, 255)
  spiInfo = true
  spiInfoOffset = 0.0
  distScale = true
  distScaleBeyondAzScale = false
  distScaleStepSize = 5000.0
  distScaleColor = E3DCOLOR(255, 255, 255, 255)
  distScaleNumbers = true
  distScaleNumbersAngle = 45.0
  distScaleNumbersFillColor = E3DCOLOR(255, 255, 255, 255)
  azScaleType = AzimuthScaleType.gates
  azScaleSize = 10000.0
  azScaleColor = E3DCOLOR(255, 255, 255, 255)
  headingIndFillColor = E3DCOLOR(255, 255, 255, 255)
  centerCross = true
  time = true
  mapBackground = true
  markers = true
  extent = 20000.0
  metricUnits = false
})

function hsdSettingsUpd(page_blk) {
  assert(page_blk.getReal("ringScaleMin", 0.2) < page_blk.getReal("ringScaleMax", 0.8), $"ringScaleMin must be smaller than ringScaleMax")
  let scriptType = page_blk.getStr("customHsd", "")
  hsdSettings.set({
    scriptPath = pages?[scriptType] ?? pages.hsd
    color = page_blk.getE3dcolor("color", E3DCOLOR(255, 255, 255, 255))
    fontId = Fonts?[page_blk.getStr("font", "hud")] ?? Fonts.hud
    fontSize = max(page_blk.getInt("fontSize", 10), 1)
    lineWidth = max(page_blk.getReal("lineWidth", 1.0), 1.0)
    lineColor = page_blk.getE3dcolor("lineColor", E3DCOLOR(255, 255, 255, 255))
    orient = Orient?[page_blk.getStr("orient", "hdgUp")] ?? Orient.hdgUp
    centerMarkType = CenterMarkType?[page_blk.getStr("centerMarkType", "cross")] ?? CenterMarkType.cross
    centerMarkFillColor = page_blk.getE3dcolor("centerMarkFillColor", E3DCOLOR(255, 255, 255, 255))
    centerMarkLineColor = page_blk.getE3dcolor("centerMarkLineColor", E3DCOLOR(255, 255, 255, 255))
    centerMarkScale = clamp(page_blk.getReal("centerMarkScale", 0.1), 0.01, 1.0)
    centerMarkSpeed = page_blk.getBool("centerMarkSpeed", true)
    spi = page_blk.getBool("spi", true)
    spiColor = page_blk.getE3dcolor("spiColor", E3DCOLOR(255, 255, 255, 255))
    spiInfo = page_blk.getBool("spiInfo", true)
    spiInfoOffset = page_blk.getReal("spiInfoOffset", 0.0)
    distScale = page_blk.getBool("distScale", true)
    distScaleBeyondAzScale = page_blk.getBool("distScaleBeyondAzScale", false)
    distScaleStepSize = max(page_blk.getReal("distScaleStepSize", 5000.0), 1.0)
    distScaleColor = page_blk.getE3dcolor("distScaleColor", E3DCOLOR(255, 255, 255, 255))
    distScaleNumbers = page_blk.getBool("distScaleNumbers", true)
    distScaleNumbersAngle = clamp(page_blk.getReal("distScaleNumbersAngle", 45.0), 0.0, 360.0)
    distScaleNumbersFillColor = page_blk.getE3dcolor("distScaleNumbersFillColor", E3DCOLOR(255, 255, 255, 255))
    azScaleType = AzimuthScaleType?[page_blk.getStr("azScaleType", "gates")] ?? AzimuthScaleType.gates
    azScaleSize = max(page_blk.getReal("azScaleSize", 10000.0), 1.0)
    azScaleColor = page_blk.getE3dcolor("azScaleColor", E3DCOLOR(255, 255, 255, 255))
    headingIndFillColor = page_blk.getE3dcolor("headingIndFillColor", E3DCOLOR(255, 255, 255, 255))
    centerCross = page_blk.getBool("centerCross", true)
    time = page_blk.getBool("time", true)
    mapBackground = page_blk.getBool("mapBackground", true)
    markers = page_blk.getBool("markers", true)
    extent = max(page_blk.getReal("extent", 20000.0), 1.0)
    metricUnits = page_blk.getBool("metricUnits", false)
  })
}

let hsd = @(pos_size) function() {
  let {
    scriptPath,
    color,
    fontId,
    fontSize,
    lineWidth,
    lineColor,
    orient,
    centerMarkType,
    centerMarkFillColor,
    centerMarkLineColor,
    centerMarkScale,
    centerMarkSpeed,
    spi,
    spiColor,
    spiInfo,
    spiInfoOffset,
    distScale,
    distScaleBeyondAzScale,
    distScaleStepSize,
    distScaleColor,
    distScaleNumbers,
    distScaleNumbersAngle,
    distScaleNumbersFillColor,
    azScaleType,
    azScaleColor,
    azScaleSize,
    headingIndFillColor,
    centerCross,
    time,
    mapBackground,
    markers,
    extent,
    metricUnits
  } = hsdSettings.get()
  return {
    watch = [hsdSettings, pos_size]
    pos = [pos_size.get()[0], pos_size.get()[1]]
    size = [pos_size.get()[2], pos_size.get()[3]]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath(scriptPath)
    drawFunc = "render"
    setupFunc = "setup"
    color
    fontId
    fontSize
    lineWidth
    lineColor
    orient
    centerMarkType
    centerMarkFillColor
    centerMarkLineColor
    centerMarkScale
    centerMarkSpeed
    spi
    spiColor
    spiInfo
    spiInfoOffset
    distScale
    distScaleBeyondAzScale
    distScaleStepSize
    distScaleColor
    distScaleNumbers
    distScaleNumbersAngle
    distScaleNumbersFillColor
    azScaleType
    azScaleSize
    azScaleColor
    headingIndFillColor
    centerCross
    time
    mapBackground
    markers
    extent
    metricUnits
  }
}

return {
  hsd
  hsdSettingsUpd
}
