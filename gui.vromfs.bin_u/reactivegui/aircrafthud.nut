import "%rGui/planeMfd.nut" as planeMfd
import "%rGui/opticAtgmSight.nut" as opticAtgmSight
import "%rGui/laserAtgmSight.nut" as laserAtgmSight
import "%rGui/rocketAamAim.nut" as aamAim
import "%rGui/agmAim.nut" as agmAim
import "%rGui/gbuAim.nut" as gbuAim
import "%rGui/fpvShellHud.nut" as fpvShellHud
from "%rGui/planeIls.nut" import planeIlsSwitcher
from "%rGui/planeHmd.nut" import planeHmdElem
from "%rGui/style/screenState.nut" import bw, bh, rw, rh
from "%rGui/targetingPodSight.nut" import aircraftTargetingPodSight
from "%rGui/airHudLeftPanel.nut" import leftPanel
from "%rGui/planeState/planeWeaponState.nut" import OpticAtgmSightVisible, AtgmTrackerVisible, IsWeaponHudVisible, LaserAtgmSightVisible, TargetingPodSightVisible, ShellFPVModeEnabled
from "%rGui/airState.nut" import IndicatorsVisible, MainMask, SecondaryMask, IsPilotHudVisible, IsMainHudVisible, IsGunnerHudVisible, HudColor
  , AlertColorHigh, IsBomberViewHudVisible, HudParamColor, isBombSightActivated, isAAMSightActivated, isRocketSightActivated, isCanonSightActivated
  , isTurretSightActivated, isParamTableActivated
from "%rGui/airHudElems.nut" import paramsTable, agmLaunchZoneTps, compassElem
from "%rGui/airSight.nut" import aircraftTurretsComponent, fixedGunsDirection, aircraftRocketSight, laserPointComponent, bombSightComponent, getTooFastText
from "%rGui/airHudComponents.nut" import radarElement, twsElement
from "%rGui/twsState.nut" import IsMlwsLwsHudVisible, IsTwsDamaged
from "%rGui/options/options.nut" import crosshairColorOpt
from "%rGui/radarComponent.nut" import maxLabelWidth, maxLabelHeight
from "%rGui/hud/actionBarTopPanel.nut" import actionBarTopPanel
from "%rGui/globals/panelIds.nut" import PNL_ID_ILS, PNL_ID_MFD
from "%rGui/radar.nut" import radarHud, radarIndication
from "%rGui/hudState.nut" import isPlayingReplay, isSpectatorMode
from "%rGui/radarState.nut" import isCollapsedRadarInReplay, IsRadarDamaged, ViewMode
from "%rGui/hud/dmgIndicatorState.nut" import dmgIndicatorWidth
from "%rGui/agmAimState.nut" import AgmBlockedState, AgmMachLimit
from "%rGui/globals/ui_library.nut" import *

let { TertiaryMask IsArbiterHudVisible } = require("%rGui/airState.nut")
let { styleText } = require("%rGui/style/airHudStyle.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")

let compassSize = [hdpx(420), hdpx(40)]

const paramsTableWidthAircraft = hdpx(600)
const arbiterParamsTableWidthAircraft = hdpx(200)
const paramsTableHeightAircraft = hdpx(22)

let aircraftParamsTablePos = Computed(@() [max(bw.get(), sw(20) - hdpx(660)), max(bh.get(), sh(10) - hdpx(100))])

let aircraftArbiterParamsTablePos = Computed(@() [max(bw.get(), sw(17.5)), sh(12)])

let radarSizeComp = Computed(@() isPlayingReplay.get() ? [sh(25), sh(50)] : [sh(33), sh(66)])
let isSquareRadarEnabled = Computed(@() ViewMode.get() == RadarViewMode.B_SCOPE_SQUARE)
let radarPosWatched = Computed(function() {
  let radarSize = radarSizeComp.get()
  return isPlayingReplay.get() ?
    [
      isSquareRadarEnabled.get()
        ? bw.get() + rw.get() - fsh(33) - radarSize[0]
        : bw.get() + rw.get() - fsh(33) - radarSize[0] - fsh(1),
      isSquareRadarEnabled.get()
        ? bh.get() + rh.get() - radarSize[1] - fsh(7)
        : bh.get() + rh.get() - radarSize[1] - fsh(15)
    ] : [
      bw.get() + rw.get() - radarSize[0] - 2 * maxLabelWidth,
      bh.get() + 0.45 * rh.get() - maxLabelHeight - radarSize[1] + sh(33)
    ]
})

let twsSize = [sh(28), sh(50)]
let twsPosWatched = Computed(@()
  isPlayingReplay.get() ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(32) + 6 + bw.get(),
    bh.get() + rh.get() - twsSize[1] - dmgIndicatorWidth.get() - hdpx(50)
  ] :
  (IsMlwsLwsHudVisible.get() ?
  [
    bw.get() + 0.02 * rw.get(),
    bh.get() + 0.53 * rh.get() - twsSize[1] * 0.5
  ] :
  [
    bw.get() + 0.01 * rw.get(),
    bh.get() + 0.5 * (rh.get() - twsSize[1])
  ])
)

