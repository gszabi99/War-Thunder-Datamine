from "%rGui/globals/ui_library.nut" import *

let planeMfd = require("%rGui/planeMfd.nut")
let { planeIlsSwitcher } = require("%rGui/planeIls.nut")
let { planeHmdElem } = require("%rGui/planeHmd.nut")
let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let opticAtgmSight = require("%rGui/opticAtgmSight.nut")
let laserAtgmSight = require("%rGui/laserAtgmSight.nut")
let targetingPodSight = require("%rGui/targetingPodSight.nut")
let leftPanel = require("%rGui/airHudLeftPanel.nut")
let { OpticAtgmSightVisible, AtgmTrackerVisible, IsWeaponHudVisible, LaserAtgmSightVisible, TargetingPodSightVisible } = require("%rGui/planeState/planeWeaponState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsGunnerHudVisible,
  HudColor, AlertColorHigh, IsBomberViewHudVisible, HudParamColor,
  isBombSightActivated, isAAMSightActivated, isRocketSightActivated,
  isCanonSightActivated, isTurretSightActivated, isParamTableActivated, IsRangefinderEnabled } = require("%rGui/airState.nut")
let aamAim = require("%rGui/rocketAamAim.nut")
let agmAim = require("%rGui/agmAim.nut")
let gbuAim = require("%rGui/gbuAim.nut")
let { paramsTable, compassElem, lockSight, rangeFinder, agmLaunchZoneTps }  = require("%rGui/airHudElems.nut")
let {
  aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight,
  laserPointComponent, bombSightComponent, laserDesignatorStatusComponent } = require("%rGui/airSight.nut")
let { radarElement, twsElement } = require("%rGui/airHudComponents.nut")
let { IsMlwsLwsHudVisible, IsTwsDamaged } = require("%rGui/twsState.nut")
let { crosshairColorOpt } = require("%rGui/options/options.nut")
let { maxLabelWidth, maxLabelHeight } = require("%rGui/radarComponent.nut")
let { actionBarTopPanel } = require("%rGui/hud/actionBarTopPanel.nut")
let { PNL_ID_ILS, PNL_ID_MFD } = require("%rGui/globals/panelIds.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let compassSize = [hdpx(420), hdpx(40)]
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { isCollapsedRadarInReplay, IsRadarDamaged } = require("%rGui/radarState.nut")

let paramsTableWidthAircraft = hdpx(600)
let arbiterParamsTableWidthAircraft = hdpx(200)
let paramsTableHeightAircraft = hdpx(22)

let aircraftParamsTablePos = Computed(@() [max(bw.get(), sw(20) - hdpx(660)), max(bh.get(), sh(10) - hdpx(100))])

let aircraftArbiterParamsTablePos = Computed(@() [max(bw.get(), sw(17.5)), sh(12)])

let radarSize = sh(28)
let radarPosWatched = Computed(@()
  isPlayingReplay.get() ?
  [
    bw.get() + rw.get() - fsh(30) - sh(33),
    bh.get() + rh.get() - sh(33)
  ] :
  [
    bw.get() + rw.get() - radarSize - 2 * maxLabelWidth,
    bh.get() + 0.45 * rh.get() - maxLabelHeight
  ]
)

let twsSize = sh(20)
let twsPosWatched = Computed(@()
  isPlayingReplay.get() ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(32) + 6 + bw.get(),
    bh.get() + rh.get() - twsSize * 1.5
  ] :
  (IsMlwsLwsHudVisible.get() ?
  [
    bw.get() + 0.02 * rw.get(),
    bh.get() + 0.43 * rh.get()
  ] :
  [
    bw.get() + 0.01 * rw.get(),
    bh.get() + 0.38 * rh.get()
  ])
)

let aircraftParamsTable = paramsTable(MainMask, SecondaryMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

let aircraftArbiterParamsTable = paramsTable(MainMask, SecondaryMask,
        arbiterParamsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftArbiterParamsTablePos,
        hdpx(1), true, false, true)

let aircraftParamsTableView = @(color, isReplayVal)
  (isReplayVal ? aircraftArbiterParamsTable : aircraftParamsTable)(color)

function mkAircraftMainHud() {
  let watch = [IsMainHudVisible, IsBomberViewHudVisible, isRocketSightActivated, isAAMSightActivated,
    isTurretSightActivated, isCanonSightActivated, isParamTableActivated, isBombSightActivated, isPlayingReplay]

  return function() {
    let children = IsMainHudVisible.get()
    ? [
        isRocketSightActivated.get() ? aircraftRocketSight(sh(10.0), sh(10.0)) : null
        isAAMSightActivated.get() ? aamAim(crosshairColorOpt, AlertColorHigh) : null
        agmAim(crosshairColorOpt, AlertColorHigh)
        gbuAim(crosshairColorOpt, AlertColorHigh)
        isTurretSightActivated.get() ? aircraftTurretsComponent(crosshairColorOpt) : null
        isCanonSightActivated.get() ? fixedGunsDirection(crosshairColorOpt) : null
        isParamTableActivated.get() ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get()) : null
        isBombSightActivated.get() ? bombSightComponent(sh(10.0), sh(10.0), crosshairColorOpt) : null
        agmLaunchZoneTps(HudColor)
      ]
        : IsBomberViewHudVisible.get()
    ? [
        aircraftParamsTableView(HudParamColor, isPlayingReplay.get())
      ]
    : null

    return {
      watch
      children
    }
  }
}

