local { bw, bh, rw, rh } = require("style/screenState.nut")
local opticAtgmSight = require("opticAtgmSight.nut")
local laserAtgmSight = require("laserAtgmSight.nut")
local {OpticAtgmSightVisible, AtgmTrackerVisible, IsWeaponHudVisible, LaserAtgmSightVisible } = require("planeState.nut")
local {
  IndicatorsVisible, MainMask, SecondaryMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsGunnerHudVisible,
  HudColor, AlertColorHigh, IsBomberViewHudVisible} = require("airState.nut")
local aamAim = require("rocketAamAim.nut")
local agmAim = require("agmAim.nut")
local {paramsTable, taTarget, compassElem}  = require("airHudElems.nut")

local {aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight, laserPointComponent} = require("airSight.nut")

local {radarElement, twsElement} = require("airHudComponents.nut")

local compassSize = [hdpx(420), hdpx(40)]

local paramsTableWidthAircraft = hdpx(330)
local arbiterParamsTableWidthAircraft = hdpx(200)
local paramsTableHeightAircraft = hdpx(22)

local aircraftParamsTablePos = Computed(@() [max(bw.value, sw(20) - hdpx(660)), sh(10) - hdpx(100)])

local aircraftArbiterParamsTablePos = Computed(@() [max(bw.value, sw(17.5)), sh(12)])

local aircraftParamsTable = paramsTable(MainMask, SecondaryMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

local aircraftArbiterParamsTable = paramsTable(MainMask, SecondaryMask,
        arbiterParamsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftArbiterParamsTablePos,
        hdpx(1), true, false, true)

local function aircraftMainHud(isBackground) {
  return @(){
    watch = [IsMainHudVisible, IsBomberViewHudVisible]
    children =
      IsMainHudVisible.value
        ? [
            aircraftRocketSight(sh(2.0), sh(2.0), isBackground)
            aamAim(isBackground, HudColor, AlertColorHigh)
            agmAim(isBackground, HudColor)
            aircraftTurretsComponent(isBackground, false)
            fixedGunsDirection(isBackground)
            aircraftParamsTable(isBackground)
            taTarget(sw(25), sh(25), isBackground)
          ]
            : IsBomberViewHudVisible.value
        ? [
            aircraftParamsTable(isBackground, true)
          ]
            : null
  }
}


 local aircraftGunnerHud = @(isBackground)
  @() {
    watch = IsGunnerHudVisible
    children = IsGunnerHudVisible.value
      ? [
        aircraftTurretsComponent(isBackground, false)
        aircraftParamsTable(isBackground)
      ]
      : null
  }

local aircraftPilotHud = @(isBackground)
  @(){
    watch = IsPilotHudVisible
    children = IsPilotHudVisible.value
      ? aircraftParamsTable(isBackground)
      : null
  }


local weaponHud = @(isBackground)
  @() {
    watch = IsWeaponHudVisible
    children = IsWeaponHudVisible.value
      ? [
        aamAim(isBackground, HudColor, AlertColorHigh)
        agmAim(isBackground, HudColor)
      ]
      : null
  }

local aircraftArbiterHud = @(isBackground)
  @(){
    watch = IsArbiterHudVisible
    children = IsArbiterHudVisible.value
      ? aircraftArbiterParamsTable(isBackground)
      : null
  }

local agmAimIndicator = @(isBackground)
  @(){
    watch = AtgmTrackerVisible
    size = flex()
    children = AtgmTrackerVisible.value ? [agmAim(isBackground, HudColor)] : null
  }


local function aircraftHUDs(isBackground) {

  local radarSize = sh(28)
  local radarPosComputed = Computed(@() [
    bw.value + 0.99 * rw.value - radarSize,
    bh.value + 0.43 * rh.value
  ])

  local twsSize = sh(20)
  local twsPosWatched = Computed(@() [
    bw.value + 0.01 * rw.value,
    bh.value + 0.37 * rh.value
  ])

  return @() {
    watch = [OpticAtgmSightVisible, IndicatorsVisible, LaserAtgmSightVisible]
    children =
    [
      !IndicatorsVisible.value ? null : aircraftMainHud(isBackground)
      !IndicatorsVisible.value ? null : aircraftGunnerHud(isBackground)
      !IndicatorsVisible.value ? null : aircraftPilotHud(isBackground)
      !IndicatorsVisible.value ? null : aircraftArbiterHud(isBackground)
      twsElement(HudColor, twsPosWatched, twsSize)
      radarElement(HudColor, radarPosComputed, radarSize)
      OpticAtgmSightVisible.value ? opticAtgmSight(sw(100), sh(100)) : null
      agmAimIndicator(isBackground)
      !IndicatorsVisible.value ? null : weaponHud(isBackground)
      laserPointComponent(isBackground)
      LaserAtgmSightVisible.value && !isBackground ? laserAtgmSight(sw(100), sh(100)) : null
      !LaserAtgmSightVisible.value ? compassElem(isBackground, compassSize, [sw(50) - 0.5*compassSize[0], sh(15)]) : null
    ]
  }
}

local function aircraftRoot() {
  local children = [aircraftHUDs(true), aircraftHUDs(false)]

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children
  }
}

return aircraftRoot
