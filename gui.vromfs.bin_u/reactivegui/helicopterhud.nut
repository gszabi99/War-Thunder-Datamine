from "%rGui/globals/ui_library.nut" import *

let mfdHud = require("mfd.nut")
let planeIls = require("planeIls.nut")
let { bw, bh, rw, rh } = require("style/screenState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, SightMask, EmptyMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsSightHudVisible, IsGunnerHudVisible,
  HudColor, MfdColor, AlertColorHigh, IsMfdEnabled, HudParamColor } = require("airState.nut")
let { IsRadarVisible, IsRadar2Visible} = require("radarState.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let { paramsTable, taTarget, compassElem, rocketAim, vertSpeed, horSpeed, turretAngles, agmLaunchZone,
  launchDistanceMax, lockSight, targetSize, sight, rangeFinder, detectAlly } = require("airHudElems.nut")
let {
  gunDirection, fixedGunsDirection, helicopterCCRP, agmTrackerStatusComponent, bombSightComponent,
  laserDesignatorStatusComponent, laserDesignatorComponent, agmTrackZoneComponent } = require("airSight.nut")
let { radarElement, twsElement } = require("airHudComponents.nut")
let leftPanel = require("airHudLeftPanel.nut")
let missileSalvoTimer = require("missileSalvoTimer.nut")
let { actionBarTopPanel } = require("hud/actionBarTopPanel.nut")
let { PNL_ID_ILS, PNL_ID_MFD } = require("%rGui/globals/panelIds.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let { isHeliPilotHudDisabled } = require("options/options.nut")
let planeHmd = require("planeHmd.nut")
let { isPlayingReplay } = require("hudState.nut")
let { IsMlwsLwsHudVisible, IsTwsDamaged } = require("twsState.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let { isCollapsedRadarInReplay, IsRadarDamaged } = require("%rGui/radarState.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthHeli = hdpx(450)
let paramsTableHeightHeli = hdpx(28)
let paramsSightTableWidth = hdpx(270)
let arbiterParamsTableWidthHelicopter = hdpx(200)
let positionParamsTable = Computed(@() [max(bw.value, sw(50) - hdpx(660)), sh(50) - hdpx(80)])
let positionParamsSightTable = Watched([sw(50) - hdpx(250) - hdpx(200), hdpx(480)])

let radarPosWatched = Computed(@() isPlayingReplay.value ?
  [
    bw.value + rw.value - fsh(30) - sh(33),
    bh.value + rh.value - sh(33)
  ] :
  [bw.value, bh.value])
let twsSize = sh(20)
let twsPosComputed = Computed(@() isPlayingReplay.value ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(16) + 6 + bw.value + (IsMlwsLwsHudVisible.value ? 0.3 * twsSize : 0),
    bh.value + rh.value - twsSize * (IsMlwsLwsHudVisible.value ? 1.3 : 1.0)
  ] :
  [
    bw.value + 0.965 * rw.value - twsSize,
    bh.value + 0.5 * rh.value
  ])

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

function helicopterMainHud() {
  return @() {
    watch = IsMainHudVisible
    children = IsMainHudVisible.value
    ? [
      rocketAim(sh(0.8), sh(1.8), HudColor.value)
      aamAim(HudColor, AlertColorHigh)
      agmAim(HudColor, AlertColorHigh)
      gunDirection(HudColor, false)
      fixedGunsDirection(HudColor)
      helicopterCCRP(HudColor)
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.value)
      horSpeed(HudColor.value)
      helicopterParamsTable(HudColor)
      taTarget(sw(25), sh(25), false)
    ]
    : null
  }
}

