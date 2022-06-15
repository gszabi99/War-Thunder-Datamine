let { bw, bh, rw, rh } = require("style/screenState.nut")
let opticAtgmSight = require("opticAtgmSight.nut")
let laserAtgmSight = require("laserAtgmSight.nut")
let targetingPodSight = require("targetingPodSight.nut")
let {OpticAtgmSightVisible, AtgmTrackerVisible, IsWeaponHudVisible, LaserAtgmSightVisible, TargetingPodSightVisible } = require("planeState/planeWeaponState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsGunnerHudVisible,
  HudColor, AlertColorHigh, IsBomberViewHudVisible,
  isBombSightActivated, isAAMSightActivated, isRocketSightActivated,
  isCanonSightActivated, isTurretSightActivated, isParamTableActivated } = require("airState.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let {paramsTable, taTarget, compassElem, lockSight}  = require("airHudElems.nut")

let {
  aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight,
  laserPointComponent, bombSightComponent, laserDesignatorStatusComponent } = require("airSight.nut")

let {radarElement, twsElement} = require("airHudComponents.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthAircraft = hdpx(330)
let arbiterParamsTableWidthAircraft = hdpx(200)
let paramsTableHeightAircraft = hdpx(22)

let aircraftParamsTablePos = Computed(@() [max(bw.value, sw(20) - hdpx(660)), sh(10) - hdpx(100)])

let aircraftArbiterParamsTablePos = Computed(@() [max(bw.value, sw(17.5)), sh(12)])

let aircraftParamsTable = paramsTable(MainMask, SecondaryMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

let aircraftArbiterParamsTable = paramsTable(MainMask, SecondaryMask,
        arbiterParamsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftArbiterParamsTablePos,
        hdpx(1), true, false, true)

let function aircraftMainHud(isBackground) {
  return @(){
    watch = [IsMainHudVisible, IsBomberViewHudVisible, isRocketSightActivated, isAAMSightActivated,
      isTurretSightActivated, isCanonSightActivated, isParamTableActivated, isBombSightActivated]
    children =
      IsMainHudVisible.value
        ? [
            isRocketSightActivated.value ? aircraftRocketSight(sh(10.0), sh(10.0)) : null
            isAAMSightActivated.value ? aamAim(HudColor, AlertColorHigh, isBackground) : null
            agmAim(HudColor, isBackground)
            isTurretSightActivated.value ? aircraftTurretsComponent(HudColor) : null
            isCanonSightActivated.value ? fixedGunsDirection(HudColor, isBackground) : null
            isParamTableActivated.value ? aircraftParamsTable(isBackground) : null
            isBombSightActivated.value ? bombSightComponent(sh(10.0), sh(10.0), isBackground) : null
            taTarget(sw(25), sh(25), isBackground)
          ]
            : IsBomberViewHudVisible.value
        ? [
            aircraftParamsTable(isBackground, false, true)
          ]
            : null
  }
}


 let aircraftGunnerHud = @(isBackground)
  @() {
    watch = [IsGunnerHudVisible, isParamTableActivated, isTurretSightActivated]
    children = IsGunnerHudVisible.value
      ? [
        isTurretSightActivated.value ? aircraftTurretsComponent() : isTurretSightActivated
        isParamTableActivated.value ? aircraftParamsTable(isBackground) : null
      ]
      : null
  }

let aircraftPilotHud = @(isBackground)
  @(){
    watch = [IsPilotHudVisible, isParamTableActivated]
    children = IsPilotHudVisible.value && isParamTableActivated.value
      ? aircraftParamsTable(isBackground)
      : null
  }


let weaponHud = @(isBackground)
  @() {
    watch = IsWeaponHudVisible
    children = IsWeaponHudVisible.value
      ? [
        aamAim(HudColor, AlertColorHigh, isBackground)
        agmAim(HudColor, isBackground)
      ]
      : null
  }

let aircraftArbiterHud = @(isBackground)
  @(){
    watch = [IsArbiterHudVisible, isParamTableActivated]
    children = IsArbiterHudVisible.value && isParamTableActivated.value
      ? aircraftArbiterParamsTable(isBackground)
      : null
  }

let agmAimIndicator = @(watchedColor, isBackground)
  @(){
    watch = AtgmTrackerVisible
    size = flex()
    children = AtgmTrackerVisible.value ? [agmAim(watchedColor, isBackground)] : null
  }


let function aircraftHUDs(isBackground) {

  let radarSize = sh(28)
  let radarPosComputed = Computed(@() [
    bw.value + 0.99 * rw.value - radarSize,
    bh.value + 0.43 * rh.value
  ])

  let twsSize = sh(20)
  let twsPosWatched = Computed(@() [
    bw.value + 0.01 * rw.value,
    bh.value + 0.37 * rh.value
  ])

  return @() {
    watch = [OpticAtgmSightVisible, IndicatorsVisible, LaserAtgmSightVisible, TargetingPodSightVisible]
    children =
    [
      aircraftMainHud(isBackground)
      aircraftGunnerHud(isBackground)
      aircraftPilotHud(isBackground)
      aircraftArbiterHud(isBackground)
      twsElement(HudColor, twsPosWatched, twsSize)
      radarElement(HudColor, radarPosComputed, radarSize)
      OpticAtgmSightVisible.value ? opticAtgmSight(sw(100), sh(100)) : null
      agmAimIndicator(HudColor, isBackground)
      !IndicatorsVisible.value ? null : weaponHud(isBackground)
      laserPointComponent(HudColor, isBackground)
      LaserAtgmSightVisible.value && !isBackground ? laserAtgmSight(sw(100), sh(100)) : null
      TargetingPodSightVisible.value && !isBackground ? targetingPodSight(sw(100), sh(100)) : null
      TargetingPodSightVisible.value && !isBackground ? laserDesignatorStatusComponent(HudColor, sw(50), sh(38), isBackground) : null
      TargetingPodSightVisible.value && !isBackground ? lockSight(HudColor, hdpx(150), hdpx(100), sw(50), sh(50), isBackground) : null
      !LaserAtgmSightVisible.value ? compassElem(HudColor, compassSize, [sw(50) - 0.5*compassSize[0], sh(15)], isBackground) : null
    ]
  }
}

let function aircraftRoot() {
  let children = [aircraftHUDs(true), aircraftHUDs(false)]

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children
  }
}

return aircraftRoot
