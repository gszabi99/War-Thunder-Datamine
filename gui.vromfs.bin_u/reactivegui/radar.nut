from "%rGui/globals/ui_library.nut" import *
let { hudFontHgt } = require("style/airHudStyle.nut")
let { MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode } = require("radarState.nut")
let dasRadarHud = load_das("%rGui/radar.das")
let dasRadarIndication = load_das("%rGui/radarIndication.das")
let su27tactic = load_das("%rGui/planeCockpit/su27tactic.das")
let jas39radar = load_das("%rGui/planeCockpit/mfdJas39radar.das")
let DataBlock = require("DataBlock")
let { IPoint3 } = require("dagor.math")
let {BlkFileName} = require("%rGui/planeState/planeToolsState.nut")

function radarHud(width, height, x, y, color_watched, has_txt_block = false) {
  return @(){
    watch = color_watched
    size = [width, height]
    pos = [x, y]
    rendObj = ROBJ_DAS_CANVAS
    script = dasRadarHud
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = Fonts.hud
    fontSize = hudFontHgt
    hasTxtBlock = has_txt_block
  }
}

let targetFormTypes = {
  "triangle" : 1,
  "square" : 2
}

let beamShapes = {
  "beam" : 0,
  "caret" : 1
}

let customPages = {
  su27tactic,
  jas39radar
}

let radarSettings = Computed(function() {
  let res = {
    lineWidth = 1.0
    lineColor = IPoint3(0, 255, 0)
    modeColor = IPoint3(0, 255, 0)
    verAngleColor = IPoint3(0, 255, 0)
    horAngleColor = IPoint3(0, 255, 0)
    scaleColor = IPoint3(0, 255, 0)
    targetColor = IPoint3(0, 255, 0)
    hideVerAngle = false
    hideHorAngle = false
    hideLaunchZone = false
    hideScale = false
    hideBeam = false
    hasAviaHorizont = false
    fontId = Fonts.hud
    targetFormType = 0
    backgroundColor = IPoint3(0, 0, 0)
    beamShape = 0
    netRowCnt = 0
    netColor = IPoint3(0, 255, 0)
    hideWeaponIndication = false
    showScanAzimuth = false
    cueHeights = false
    script = dasRadarHud
    centerRadar = false
    cueTopHeiColor = IPoint3(0, 255, 0)
    cueLowHeiColor = IPoint3(0, 255, 0)
    cueUndergroundColor = IPoint3(0, 255, 0)
    isMetricUnits = false
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
      if (typeStr != "radar" && typeStr != "radar_b_round")
        continue
      let targetType = pageBlk.getStr("targetForm", "")
      let beamType = pageBlk.getStr("beamShape", "beam")
      let scriptType = pageBlk.getStr("customRadar", "")
      return {
        lineWidth = pageBlk.getReal("lineWidth", 1.0)
        lineColor = pageBlk.getIPoint3("lineColor", IPoint3(-1, -1, -1))
        modeColor = pageBlk.getIPoint3("modeColor", IPoint3(-1, -1, -1))
        verAngleColor = pageBlk.getIPoint3("verAngleColor", IPoint3(-1, -1, -1))
        horAngleColor = pageBlk.getIPoint3("horAngleColor", IPoint3(-1, -1, -1))
        scaleColor = pageBlk.getIPoint3("scaleColor", IPoint3(-1, -1, -1))
        targetColor = pageBlk.getIPoint3("targetColor", IPoint3(-1, -1, -1))
        hideVerAngle = pageBlk.getBool("hideVerAngle", false)
        hideHorAngle = pageBlk.getBool("hideHorAngle", false)
        hideLaunchZone = pageBlk.getBool("hideLaunchZone", false)
        hideScale = pageBlk.getBool("hideScale", false)
        hideBeam = pageBlk.getBool("hideBeam", false)
        hasAviaHorizont = pageBlk.getBool("hasAviaHorizont", false)
        fontId = Fonts?[pageBlk.getStr("font", "hud")] ?? Fonts.hud
        targetFormType = targetFormTypes?[targetType] ?? 0
        backgroundColor = pageBlk.getIPoint3("backgroundColor", IPoint3(0, 0, 0))
        beamShape = beamShapes?[beamType] ?? 0
        netRowCnt = pageBlk.getInt("netRowCnt", 0)
        netColor = pageBlk.getIPoint3("netColor", IPoint3(-1, -1, -1))
        hideWeaponIndication = pageBlk.getBool("hideWeaponIndication", false)
        showScanAzimuth = pageBlk.getBool("showScanAzimuth", false)
        cueHeights = pageBlk.getBool("showCueHeights", false)
        script = customPages?[scriptType] ?? dasRadarHud
        centerRadar = pageBlk.getBool("centerRadar", false)
        cueTopHeiColor = pageBlk.getIPoint3("cueTopHeiColor", IPoint3(-1, -1, -1))
        cueLowHeiColor = pageBlk.getIPoint3("cueLowHeiColor", IPoint3(-1, -1, -1))
        cueUndergroundColor = pageBlk.getIPoint3("cueUndergroundColor", IPoint3(-1, -1, -1))
        isMetricUnits = pageBlk.getBool("isMetricUnits", false)
      }
    }
  }
  return res
})

