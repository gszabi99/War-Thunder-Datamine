from "%rGui/globals/ui_library.nut" import *

let mfdHud = require("mfd.nut")
let heliIlsHud = require("heliIls.nut")
let { bw, bh, rw, rh } = require("style/screenState.nut")
let {
  IndicatorsVisible, MainMask, SecondaryMask, SightMask, EmptyMask, IsArbiterHudVisible,
  IsPilotHudVisible, IsMainHudVisible, IsSightHudVisible, IsGunnerHudVisible,
  HudColor, MfdColor, AlertColorHigh, IsMfdEnabled, HudParamColor } = require("airState.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let { paramsTable, taTarget, compassElem, rocketAim, vertSpeed, horSpeed, turretAngles, agmLaunchZone,
  launchDistanceMax, lockSight, targetSize, sight, rangeFinder, detectAlly } = require("airHudElems.nut")
let {
  gunDirection, fixedGunsDirection, helicopterCCRP, agmTrackerStatusComponent, bombSightComponent,
  laserDesignatorStatusComponent, laserDesignatorComponent, agmTrackZoneComponent } = require("airSight.nut")
let { radarElement, twsElement } = require("airHudComponents.nut")
let leftPanel = require("airHudLeftPanel.nut")

let compassSize = [hdpx(420), hdpx(40)]

let paramsTableWidthHeli = hdpx(450)
let paramsTableHeightHeli = hdpx(28)
let paramsSightTableWidth = hdpx(270)
let arbiterParamsTableWidthHelicopter = hdpx(200)
let positionParamsTable = Computed(@() [max(bw.value, sw(50) - hdpx(660)), sh(50) - hdpx(100)])
let positionParamsSightTable = Watched([sw(50) - hdpx(250) - hdpx(200), hdpx(480)])

let radarSize = sh(28)
let radarPosWatched = Computed(@() [bw.value, bh.value])
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

let function helicopterMainHud() {
  return @() {
    watch = IsMainHudVisible
    children = IsMainHudVisible.value
    ? [
      rocketAim(sh(0.8), sh(1.8), HudColor.value)
      aamAim(HudColor, AlertColorHigh)
      agmAim(HudColor)
      gunDirection(HudColor, false)
      fixedGunsDirection(HudColor)
      helicopterCCRP(HudColor)
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.value)
      horSpeed(HudColor.value)
      helicopterParamsTable(HudColor)
      taTarget(sw(25), sh(25))
    ]
    : null
  }
}

let function helicopterSightHud() {
  return @() {
    watch = IsSightHudVisible
    children = IsSightHudVisible.value ?
    [
      vertSpeed(sh(4.0), sh(30), sw(50) + hdpx(325), sh(35), HudParamColor.value)
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
      agmAim(HudParamColor)
      gunDirection(HudParamColor, true)
    ]
    : null
  }
}

let function helicopterGunnerHud() {
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

let function pilotHud() {
  return @() {
    watch = IsPilotHudVisible
    children = IsPilotHudVisible.value ?
    [
      vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(325), sh(42.5), HudColor.value)
      helicopterParamsTable(HudColor)
    ]
    : null
  }
}

let function helicopterArbiterHud() {
  return @() {
    watch = IsArbiterHudVisible
    children = IsArbiterHudVisible.value ?
    [
      helicopterArbiterParamsTable(HudColor)
    ]
    : null
  }
}

let function mkHelicopterIndicators() {
  return @() {
    watch = [IsMfdEnabled, HudColor]
    children = [
      helicopterMainHud()
      helicopterSightHud()
      helicopterGunnerHud()
      helicopterArbiterHud()
      pilotHud()
      !IsMfdEnabled.value ? twsElement(MfdColor, twsPosComputed, twsSize) : null
      !IsMfdEnabled.value ? radarElement(MfdColor, radarPosWatched, radarSize) : null
      compassElem(MfdColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)])
      bombSightComponent(sh(10.0), sh(10.0), HudColor)
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
    indicatorsCtor
  ]

  function onAttach() {
    gui_scene.addPanel(0, mfdHud)
    gui_scene.addPanel(1, heliIlsHud)
  }
  function onDetach() {
    gui_scene.removePanel(0)
    gui_scene.removePanel(1)
  }
}

return helicopterRoot
