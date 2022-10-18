let mfdHud = require("mfd.nut")
let heliIlsHud = require("heliIls.nut")

let {bw, bh, rw, rh, safeAreaSizeHud} = require("style/screenState.nut")
let {IsRadarHudVisible} = require("radarState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, SightMask, EmptyMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsSightHudVisible, IsGunnerHudVisible,
  HudColor, AlertColorHigh, IsMfdEnabled} = require("airState.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let {paramsTable, taTarget, compassElem, rocketAim, vertSpeed, horSpeed, turretAngles, agmLaunchZone,
  launchDistanceMax, lockSight, targetSize, sight, rangeFinder, detectAlly} = require("airHudElems.nut")
let hudLogs = require("hudLogs.nut")
let voiceChat = require("chat/voiceChat.nut")

let {
  gunDirection, fixedGunsDirection, helicopterCCRP, agmTrackerStatusComponent, bombSightComponent,
  laserDesignatorStatusComponent, laserDesignatorComponent, agmTrackZoneComponent} = require("airSight.nut")

let {radarElement, twsElement} = require("airHudComponents.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthHeli = hdpx(450)
let paramsTableHeightHeli = hdpx(28)
let paramsSightTableWidth = hdpx(270)
let arbiterParamsTableWidthHelicopter = hdpx(200)
let positionParamsTable = Computed(@() [max(bw.value, sw(50) - hdpx(660)), sh(50) - hdpx(100)])
let positionParamsSightTable = Watched([sw(50) - hdpx(250) - hdpx(200), hdpx(480)])

let radarSize = sh(28)
let radarPosWatched = Computed(@() [bw.value + 0.05 * rw.value, bh.value + 0.05 * rh.value])
let twsSize = sh(20)
let twsPosComputed = Computed(@() [bw.value + 0.965 * rw.value - twsSize, bh.value + 0.5 * rh.value])

let helicopterArbiterParamsTablePos = Computed(@() [max(bw.value, sw(17.5)), sh(12)])

let helicopterParamsTable = paramsTable(MainMask, SecondaryMask,
  paramsTableWidthHeli, paramsTableHeightHeli,
  positionParamsTable,
  hdpx(5))

let helicopterSightParamsTable = paramsTable(SightMask, EmptyMask,
  paramsSightTableWidth, paramsTableHeightHeli,
  positionParamsSightTable,
  hdpx(3))

let helicopterArbiterParamsTable = paramsTable(MainMask, SecondaryMask,
  arbiterParamsTableWidthHelicopter, paramsTableHeightHeli,
  helicopterArbiterParamsTablePos,
  hdpx(1), true, false, true)

let function helicopterMainHud(isBackground) {
  return @(){
    watch = IsMainHudVisible
    children = IsMainHudVisible.value
    ? [
      rocketAim(sh(0.8), sh(1.8), HudColor.value, isBackground)
      aamAim(HudColor, AlertColorHigh, isBackground)
      agmAim(HudColor, isBackground)
      gunDirection(HudColor, false, isBackground)
      fixedGunsDirection(HudColor, isBackground)
      helicopterCCRP(HudColor, isBackground)
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.value, isBackground)
      horSpeed(HudColor.value, isBackground)
      helicopterParamsTable(isBackground)
      taTarget(sw(25), sh(25), isBackground)
    ]
    : null
  }
}

