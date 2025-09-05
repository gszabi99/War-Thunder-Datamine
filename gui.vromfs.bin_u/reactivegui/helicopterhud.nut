from "%rGui/globals/ui_library.nut" import *

let mfdHud = require("%rGui/mfd.nut")
let { planeIlsSwitcher } = require("%rGui/planeIls.nut")
let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, SightMask, EmptyMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsSightHudVisible, IsGunnerHudVisible,
  HudColor, MfdColor, AlertColorHigh, IsMfdEnabled, HudParamColor } = require("%rGui/airState.nut")
let { isCollapsedRadarInReplay, IsRadarDamaged, IsRadarVisible, IsRadar2Visible} = require("%rGui/radarState.nut")
let aamAim = require("%rGui/rocketAamAim.nut")
let agmAim = require("%rGui/agmAim.nut")
let { paramsTable, taTarget, compassElem, rocketAim, vertSpeed, horSpeed, turretAngles, agmLaunchZone,
  launchDistanceMax, lockSight, targetSize, sight, rangeFinder, detectAlly } = require("%rGui/airHudElems.nut")
let {
  gunDirection, fixedGunsDirection, helicopterCCRP, agmTrackerStatusComponent, bombSightComponent,
  laserDesignatorStatusComponent, laserDesignatorComponent, agmTrackZoneComponent } = require("%rGui/airSight.nut")
let { radarElement, twsElement } = require("%rGui/airHudComponents.nut")
let leftPanel = require("%rGui/airHudLeftPanel.nut")
let missileSalvoTimer = require("%rGui/missileSalvoTimer.nut")
let { actionBarTopPanel } = require("%rGui/hud/actionBarTopPanel.nut")
let { PNL_ID_ILS, PNL_ID_MFD } = require("%rGui/globals/panelIds.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let { isHeliPilotHudDisabled } = require("%rGui/options/options.nut")
let { planeHmdElem }  = require("%rGui/planeHmd.nut")
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { IsMlwsLwsHudVisible, IsTwsDamaged } = require("%rGui/twsState.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthHeli = hdpx(450)
let paramsTableHeightHeli = hdpx(28)
let paramsSightTableWidth = hdpx(270)
let arbiterParamsTableWidthHelicopter = hdpx(200)
let positionParamsTable = Computed(@() [max(bw.get(), sw(50) - hdpx(660)), sh(50) - hdpx(80)])
let positionParamsSightTable = Watched([sw(50) - hdpx(250) - hdpx(200), hdpx(480)])

let radarPosWatched = Computed(@() isPlayingReplay.get() ?
  [
    bw.get() + rw.get() - fsh(30) - sh(33),
    bh.get() + rh.get() - sh(33)
  ] :
  [bw.get() + hdpx(75), bh.get()])
let twsSize = sh(20)
let twsPosComputed = Computed(@() isPlayingReplay.get() ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(16) + 6 + bw.get() + (IsMlwsLwsHudVisible.get() ? 0.3 * twsSize : 0),
    bh.get() + rh.get() - twsSize * (IsMlwsLwsHudVisible.get() ? 1.3 : 1.0)
  ] :
  [
    bw.get() + 0.965 * rw.get() - twsSize,
    bh.get() + 0.5 * rh.get()
  ])

let helicopterArbiterParamsTablePos = Computed(@() [max(bw.get(), sw(17.5)), sh(12)])

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

let helicopterParamsTableView = @(color, isReplayVal)
  (isReplayVal ? helicopterArbiterParamsTable : helicopterParamsTable)(color)

function helicopterMainHud() {
  return @() {
    watch = [IsMainHudVisible, isPlayingReplay]
    children = IsMainHudVisible.get()
    ? [
      rocketAim(sh(0.8), sh(1.8), HudColor.get())
      aamAim(HudColor, AlertColorHigh)
      agmAim(HudColor, AlertColorHigh)
      gunDirection(HudColor, false)
      fixedGunsDirection(HudColor)
      helicopterCCRP(HudColor)
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.get())
      horSpeed(HudColor.get())
      helicopterParamsTableView(HudColor, isPlayingReplay.get())
      taTarget(sw(25), sh(25), false)
    ]
    : null
  }
}

function helicopterSightHud() {
  return @() {
    watch = IsSightHudVisible
    children = IsSightHudVisible.get() ?
    [
      vertSpeed(sh(4.0), sh(30), sw(50) + hdpx(325), sh(35), HudParamColor.get())
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
    watch = [IsGunnerHudVisible, isPlayingReplay]
    children = IsGunnerHudVisible.get()
    ? [
        gunDirection(HudColor, false)
        fixedGunsDirection(HudColor)
        helicopterCCRP(HudColor)
        vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.get())
        helicopterParamsTableView(HudColor, isPlayingReplay.get())
      ]
    : null
  }
}

let pilotHud = @() {
  watch = [IsPilotHudVisible, isHeliPilotHudDisabled, isPlayingReplay]
  children = IsPilotHudVisible.get() && !isHeliPilotHudDisabled.get()
    ? helicopterParamsTableView(HudColor, isPlayingReplay.get())
    : null
}

function helicopterArbiterHud() {
  return @() {
    watch = IsArbiterHudVisible
    children = IsArbiterHudVisible.get() ?
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
      !IsMfdEnabled.get() ? twsElement(IsTwsDamaged.get() ? AlertColorHigh : MfdColor, twsPosComputed, twsSize) : null
      !IsMfdEnabled.get() ? radarElement(IsRadarDamaged.get() ? AlertColorHigh : MfdColor, radarPosWatched.get()) : null
      compassElem(MfdColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)])
      bombSightComponent(sh(10.0), sh(10.0), HudColor)
      !isCollapsedRadarInReplay.get()
        ? radarHud(sh(33), sh(33), radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {}, true) : null
      IsRadarVisible.get() || IsRadar2Visible.get() ? radarIndication(HudColor) : null
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
  children = (IndicatorsVisible.get() || IsMfdEnabled.get())
    ? helicopterIndicators
    : null
}

let helicopterRoot = {
  size = static [sw(100), sh(100)]
  children = [
    leftPanel
    actionBarTopPanel
    indicatorsCtor
    planeHmdElem
  ]

  function onAttach() {
    gui_scene.addPanel(PNL_ID_MFD, mfdHud)
    gui_scene.addPanel(PNL_ID_ILS, planeIlsSwitcher)
  }
  function onDetach() {
    gui_scene.removePanel(PNL_ID_MFD)
    gui_scene.removePanel(PNL_ID_ILS)
  }
}

return helicopterRoot
