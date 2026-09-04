import "%rGui/mfd.nut" as mfdHud
import "%rGui/rocketAamAim.nut" as aamAim
import "%rGui/agmAim.nut" as agmAim
import "%rGui/fpvShellHud.nut" as fpvShellHud
from "%rGui/planeIls.nut" import planeIlsSwitcher
from "%rGui/style/screenState.nut" import bw, bh, rw, rh
from "%rGui/airState.nut" import IndicatorsVisible, MainMask, SecondaryMask, TertiaryMask, IsArbiterHudVisible, IsPilotHudVisible, IsMainHudVisible
  , IsGunnerHudVisible, HudColor, MfdColor, AlertColorHigh, IsMfdEnabled, IsSightHudVisible
from "%rGui/radarState.nut" import isCollapsedRadarInReplay, IsRadarDamaged, IsRadarVisible, IsRadar2Visible, ViewMode
from "%rGui/airHudElems.nut" import paramsTable, taTarget, compassElem, rocketAim, vertSpeed, horSpeed
from "%rGui/airSight.nut" import gunDirection, fixedGunsDirection, helicopterCCRP, bombSightComponent
from "%rGui/airHudComponents.nut" import radarElement, twsElement
from "%rGui/airHudLeftPanel.nut" import leftPanel
from "%rGui/hud/actionBarTopPanel.nut" import actionBarTopPanel
from "%rGui/globals/panelIds.nut" import PNL_ID_ILS, PNL_ID_MFD
from "%rGui/radar.nut" import radarHud, radarIndication
from "%rGui/options/options.nut" import isHeliPilotHudDisabled
from "%rGui/planeHmd.nut" import planeHmdElem
from "%rGui/hudState.nut" import isPlayingReplay, isSpectatorMode
from "%rGui/twsState.nut" import IsTwsDamaged
from "%rGui/planeState/planeWeaponState.nut" import ShellFPVModeEnabled
from "%rGui/globals/ui_library.nut" import *

let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")
let { helicopterTargetingPodSight } = require("%rGui/targetingPodSight.nut")

let compassSize = [hdpx(420), hdpx(40)]
let compassPos = [sw(50) - 0.5 * compassSize[0], sh(15)]

const paramsTableWidthHeli = hdpx(450)
const paramsTableHeightHeli = hdpx(28)
const arbiterParamsTableWidthHelicopter = hdpx(200)
let positionParamsTable = Computed(@() [max(bw.get(), sw(50) - hdpx(660)), sh(50) - hdpx(80)])

let radarSizeComp = Computed(@() isPlayingReplay.get() ? [sh(50), sh(25)] : [sh(66), sh(33)])
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
      bw.get() + hdpx(75), bh.get()
    ]
})

let twsSize = [sh(28), sh(50)]
let twsPosComputed = Computed(@() isPlayingReplay.get() ?
  [
    scrn_tgt(0.24) + fpx(45) + scrn_tgt(0.005) + fpx(16) + 6 + bw.get(),
    bh.get() + rh.get() - twsSize[1]
  ] : [
    bw.get() + 0.985 * rw.get() - twsSize[0],
    bh.get() + 0.5 * (rh.get() * 0.98 - twsSize[0])
  ])

let helicopterArbiterParamsTablePos = Computed(@() [max(bw.get(), sw(17.5)), sh(12)])

let helicopterParamsTable = paramsTable(MainMask, SecondaryMask, TertiaryMask,
  paramsTableWidthHeli, paramsTableHeightHeli,
  positionParamsTable,
  hdpx(5))

let helicopterArbiterParamsTable = paramsTable(MainMask, SecondaryMask, TertiaryMask,
  arbiterParamsTableWidthHelicopter, paramsTableHeightHeli,
  helicopterArbiterParamsTablePos,
  hdpx(1), true, false, true)

let helicopterParamsTableView = @(color, isReplayVal, isRefereeModeVal)
  ((isReplayVal || isRefereeModeVal) ? helicopterArbiterParamsTable : helicopterParamsTable)(color)

function helicopterMainHud() {
  return @() {
    watch = [IsMainHudVisible, isPlayingReplay, isSpectatorMode]
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
      helicopterParamsTableView(HudColor, isPlayingReplay.get(), isSpectatorMode.get())
      taTarget(sw(25), sh(25), false)
      bombSightComponent(sh(10.0), sh(10.0), HudColor)
    ]
    : null
  }
}

function helicopterGunnerHud() {
  return @() {
    watch = [IsGunnerHudVisible, isPlayingReplay, isSpectatorMode]
    children = IsGunnerHudVisible.get()
    ? [
        gunDirection(HudColor, false)
        fixedGunsDirection(HudColor)
        helicopterCCRP(HudColor)
        vertSpeed(sh(4.0), sh(15), sw(50) + hdpx(315), sh(42.5), HudColor.get())
        helicopterParamsTableView(HudColor, isPlayingReplay.get(), isSpectatorMode.get())
      ]
    : null
  }
}

let pilotHud = @() {
  watch = [IsPilotHudVisible, isHeliPilotHudDisabled, isPlayingReplay, isSpectatorMode]
  children = IsPilotHudVisible.get() && !isHeliPilotHudDisabled.get()
    ? helicopterParamsTableView(HudColor, isPlayingReplay.get(), isSpectatorMode.get())
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
    watch = [IsMfdEnabled, HudColor, IsRadarVisible, IsRadar2Visible, isCollapsedRadarInReplay, IsRadarDamaged, IsTwsDamaged, IsSightHudVisible,
      radarPosWatched, radarSizeComp, isSquareRadarEnabled]
    children = IsSightHudVisible.get() ? helicopterTargetingPodSight
    : [
      helicopterMainHud()
      helicopterGunnerHud()
      helicopterArbiterHud()
      pilotHud
      !IsMfdEnabled.get() ? twsElement(IsTwsDamaged.get() ? AlertColorHigh : MfdColor, twsPosComputed, twsSize) : null
      !IsMfdEnabled.get() ? radarElement(IsRadarDamaged.get() ? AlertColorHigh : MfdColor, radarPosWatched.get(), radarSizeComp.get(), isSquareRadarEnabled.get()) : null
      compassElem(MfdColor, compassSize, compassPos)
      !isCollapsedRadarInReplay.get()
        ? radarHud(radarSizeComp.get()[0], radarSizeComp.get()[1], radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {
          canZoom = true
          magnifiedIndicator = true
          moveMagnifiedIndicatorRight = !IsSightHudVisible.get()
        }, true) : null
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
  size = FLEX
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  children = (IndicatorsVisible.get() || IsMfdEnabled.get())
    ? helicopterIndicators
    : null
}

let helicopterHud = @() {
  watch = ShellFPVModeEnabled
  size = const [sw(100), sh(100)]
  children = ShellFPVModeEnabled.get() ? fpvShellHud :
  [
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

return {
  helicopterParamsTableView
  helicopterHud
}
