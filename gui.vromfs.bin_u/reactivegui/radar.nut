from "%rGui/globals/ui_library.nut" import *
let { hudFontHgt } = require("%rGui/style/airHudStyle.nut")
let { MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode, IsCScopeVisible, IsBScopeVisible,
  ViewMode } = require("%rGui/radarState.nut")
let { IPoint3 } = require("dagor.math")
let { getLangId } = require("dagor.localize")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")
let { radarButtonsAir, radarButtonsHeli, isRadarButtonsVisible } = require("%rGui/radarButtons.nut")
let { unitType } = require("%rGui/hudState.nut")
let { ButtonExtendUpdatePress } = require("wt.behaviors")

let radarButtonsComps = {
  aircraft = radarButtonsAir
  helicopter = radarButtonsHeli
}

let radarOffsets = Computed(function() {
  if (radarButtonsComps?[unitType.get()] == null)
    return [0, 0]
  if (IsBScopeVisible.get() && ViewMode.get() == RadarViewMode.B_SCOPE_ROUND)
    return [hdpx(21), hdpx(-20)]
  if (IsCScopeVisible.get())
    return [hdpx(-3), hdpx(-30)]
  return [0, 0]
})


let radarCanvas = @(color_watched, ovr = {}, handle_clicks = false) function() {
  let radarScriptDas = getDasScriptByPath("%rGui/radar.das")
  let radarHandleClick = DasFunction(radarScriptDas, "handle_click")
  let radarHandleDoubleClick = DasFunction(radarScriptDas, "handle_double_click")
  let radarHandlePress = DasFunction(radarScriptDas, "handle_press")
  return {
    watch = [color_watched, radarOffsets]
    size = flex()
    pos = radarOffsets.get()
    rendObj = ROBJ_DAS_CANVAS
    script = radarScriptDas
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched?.get()
    font = Fonts.hud
    fontSize = hudFontHgt

    screenHeight = sh(100)

    handleClicks = handle_clicks
    behavior = handle_clicks ? [Behaviors.Button, ButtonExtendUpdatePress] : null
    skipDirPadNav = true
    onClick = handle_clicks ? function(evt){
      let elem = evt.target
      radarHandleClick(elem, elem.getScreenPosX(), elem.getScreenPosY(), elem.getWidth(), elem.getHeight(), evt.screenX, evt.screenY)
    } : null
    onDoubleClick = handle_clicks ? function(evt){
      let elem = evt.target
      radarHandleDoubleClick(elem, elem.getScreenPosX(), elem.getScreenPosY(), elem.getWidth(), elem.getHeight(), evt.screenX, evt.screenY)
    } : null
    onUpdatePress = handle_clicks ? function(evt){
      let elem = evt.target
      radarHandlePress(elem, elem.getScreenPosX(), elem.getScreenPosY(), elem.getWidth(), elem.getHeight(), evt.screenX, evt.screenY)
    } : null
  }.__update(ovr)
}


let radarHud = @(width, height, x, y, color_watched, ovr = {}, handle_clicks = false) @() {
  watch = [isRadarButtonsVisible, unitType]
  size = [width, height]
  pos = [x, y]
  children = [
    radarCanvas(color_watched, ovr, handle_clicks)
    isRadarButtonsVisible.get() ? radarButtonsComps?[unitType.get()] : null
  ]
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
  jas39Eradar = "%rGui/planeCockpit/mfdJas39Eradar.das"
  rafaelRadar = "%rGui/planeCockpit/mfdRafaelRadar.das"
  typhoonRadar = "%rGui/planeCockpit/mfdTyphoonRadar.das"
  su30Radar = "%rGui/planeCockpit/mfdSu30Radar.das"
  fa18cRadarATTK = "%rGui/planeCockpit/mfdfa18cRadarATTK.das"
  f106Radar = "%rGui/planeCockpit/F106Radar.das"
  mig25Radar = "%rGui/planeCockpit/mfdMig25Radar.das"
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
    textColor = IPoint3(0, 0, 0)
    radarBackgroundColor = IPoint3(0, 0, 0)
    radarScanColor = IPoint3(0, 0, 0)
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
    stretchFull = false
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
    textColor = page_blk.getIPoint3("textColor", IPoint3(0, 0, 0))
    radarBackgroundColor = page_blk.getIPoint3("radarBackgroundColor", IPoint3(0, 0, 0))
    radarScanColor = page_blk.getIPoint3("radarScanColor", IPoint3(0, 0, 0))
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
    stretchFull = page_blk.getBool("stretchFull", false)
  })
}