let function helicopterSightHud(isBackground) {

  return @(){
    watch = IsSightHudVisible
    children = IsSightHudVisible.value ?
    [
      vertSpeed(sh(4.0), sh(30), sw(50) + hdpx(325), sh(35), HudColor.value, isBackground)
      turretAngles(HudColor, hdpx(150), hdpx(150), sw(50), sh(90), isBackground)
      agmLaunchZone(HudColor, sw(100), sh(100), isBackground)
      launchDistanceMax(HudColor, hdpx(150), hdpx(150), sw(50), sh(90), isBackground)
      helicopterSightParamsTable(isBackground)
      lockSight(HudColor, hdpx(150), hdpx(100), sw(50), sh(50), isBackground)
      targetSize(HudColor, sw(100), sh(100))
      agmTrackZoneComponent(HudColor, isBackground)
      agmTrackerStatusComponent(HudColor, sw(50), sh(41), isBackground)
      laserDesignatorComponent(HudColor, sw(50), sh(42), isBackground)
      laserDesignatorStatusComponent(HudColor, sw(50), sh(38), isBackground)
      sight(HudColor, sw(50), sh(50), hdpx(500), isBackground)
      rangeFinder(HudColor, sw(50), sh(59), isBackground)
      detectAlly(sw(51), sh(35), isBackground)
      agmAim(HudColor, isBackground)
      gunDirection(HudColor, true, isBackground)
    ]
    : null
  }
}

let function helicopterGunnerHud(isBackground) {
  return @(){
    watch = IsGunnerHudVisible
    children = IsGunnerHudVisible.value
    ? [
        gunDirection(HudColor, false, isBackground)
        fixedGunsDirection(HudColor, isBackground)
        helicopterCCRP(HudColor, isBackground)
        vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.value, isBackground)
        helicopterParamsTable(isBackground)
      ]
    : null
  }
}

let function pilotHud(isBackground) {
  return @(){
    watch = IsPilotHudVisible
    children = IsPilotHudVisible.value ?
    [
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(325), sh(42.5), HudColor.value, isBackground)
      helicopterParamsTable(isBackground)
    ]
    : null
  }
}

let function helicopterArbiterHud(isBackground) {
  return @(){
    watch = IsArbiterHudVisible
    children = IsArbiterHudVisible.value ?
    [
      helicopterArbiterParamsTable(isBackground)
    ]
    : null
  }
}

let function mkHelicopterIndicators(isBackground) {
  return @() {
    watch = [IsRadarHudVisible, IsMfdEnabled, HudColor]
    children = [
      helicopterMainHud(isBackground)
      helicopterSightHud(isBackground)
      helicopterGunnerHud(isBackground)
      helicopterArbiterHud(isBackground)
      pilotHud(isBackground)
      !IsMfdEnabled.value ? twsElement(HudColor, twsPosComputed, twsSize) : null
      !IsMfdEnabled.value ? radarElement(HudColor, radarPosWatched, radarSize) : null
      !IsRadarHudVisible.value ? compassElem(HudColor, compassSize, [sw(50) - 0.5*compassSize[0], sh(15)], isBackground) : null
      bombSightComponent(sh(10.0), sh(10.0), isBackground)
    ]
  }
}

let helicopterIndicators = mkHelicopterIndicators(false)
let helicopterIndicatorsBackground = mkHelicopterIndicators(true)

let indicatorsCtor = @() {
  watch = [
    IndicatorsVisible
    IsMfdEnabled
  ]
  size = flex()
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  children = (IndicatorsVisible.value || IsMfdEnabled.value)
    ? [helicopterIndicatorsBackground, helicopterIndicators]
    : null
 }

let chatCtor = @() {
  watch = safeAreaSizeHud
  size = [SIZE_TO_CONTENT, hdpx(350)]
  margin = safeAreaSizeHud.value.borders
  flow = FLOW_VERTICAL
  valign = ALIGN_BOTTOM
  halign = ALIGN_LEFT
  gap = hdpx(10)
  children = [
    voiceChat
    hudLogs
  ]
}

let helicopterRoot = {
  size = [sw(100), sh(100)]
  children = [
    chatCtor
    indicatorsCtor
  ]

  function onAttach() {
    ::gui_scene.addPanel(0, mfdHud)
    ::gui_scene.addPanel(1, heliIlsHud)
  }
  function onDetach() {
    ::gui_scene.removePanel(0)
    ::gui_scene.removePanel(1)
  }
}

return helicopterRoot
