from "%rGui/globals/ui_library.nut" import *

let planeMfd = require("planeMfd.nut")
let planeIls = require("planeIls.nut")
let planeHmd = require("planeHmd.nut")
let { bw, bh, rw, rh } = require("style/screenState.nut")
let opticAtgmSight = require("opticAtgmSight.nut")
let laserAtgmSight = require("laserAtgmSight.nut")
let targetingPodSight = require("targetingPodSight.nut")
let leftPanel = require("airHudLeftPanel.nut")
let { OpticAtgmSightVisible, AtgmTrackerVisible, IsWeaponHudVisible, LaserAtgmSightVisible, TargetingPodSightVisible } = require("planeState/planeWeaponState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsGunnerHudVisible,
  HudColor, AlertColorHigh, IsBomberViewHudVisible, HudParamColor,
  isBombSightActivated, isAAMSightActivated, isRocketSightActivated,
  isCanonSightActivated, isTurretSightActivated, isParamTableActivated, IsRangefinderEnabled } = require("airState.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let gbuAim = require("gbuAim.nut")
let { paramsTable, compassElem, lockSight, rangeFinder, agmLaunchZoneTps }  = require("airHudElems.nut")
let {
  aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight,
  laserPointComponent, bombSightComponent, laserDesignatorStatusComponent } = require("airSight.nut")
let { radarElement, twsElement } = require("airHudComponents.nut")
let { IsMlwsLwsHudVisible } = require("twsState.nut")
let { crosshairColorOpt } = require("options/options.nut")
let { maxLabelWidth, maxLabelHeight } = require("radarComponent.nut")
let actionBarTopPanel = require("hud/actionBarTopPanel.nut")
let { PNL_ID_ILS, PNL_ID_MFD } = require("%rGui/globals/panelIds.nut")
let { radarHud, radarIndication } = require("%rGui/radar.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let compassSize = [hdpx(420), hdpx(40)]
let { isPlayingReplay } = require("hudState.nut")
let { isCollapsedRadarInReplay } = require("%rGui/radarState.nut")

let paramsTableWidthAircraft = hdpx(600)
let arbiterParamsTableWidthAircraft = hdpx(200)
let paramsTableHeightAircraft = hdpx(22)

let aircraftParamsTablePos = Computed(@() [max(bw.value, sw(20) - hdpx(660)), max(bh.value, sh(10) - hdpx(100))])

let aircraftArbiterParamsTablePos = Computed(@() [max(bw.value, sw(17.5)), sh(12)])

let radarSize = sh(28)
let radarPosWatched = Computed(@()
  isPlayingReplay.value ?
  [
    bw.value + rw.value - fsh(30) - sh(33),
    bh.value + rh.value - sh(33)
  ] :
  [
    bw.value + rw.value - radarSize - 2 * maxLabelWidth,
    bh.value + 0.45 * rh.value - maxLabelHeight
  ]
)

let twsSize = sh(20)
let twsPosWatched = Computed(@()
  isPlayingReplay.value ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(32) + 6 + bw.value,
    bh.value + rh.value - twsSize * 1.5
  ] :
  (IsMlwsLwsHudVisible.value ?
  [
    bw.value + 0.02 * rw.value,
    bh.value + 0.43 * rh.value
  ] :
  [
    bw.value + 0.01 * rw.value,
    bh.value + 0.38 * rh.value
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


function mkAircraftMainHud() {
  let watch = [IsMainHudVisible, IsBomberViewHudVisible, isRocketSightActivated, isAAMSightActivated,
    isTurretSightActivated, isCanonSightActivated, isParamTableActivated, isBombSightActivated]

  return function() {
    let children = IsMainHudVisible.value
    ? [
        isRocketSightActivated.value ? aircraftRocketSight(sh(10.0), sh(10.0)) : null
        isAAMSightActivated.value ? aamAim(crosshairColorOpt, AlertColorHigh) : null
        agmAim(crosshairColorOpt, AlertColorHigh)
        gbuAim(crosshairColorOpt, AlertColorHigh)
        isTurretSightActivated.value ? aircraftTurretsComponent(crosshairColorOpt) : null
        isCanonSightActivated.value ? fixedGunsDirection(crosshairColorOpt) : null
        isParamTableActivated.value ? aircraftParamsTable(HudParamColor) : null
        isBombSightActivated.value ? bombSightComponent(sh(10.0), sh(10.0), crosshairColorOpt) : null
        agmLaunchZoneTps(HudColor)
      ]
        : IsBomberViewHudVisible.value
    ? [
        aircraftParamsTable(HudParamColor)
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
  children = TargetingPodSightVisible.value ?
    [
      targetingPodSight(sw(100), sh(100))
      laserDesignatorStatusComponent(HudColor, sw(50), sh(38))
      IsRangefinderEnabled.value ? rangeFinder(HudColor, sw(50), sh(59)) : null
      lockSight(crosshairColorOpt, hdpx(150), hdpx(100), sw(50), sh(50))
    ]
    : null
}


function aircraftGunnerHud() {
  return {
    watch = [IsGunnerHudVisible, isParamTableActivated, isTurretSightActivated]
    children = IsGunnerHudVisible.value
      ? [
        isTurretSightActivated.value ? aircraftTurretsComponent(crosshairColorOpt) : null
        isParamTableActivated.value ? aircraftParamsTable(HudParamColor) : null
      ]
      : null
  }
}

function aircraftPilotHud() {
  return {
    watch = [IsPilotHudVisible, isParamTableActivated, OpticAtgmSightVisible, LaserAtgmSightVisible]
    children = (IsPilotHudVisible.value || OpticAtgmSightVisible.value || LaserAtgmSightVisible.value) && isParamTableActivated.value
      ? aircraftParamsTable(HudParamColor)
      : null
  }
}


let weaponHud = @() {
  watch = [ IsWeaponHudVisible, IndicatorsVisible ]
  children = IsWeaponHudVisible.value && IndicatorsVisible.value
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
    children = IsArbiterHudVisible.value && isParamTableActivated.value
      ? aircraftArbiterParamsTable(HudParamColor)
      : null
  }
}

function mkAgmAimIndicator(watchedColor, watchedAlertColor) {
  return function() {
    return {
      watch = AtgmTrackerVisible
      size = flex()
      children = AtgmTrackerVisible.value ? [
        agmAim(watchedColor, watchedAlertColor, false)
        gbuAim(watchedColor, watchedAlertColor, false)
      ] : null
    }
  }
}

return {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = [sw(100), sh(100)]
  children = @() {
    watch = [OpticAtgmSightVisible, LaserAtgmSightVisible, isCollapsedRadarInReplay]
    size = flex()
    children = [
      mkAircraftMainHud()
      aircraftGunnerHud
      aircraftPilotHud
      aircraftArbiterHud
      leftPanel
      actionBarTopPanel
      twsElement(HudColor, twsPosWatched, twsSize)
      radarElement(HudColor, radarPosWatched.value)
      OpticAtgmSightVisible.value ? opticAtgmSight(sw(100), sh(100)) : null
      mkAgmAimIndicator(crosshairColorOpt, AlertColorHigh)
      weaponHud
      laserPointComponent(HudColor)
      LaserAtgmSightVisible.value ? laserAtgmSight(sw(100), sh(100)) : null
      aircraftSightHud
      !LaserAtgmSightVisible.value ? compassElem(HudColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)]) : null
      planeHmd
      !isCollapsedRadarInReplay.value ? radarHud(sh(33), sh(33), radarPosWatched.value[0], radarPosWatched.value[1], HudColor) : null
      radarIndication(HudColor)
      sensorViewIndicators
    ]
  }

  function onAttach() {
    gui_scene.addPanel(PNL_ID_MFD, planeMfd)
    gui_scene.addPanel(PNL_ID_ILS, planeIls)
  }
  function onDetach() {
    gui_scene.removePanel(PNL_ID_MFD)
    gui_scene.removePanel(PNL_ID_ILS)
  }
}