let radarMfd = @(pos_and_size, color_watched) function() {
  let { lineWidth, lineColor, modeColor, verAngleColor, scaleColor, hideBeam, hideLaunchZone, hideScale,
    hideHorAngle, hideVerAngle, horAngleColor, targetColor, fontId, hasAviaHorizont, targetFormType,
    backgroundColor, textColor, radarBackgroundColor, radarScanColor, beamShape, netRowCnt, netColor, hideWeaponIndication,
    cueHeights, fontSize, showScanAzimuth, scriptPath, centerRadar, cueTopHeiColor, cueLowHeiColor, cueUndergroundColor, isMetricUnits,
    radarModeNameLangId, stretchFull } = radarSettings.get()
  return {
    watch = [color_watched, MfdRadarHideBkg, MfdRadarFontScale, MfdViewMode, pos_and_size, radarSettings]
    size = [pos_and_size.get().w, pos_and_size.get().h]
    pos = [pos_and_size.get().x, pos_and_size.get().y]
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath(scriptPath)
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = color_watched.get()
    font = fontId
    fontSize = fontSize > 0 ? fontSize : (MfdRadarFontScale.get() > 0 ? MfdRadarFontScale.get() : pos_and_size.get().h / 512.0) * 30
    hideBackground = MfdRadarHideBkg.get()
    enableByMfd = true
    mode = MfdViewMode.get()
    lineWidth
    lineColor = lineColor.x < 0 ? color_watched.get() : Color(lineColor.x, lineColor.y, lineColor.z, 255)
    modeColor = modeColor.x < 0 ? color_watched.get() : Color(modeColor.x, modeColor.y, modeColor.z, 255)
    verAngleColor = verAngleColor.x < 0 ? color_watched.get() : Color(verAngleColor.x, verAngleColor.y, verAngleColor.z, 255)
    horAngleColor = horAngleColor.x < 0 ? color_watched.get() : Color(horAngleColor.x, horAngleColor.y, horAngleColor.z, 255)
    scaleColor = scaleColor.x < 0 ? color_watched.get() : Color(scaleColor.x, scaleColor.y, scaleColor.z, 255)
    targetColor = targetColor.x < 0 ? color_watched.get() : Color(targetColor.x, targetColor.y, targetColor.z, 255)
    hideBeam
    hideLaunchZone
    hideScale
    hideHorAngle
    hideVerAngle
    hasAviaHorizont
    targetFormType
    backgroundColor = Color(backgroundColor.x, backgroundColor.y, backgroundColor.z, 255)
    textColor = Color(textColor.x, textColor.y, textColor.z, 255)
    radarBackgroundColor = Color(radarBackgroundColor.x, radarBackgroundColor.y, radarBackgroundColor.z, 255)
    radarScanColor = Color(radarScanColor.x, radarScanColor.y, radarScanColor.z, 255)
    beamShape
    netRowCnt
    netColor = netColor.x < 0 ? color_watched.get() : Color(netColor.x, netColor.y, netColor.z, 255)
    hideWeaponIndication
    showScanAzimuth
    cueHeights
    centerRadar
    cueTopHeiColor = cueTopHeiColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueTopHeiColor.x, cueTopHeiColor.y, cueTopHeiColor.z, 255)
    cueLowHeiColor = cueLowHeiColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueLowHeiColor.x, cueLowHeiColor.y, cueLowHeiColor.z, 255)
    cueUndergroundColor = cueUndergroundColor.x < 0 ? Color(modeColor.x, modeColor.y, modeColor.z, 255) : Color(cueUndergroundColor.x, cueUndergroundColor.y, cueUndergroundColor.z, 255)
    isMetricUnits
    radarModeNameLangId
    stretchFull
  }
}

let function radarIndication(color_watched, handle_clicks = false) {
  return @(){
    watch = color_watched
    size = flex()
    rendObj = ROBJ_DAS_CANVAS
    script = getDasScriptByPath("%rGui/radarIndication.das")
    drawFunc = "draw_radar_indication"
    setupFunc = "setup_data"
    color = color_watched.get()
    font = Fonts.hud
    fontSize = hudFontHgt
    handleClicks = handle_clicks
  }
}

return {
  radarHud
  radarCanvas
  radarIndication
  radarMfd
  radarSettingsUpd
}