let aircraftSightHud = @() {
  watch = [TargetingPodSightVisible, IsRangefinderEnabled]
  children = TargetingPodSightVisible.get() ?
    [
      targetingPodSight(sw(100), sh(100))
      laserDesignatorStatusComponent(HudColor, sw(50), sh(38))
      IsRangefinderEnabled.get() ? rangeFinder(HudColor, sw(50), sh(59)) : null
      lockSight(crosshairColorOpt, hdpx(150), hdpx(100), sw(50), sh(50))
    ]
    : null
}


function aircraftGunnerHud() {
  return {
    watch = [IsGunnerHudVisible, isParamTableActivated, isTurretSightActivated, isPlayingReplay]
    children = IsGunnerHudVisible.get()
      ? [
        isTurretSightActivated.get() ? aircraftTurretsComponent(crosshairColorOpt) : null
        isParamTableActivated.get() ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get()) : null
      ]
      : null
  }
}

function aircraftPilotHud() {
  return {
    watch = [IsPilotHudVisible, isParamTableActivated, OpticAtgmSightVisible, LaserAtgmSightVisible, isPlayingReplay]
    children = (IsPilotHudVisible.get() || OpticAtgmSightVisible.get() || LaserAtgmSightVisible.get()) && isParamTableActivated.get()
      ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get())
      : null
  }
}


let weaponHud = @() {
  watch = [ IsWeaponHudVisible, IndicatorsVisible ]
  children = IsWeaponHudVisible.get() && IndicatorsVisible.get()
    ? [
      aamAim(crosshairColorOpt, AlertColorHigh)
      agmAim(crosshairColorOpt, AlertColorHigh)
      gbuAim(crosshairColorOpt, AlertColorHigh)
    ]
    : null
}

function aircraftArbiterHud() {
  return {
    watch = [IsArbiterHudVisible, isParamTableActivated]
    children = IsArbiterHudVisible.get() && isParamTableActivated.get()
      ? aircraftArbiterParamsTable(HudParamColor)
      : null
  }
}

function mkAgmAimIndicator(watchedColor, watchedAlertColor) {
  return function() {
    return {
      watch = AtgmTrackerVisible
      size = flex()
      children = AtgmTrackerVisible.get() ? [
        agmAim(watchedColor, watchedAlertColor, false)
        gbuAim(watchedColor, watchedAlertColor, false)
      ] : null
    }
  }
}

return {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = static [sw(100), sh(100)]
  children = @() {
    watch = [OpticAtgmSightVisible, LaserAtgmSightVisible, isCollapsedRadarInReplay, IsRadarDamaged, IsTwsDamaged]
    size = flex()
    children = [
      mkAircraftMainHud()
      aircraftGunnerHud
      aircraftPilotHud
      aircraftArbiterHud
      leftPanel
      actionBarTopPanel
      twsElement(IsTwsDamaged.get() ? AlertColorHigh : HudColor, twsPosWatched, twsSize)
      radarElement(IsRadarDamaged.get() ? AlertColorHigh : HudColor, radarPosWatched.get())
      OpticAtgmSightVisible.get() ? opticAtgmSight(sw(100), sh(100)) : null
      mkAgmAimIndicator(crosshairColorOpt, AlertColorHigh)
      weaponHud
      laserPointComponent(HudColor)
      LaserAtgmSightVisible.get() ? laserAtgmSight(sw(100), sh(100)) : null
      aircraftSightHud
      !LaserAtgmSightVisible.get() ? compassElem(HudColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)]) : null
      planeHmdElem
      !isCollapsedRadarInReplay.get() ? radarHud(sh(33), sh(33), radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {}, true) : null
      radarIndication(HudColor)
      sensorViewIndicators
    ]
  }

  function onAttach() {
    gui_scene.addPanel(PNL_ID_MFD, planeMfd)
    gui_scene.addPanel(PNL_ID_ILS, planeIlsSwitcher)
  }
  function onDetach() {
    gui_scene.removePanel(PNL_ID_MFD)
    gui_scene.removePanel(PNL_ID_ILS)
  }
}
