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
let { paramsTable, compassElem, lockSight, rangeFinder }  = require("airHudElems.nut")
let {
  aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight,
  laserPointComponent, bombSightComponent, laserDesignatorStatusComponent } = require("airSight.nut")
let { radarElement, twsElement } = require("airHudComponents.nut")
let { crosshairColorOpt } = require("options/options.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthAircraft = hdpx(600)
let arbiterParamsTableWidthAircraft = hdpx(200)
let paramsTableHeightAircraft = hdpx(22)

let aircraftParamsTablePos = Computed(@() [max(bw.value, sw(20) - hdpx(660)), max(bh.value, sh(10) - hdpx(100))])

let aircraftArbiterParamsTablePos = Computed(@() [max(bw.value, sw(17.5)), sh(12)])

let aircraftParamsTable = paramsTable(MainMask, SecondaryMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

let aircraftArbiterParamsTable = paramsTable(MainMask, SecondaryMask,
        arbiterParamsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftArbiterParamsTablePos,
        hdpx(1), true, false, true)


let function mkAircraftMainHud() {
  let watch = [IsMainHudVisible, IsBomberViewHudVisible, isRocketSightActivated, isAAMSightActivated,
    isTurretSightActivated, isCanonSightActivated, isParamTableActivated, isBombSightActivated]

  return function() {
    let children = IsMainHudVisible.value
    ? [
        isRocketSightActivated.value ? aircraftRocketSight(sh(10.0), sh(10.0)) : null
        isAAMSightActivated.value ? aamAim(crosshairColorOpt, AlertColorHigh) : null
        agmAim(crosshairColorOpt)
        gbuAim(crosshairColorOpt)
        isTurretSightActivated.value ? aircraftTurretsComponent(crosshairColorOpt) : null
        isCanonSightActivated.value ? fixedGunsDirection(crosshairColorOpt) : null
        isParamTableActivated.value ? aircraftParamsTable(HudParamColor) : null
        isBombSightActivated.value ? bombSightComponent(sh(10.0), sh(10.0), crosshairColorOpt) : null
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


let function aircraftGunnerHud() {
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

let function aircraftPilotHud() {
  return {
    watch = [IsPilotHudVisible, isParamTableActivated]
    children = IsPilotHudVisible.value && isParamTableActivated.value
      ? aircraftParamsTable(HudParamColor)
      : null
  }
}


let function weaponHud() {
  return {
    watch = IsWeaponHudVisible
    children = IsWeaponHudVisible.value
      ? [
        aamAim(crosshairColorOpt, AlertColorHigh)
        agmAim(crosshairColorOpt)
        gbuAim(crosshairColorOpt)
      ]
      : null
  }
}

let function aircraftArbiterHud() {
  return {
    watch = [IsArbiterHudVisible, isParamTableActivated]
    children = IsArbiterHudVisible.value && isParamTableActivated.value
      ? aircraftArbiterParamsTable(HudParamColor)
      : null
  }
}

let function mkAgmAimIndicator(watchedColor) {
  return function() {
    return {
      watch = AtgmTrackerVisible
      size = flex()
      children = AtgmTrackerVisible.value ? [agmAim(watchedColor)] : null
    }
  }
}


let function aircraftHUDs() {
  let radarSize = sh(28)
  let radarPosComputed = Computed(@() [
    bw.value + 0.99 * rw.value - radarSize,
    bh.value + 0.45 * rh.value
  ])

  let twsSize = sh(20)
  let twsPosWatched = Computed(@() [
    bw.value + 0.01 * rw.value,
    bh.value + 0.37 * rh.value
  ])

  return @() {
    watch = [OpticAtgmSightVisible, IndicatorsVisible, LaserAtgmSightVisible]
    size = flex()
    children =
    [
      mkAircraftMainHud()
      aircraftGunnerHud
      aircraftPilotHud
      aircraftArbiterHud
      leftPanel
      twsElement(HudColor, twsPosWatched, twsSize)
      radarElement(HudColor, radarPosComputed, radarSize)
      OpticAtgmSightVisible.value ? opticAtgmSight(sw(100), sh(100)) : null
      mkAgmAimIndicator(crosshairColorOpt)
      !IndicatorsVisible.value ? null : weaponHud()
      laserPointComponent(HudColor)
      LaserAtgmSightVisible.value ? laserAtgmSight(sw(100), sh(100)) : null
      aircraftSightHud
      !LaserAtgmSightVisible.value ? compassElem(HudColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)]) : null
      planeHmd(sw(100), sh(100))
    ]
  }
}

let function aircraftRoot() {
  let children = aircraftHUDs()

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children

    function onAttach() {
      gui_scene.addPanel(0, planeMfd)
      gui_scene.addPanel(1, planeIls)
    }
    function onDetach() {
      gui_scene.removePanel(0)
      gui_scene.removePanel(1)
    }

  }
}

return aircraftRoot
