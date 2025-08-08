from "%rGui/globals/ui_library.nut" import *
let { hudFontHgt } = require("style/airHudStyle.nut")
let { MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode } = require("radarState.nut")
let { IPoint3 } = require("dagor.math")
let { getLangId } = require("dagor.localize")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")

function radarHud(width, height, x, y, color_watched, has_txt_block = false) {
  return @(){
    watch = color_watched
    size = [width, height]
    pos = [x, y]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/radar.das")
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
  su27tactic = "%rGui/planeCockpit/su27tactic.das"
  jas39radar = "%rGui/planeCockpit/mfdJas39radar.das"
  rafaelRadar = "%rGui/planeCockpit/mfdRafaelRadar.das"
  typhoonRadar = "%rGui/planeCockpit/mfdTyphoonRadar.das"
  su30Radar = "%rGui/planeCockpit/mfdSu30Radar.das"
  fa18cRadarATTK = "%rGui/planeCockpit/mfdfa18cRadarATTK.das"
  f106Radar = "%rGui/planeCockpit/F106Radar.das"
}

let radarSettings = Watched({
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
    fontSize = -1
    targetFormType = 0
    backgroundColor = IPoint3(0, 0, 0)
    beamShape = 0
    netRowCnt = 0
    netColor = IPoint3(0, 255, 0)
    hideWeaponIndication = false
    showScanAzimuth = false
    cueHeights = false
    scriptPath = "%rGui/radar.das"
    centerRadar = false
    cueTopHeiColor = IPoint3(0, 255, 0)
    cueLowHeiColor = IPoint3(0, 255, 0)
    cueUndergroundColor = IPoint3(0, 255, 0)
    isMetricUnits = false
    radarModeNameLangId = -1
  })

function radarSettingsUpd(page_blk) {
  let targetType = page_blk.getStr("targetForm", "")
  let beamType = page_blk.getStr("beamShape", "beam")
  let scriptType = page_blk.getStr("customRadar", "")
  radarSettings.set({
    lineWidth = page_blk.getReal("lineWidth", 1.0)
    lineColor = page_blk.getIPoint3("lineColor", IPoint3(-1, -1, -1))
    modeColor = page_blk.getIPoint3("modeColor", IPoint3(-1, -1, -1))
    verAngleColor = page_blk.getIPoint3("verAngleColor", IPoint3(-1, -1, -1))
    horAngleColor = page_blk.getIPoint3("horAngleColor", IPoint3(-1, -1, -1))
    scaleColor = page_blk.getIPoint3("scaleColor", IPoint3(-1, -1, -1))
    targetColor = page_blk.getIPoint3("targetColor", IPoint3(-1, -1, -1))
    hideVerAngle = page_blk.getBool("hideVerAngle", false)
    hideHorAngle = page_blk.getBool("hideHorAngle", false)
    hideLaunchZone = page_blk.getBool("hideLaunchZone", false)
    hideScale = page_blk.getBool("hideScale", false)
    hideBeam = page_blk.getBool("hideBeam", false)
    hasAviaHorizont = page_blk.getBool("hasAviaHorizont", false)
    fontId = Fonts?[page_blk.getStr("font", "hud")] ?? Fonts.hud
    fontSize = page_blk.getInt("fontSize", -1)
    targetFormType = targetFormTypes?[targetType] ?? 0
    backgroundColor = page_blk.getIPoint3("backgroundColor", IPoint3(0, 0, 0))
    beamShape = beamShapes?[beamType] ?? 0
    netRowCnt = page_blk.getInt("netRowCnt", 0)
    netColor = page_blk.getIPoint3("netColor", IPoint3(-1, -1, -1))
    hideWeaponIndication = page_blk.getBool("hideWeaponIndication", false)
    showScanAzimuth = page_blk.getBool("showScanAzimuth", false)
    cueHeights = page_blk.getBool("showCueHeights", false)
    scriptPath = customPages?[scriptType] ?? "%rGui/radar.das"
    centerRadar = page_blk.getBool("centerRadar", false)
    cueTopHeiColor = page_blk.getIPoint3("cueTopHeiColor", IPoint3(-1, -1, -1))
    cueLowHeiColor = page_blk.getIPoint3("cueLowHeiColor", IPoint3(-1, -1, -1))
    cueUndergroundColor = page_blk.getIPoint3("cueUndergroundColor", IPoint3(-1, -1, -1))
    isMetricUnits = page_blk.getBool("isMetricUnits", false)
    radarModeNameLangId = getLangId(page_blk.getStr("radarModeNameLangId", ""))
  })
}

let radarMfd = @(pos_and_size, color_watched) function() {
  let { lineWidth, lineColor, modeColor, verAngleColor, scaleColor, hideBeam, hideLaunchZone, hideScale,
   hideHorAngle, hideVerAngle, horAngleColor, targetColor, fontId, hasAviaHorizont, targetFormType,
   backgroundColor, beamShape, netRowCnt, netColor, hideWeaponIndication, cueHeights, fontSize,
   showScanAzimuth, scriptPath, centerRadar, cueTopHeiColor, cueLowHeiColor, cueUndergroundColor, isMetricUnits,
   radarModeNameLangId } = radarSettings.get()
  return {
    watch = [color_watched, MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode, pos_and_size, radarSettings]
    size = [pos_and_size.value.w, pos_and_size.value.h]
    pos = [pos_and_size.value.x, pos_and_size.value.y]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath(scriptPath)
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.value
    font = fontId
    fontSize = fontSize > 0 ? fontSize : (MfdRadarFontScale.value > 0 ? MfdRadarFontScale.value : pos_and_size.value.h / 512.0) * 30
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
    radarModeNameLangId
  }
}

let function radarIndication(color_watched) {
  return @(){
    watch = color_watched
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/radarIndication.das")
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
  radarSettingsUpd
}