let radarMfd = @(pos_and_size, color_watched) function() {
  let { lineWidth, lineColor, modeColor, verAngleColor, scaleColor, hideBeam, hideLaunchZone, hideScale,
   hideHorAngle, hideVerAngle, horAngleColor, targetColor, fontId, hasAviaHorizont, targetFormType,
   backgroundColor, beamShape, netRowCnt, netColor, hideWeaponIndication, cueHeights,
   showScanAzimuth, script, centerRadar, cueTopHeiColor, cueLowHeiColor, cueUndergroundColor, isMetricUnits } = radarSettings.get()
  return {
    watch = [color_watched, MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode, pos_and_size, radarSettings]
    size = [pos_and_size.value.w, pos_and_size.value.h]
    pos = [pos_and_size.value.x, pos_and_size.value.y]
    rendObj = ROBJ_DAS_CANVAS
    script
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = fontId
    fontSize = (MfdRadarFontScale.value > 0 ? MfdRadarFontScale.value : pos_and_size.value.h / 512.0) * 30
    hideBackground = MfdRadarHideBkg.value
    enableByMfd = true
    mode = MfdViewMode.value
    lineWidth
    lineColor = lineColor.x < 0 ? color_watched.value : Color(lineColor.x, lineColor.y, lineColor.z, 255)
    modeColor = modeColor.x < 0 ? color_watched.value : Color(modeColor.x, modeColor.y, modeColor.z, 255)
    verAngleColor = verAngleColor.x < 0 ? color_watched.value : Color(verAngleColor.x, verAngleColor.y, verAngleColor.z, 255)
    horAngleColor = horAngleColor.x < 0 ? color_watched.value : Color(horAngleColor.x, horAngleColor.y, horAngleColor.z, 255)
    scaleColor = scaleColor.x < 0 ? color_watched.value : Color(scaleColor.x, scaleColor.y, scaleColor.z, 255)
    targetColor = targetColor.x < 0 ? color_watched.value : Color(targetColor.x, targetColor.y, targetColor.z, 255)
    hideBeam
    hideLaunchZone
    hideScale
    hideHorAngle
    hideVerAngle
    hasAviaHorizont
    targetFormType
    backgroundColor = Color(backgroundColor.x, backgroundColor.y, backgroundColor.z, 255)
    beamShape
    netRowCnt
    netColor = netColor.x < 0 ? color_watched.value : Color(netColor.x, netColor.y, netColor.z, 255)
    hideWeaponIndication
    showScanAzimuth
    cueHeights
    centerRadar
    cueTopHeiColor = cueTopHeiColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueTopHeiColor.x, cueTopHeiColor.y, cueTopHeiColor.z, 255)
    cueLowHeiColor = cueLowHeiColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueLowHeiColor.x, cueLowHeiColor.y, cueLowHeiColor.z, 255)
    cueUndergroundColor = cueUndergroundColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueUndergroundColor.x, cueUndergroundColor.y, cueUndergroundColor.z, 255)
    isMetricUnits
  }
}

let function radarIndication(color_watched) {
  return @(){
    watch = color_watched
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = dasRadarIndication
    drawFunc = "draw_radar_indication"
    setupFunc = "setup_data"
    color = color_watched.value
    font = Fonts.hud
    fontSize = hudFontHgt
  }
}

return {
  radarHud
  radarIndication
  radarMfd
}