let aircraftParamsTable = paramsTable(MainMask, SecondaryMask, TertiaryMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

let aircraftArbiterParamsTable = paramsTable(MainMask, SecondaryMask, TertiaryMask,
        arbiterParamsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftArbiterParamsTablePos,
        hdpx(1), true, false, true)

let aircraftParamsTableView = @(color, isReplayVal, isRefereeModeVal)
  ((isReplayVal || isRefereeModeVal) ? aircraftArbiterParamsTable : aircraftParamsTable)(color)

let agmHighSpeedWarning = @() styleText.__merge({
  watch = [AgmBlockedState, AgmMachLimit]
  rendObj = ROBJ_TEXT
  pos = const [sw(50) + sw(5), sh(50) - sw(5)]
  text = AgmBlockedState.get() ? getTooFastText(AgmMachLimit.get(), "HUD/AGM_HIGH_SPEED") : ""
})

function mkAircraftMainHud() {
  let watch = [IsMainHudVisible, IsBomberViewHudVisible, isRocketSightActivated, isAAMSightActivated,
    isTurretSightActivated, isCanonSightActivated, isParamTableActivated, isBombSightActivated, isPlayingReplay, isSpectatorMode]

  return function() {
    let children = IsMainHudVisible.get()
    ? [
        isRocketSightActivated.get() ? aircraftRocketSight(sh(10.0), sh(10.0)) : null
        isAAMSightActivated.get() ? aamAim(crosshairColorOpt, AlertColorHigh) : null
        agmAim(crosshairColorOpt, AlertColorHigh)
        gbuAim(crosshairColorOpt, AlertColorHigh)
        isTurretSightActivated.get() ? aircraftTurretsComponent(crosshairColorOpt) : null
        isCanonSightActivated.get() ? fixedGunsDirection(crosshairColorOpt) : null
        isParamTableActivated.get() ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get()) : null
        isBombSightActivated.get() ? bombSightComponent(sh(10.0), sh(10.0), crosshairColorOpt) : null
        agmHighSpeedWarning
        agmLaunchZoneTps(HudColor)
      ]
        : IsBomberViewHudVisible.get()
    ? [
        aircraftParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get())
      ]
    : null

    return {
      watch
      children
    }
  }
}

function aircraftGunnerHud() {
  return {
    watch = [IsGunnerHudVisible, isParamTableActivated, isTurretSightActivated, isPlayingReplay, isSpectatorMode]
    children = IsGunnerHudVisible.get()
      ? [
        isTurretSightActivated.get() ? aircraftTurretsComponent(crosshairColorOpt) : null
        isParamTableActivated.get() ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get()) : null
      ]
      : null
  }
}

function aircraftPilotHud() {
  return {
    watch = [IsPilotHudVisible, isParamTableActivated, OpticAtgmSightVisible, LaserAtgmSightVisible, isPlayingReplay,
      isSpectatorMode]
    children = (IsPilotHudVisible.get() || OpticAtgmSightVisible.get() || LaserAtgmSightVisible.get()) && isParamTableActivated.get()
      ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get())
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
      size = FLEX
      children = AtgmTrackerVisible.get() ? [
        agmAim(watchedColor, watchedAlertColor, false)
        gbuAim(watchedColor, watchedAlertColor, false)
      ] : null
    }
  }
}

let aircraftDefaultHud = @(){
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = FLEX
  watch = [IsRadarDamaged, isCollapsedRadarInReplay, IsTwsDamaged, radarPosWatched, LaserAtgmSightVisible,
    radarSizeComp, isSquareRadarEnabled]
  children = [
    twsElement(IsTwsDamaged.get() ? AlertColorHigh : HudColor, twsPosWatched, twsSize)
    radarElement(IsRadarDamaged.get() ? AlertColorHigh : HudColor, radarPosWatched.get(), radarSizeComp.get(), isSquareRadarEnabled.get())
    radarIndication(HudColor)
    !isCollapsedRadarInReplay.get() ? radarHud(radarSizeComp.get()[0], radarSizeComp.get()[1], radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {
      canZoom = true
      magnifiedIndicator = true
    }, true) : null
    laserPointComponent(HudColor)
    !LaserAtgmSightVisible.get() ? compassElem(HudColor, compassSize, [sw(50) - 0.5 * compassSize[0], sh(15)]) : null
  ]
}

let aircraftHud = {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = const [sw(100), sh(100)]
  children = @() {
    watch = [OpticAtgmSightVisible, LaserAtgmSightVisible, TargetingPodSightVisible, ShellFPVModeEnabled]
    size = FLEX
    children = ShellFPVModeEnabled.get() ? fpvShellHud :
    [
      mkAircraftMainHud()
      aircraftGunnerHud
      aircraftPilotHud
      aircraftArbiterHud
      leftPanel
      actionBarTopPanel
      OpticAtgmSightVisible.get() ? opticAtgmSight(sw(100), sh(100)) : null
      mkAgmAimIndicator(crosshairColorOpt, AlertColorHigh)
      weaponHud
      LaserAtgmSightVisible.get() ? laserAtgmSight(sw(100), sh(100)) : null
      planeHmdElem
      sensorViewIndicators
      TargetingPodSightVisible.get() ? aircraftTargetingPodSight(sw(100), sh(100))
      : aircraftDefaultHud
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

return {
  aircraftParamsTableView
  aircraftHud
}