function helicopterSightHud() {
  return @() {
    watch = IsSightHudVisible
    children = IsSightHudVisible.value ?
    [
      vertSpeed(sh(4.0), sh(30), sw(50) + hdpx(325), sh(35), HudParamColor.value)
      missileSalvoTimer(HudParamColor, sw(50) - hdpx(150), sh(90) - hdpx(174))
      turretAngles(HudParamColor, hdpx(150), hdpx(150), sw(50), sh(90))
      agmLaunchZone(HudParamColor, sw(100), sh(100))
      launchDistanceMax(HudParamColor, hdpx(150), hdpx(150), sw(50), sh(90))
      helicopterSightParamsTable(HudParamColor)
      lockSight(HudParamColor, hdpx(150), hdpx(100), sw(50), sh(50))
      targetSize(HudParamColor, sw(100), sh(100))
      agmTrackZoneComponent(HudParamColor)
      agmTrackerStatusComponent(HudParamColor, sw(50), sh(41))
      laserDesignatorComponent(HudParamColor, sw(50), sh(42))
      laserDesignatorStatusComponent(HudParamColor, sw(50), sh(38))
      sight(HudParamColor, sw(50), sh(50), hdpx(500))
      rangeFinder(HudParamColor, sw(50), sh(59))
      detectAlly(sw(51), sh(35))
      agmAim(HudParamColor, AlertColorHigh)
      gunDirection(HudParamColor, true)
    ]
    : null
  }
}

function helicopterGunnerHud() {
  return @() {
    watch = IsGunnerHudVisible
    children = IsGunnerHudVisible.value
    ? [
        gunDirection(HudColor, false)
        fixedGunsDirection(HudColor)
        helicopterCCRP(HudColor)
        vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.value)
        helicopterParamsTable(HudColor)
      ]
    : null
  }
}

let pilotHud = @() {
  watch = [IsPilotHudVisible, isHeliPilotHudDisabled]
  children = IsPilotHudVisible.value && !isHeliPilotHudDisabled.value
    ? helicopterParamsTable(HudColor)
    : null
}

function helicopterArbiterHud() {
  return @() {
    watch = IsArbiterHudVisible
    children = IsArbiterHudVisible.value ?
    [
      helicopterArbiterParamsTable(HudColor)
    ]
    : null
  }
}

function mkHelicopterIndicators() {
  return @() {
    watch = [IsMfdEnabled, HudColor, IsRadarVisible, IsRadar2Visible, isCollapsedRadarInReplay, IsRadarDamaged, IsTwsDamaged]
    children = [
      helicopterMainHud()
      helicopterSightHud()
      helicopterGunnerHud()
      helicopterArbiterHud()
      pilotHud
      !IsMfdEnabled.value ? twsElement(IsTwsDamaged.value ? AlertColorHigh : MfdColor, twsPosComputed, twsSize) : null
      !IsMfdEnabled.value ? radarElement(IsRadarDamaged.value ? AlertColorHigh : MfdColor, radarPosWatched.value) : null
      compassElem(MfdColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)])
      bombSightComponent(sh(10.0), sh(10.0), HudColor)
      !isCollapsedRadarInReplay.value && (IsRadarVisible.value || IsRadar2Visible.value) ? radarHud(sh(33), sh(33), radarPosWatched.value[0], radarPosWatched.value[1], HudColor) : null
      IsRadarVisible.value || IsRadar2Visible.value ? radarIndication(HudColor) : null
      sensorViewIndicators
    ]
  }
}

let helicopterIndicators = mkHelicopterIndicators()

let indicatorsCtor = @() {
  watch = [
    IndicatorsVisible
    IsMfdEnabled
  ]
  size = flex()
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  children = (IndicatorsVisible.value || IsMfdEnabled.value)
    ? helicopterIndicators
    : null
}

let helicopterRoot = {
  size = [sw(100), sh(100)]
  children = [
    leftPanel
    actionBarTopPanel
    indicatorsCtor
    planeHmd
  ]

  function onAttach() {
    gui_scene.addPanel(PNL_ID_MFD, mfdHud)
    gui_scene.addPanel(PNL_ID_ILS, planeIls)
  }
  function onDetach() {
    gui_scene.removePanel(PNL_ID_MFD)
    gui_scene.removePanel(PNL_ID_ILS)
  }
}

return helicopterRoot
