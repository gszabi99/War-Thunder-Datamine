from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { E3DCOLOR } = require("dagor.math")
let { BlkFileName } = require("%rGui/planeState/planeToolsState.nut")

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
  hsd = @() load_das("%rGui/planeCockpit/hsd.das")
  
}

let hsdSettings = Computed(function() {
  let res = {
    getDasScript = pages.hsd
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
  }

  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  let cockpitBlk = blk.getBlockByName("cockpit")
  if (!cockpitBlk)
    return res
  let mfdBlk = cockpitBlk.getBlockByName("multifunctionDisplays")
  if (!mfdBlk)
    return res
  for (local i = 0; i < mfdBlk.blockCount(); ++i) {
    let displayBlk = mfdBlk.getBlock(i)
    for (local j = 0; j < displayBlk.blockCount(); ++j) {
      let pageBlk = displayBlk.getBlock(j)
      let typeStr = pageBlk.getStr("type", "")
      if (typeStr != "hsd")
        continue
      assert(pageBlk.getReal("ringScaleMin", 0.2) < pageBlk.getReal("ringScaleMax", 0.8), $"ringScaleMin must be smaller than ringScaleMax")
      let scriptType = pageBlk.getStr("customHsd", "")
      return {
        getDasScript = pages?[scriptType] ?? pages["hsd"]
        color = pageBlk.getE3dcolor("color", E3DCOLOR(255, 255, 255, 255))
        fontId = Fonts?[pageBlk.getStr("font", "hud")] ?? Fonts.hud
        fontSize = max(pageBlk.getInt("fontSize", 10), 1)
        lineWidth = max(pageBlk.getReal("lineWidth", 1.0), 1.0)
        lineColor = pageBlk.getE3dcolor("lineColor", E3DCOLOR(255, 255, 255, 255))
        orient = Orient?[pageBlk.getStr("orient", "hdgUp")] ?? Orient.hdgUp
        centerMarkType = CenterMarkType?[pageBlk.getStr("centerMarkType", "cross")] ?? CenterMarkType.cross
        centerMarkFillColor = pageBlk.getE3dcolor("centerMarkFillColor", E3DCOLOR(255, 255, 255, 255))
        centerMarkLineColor = pageBlk.getE3dcolor("centerMarkLineColor", E3DCOLOR(255, 255, 255, 255))
        centerMarkScale = clamp(pageBlk.getReal("centerMarkScale", 0.1), 0.01, 1.0)
        centerMarkSpeed = pageBlk.getBool("centerMarkSpeed", true)
        spi = pageBlk.getBool("spi", true)
        spiColor = pageBlk.getE3dcolor("spiColor", E3DCOLOR(255, 255, 255, 255))
        spiInfo = pageBlk.getBool("spiInfo", true)
        distScale = pageBlk.getBool("distScale", true)
        distScaleBeyondAzScale = pageBlk.getBool("distScaleBeyondAzScale", false)
        distScaleStepSize = max(pageBlk.getReal("distScaleStepSize", 5000.0), 1.0)
        distScaleColor = pageBlk.getE3dcolor("distScaleColor", E3DCOLOR(255, 255, 255, 255))
        distScaleNumbers = pageBlk.getBool("distScaleNumbers", true)
        distScaleNumbersAngle = clamp(pageBlk.getReal("distScaleNumbersAngle", 45.0), 0.0, 360.0)
        distScaleNumbersFillColor = pageBlk.getE3dcolor("distScaleNumbersFillColor", E3DCOLOR(255, 255, 255, 255))
        azScaleType = AzimuthScaleType?[pageBlk.getStr("azScaleType", "gates")] ?? AzimuthScaleType.gates
        azScaleSize = max(pageBlk.getReal("azScaleSize", 10000.0), 1.0)
        azScaleColor = pageBlk.getE3dcolor("azScaleColor", E3DCOLOR(255, 255, 255, 255))
        headingIndFillColor = pageBlk.getE3dcolor("headingIndFillColor", E3DCOLOR(255, 255, 255, 255))
        centerCross = pageBlk.getBool("centerCross", true)
        time = pageBlk.getBool("time", true)
        mapBackground = pageBlk.getBool("mapBackground", true)
        markers = pageBlk.getBool("markers", true)
        extent = max(pageBlk.getReal("extent", 20000.0), 1.0)
        metricUnits = pageBlk.getBool("metricUnits", false)
      }
    }
  }
  return res
})

let hsd = @(width, height, pos_x = 0, pos_y = 0) function() {
  let {
    getDasScript,
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
    watch = [hsdSettings]
    size = [width, height]
    pos = [pos_x, pos_y]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScript()
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

return hsd
