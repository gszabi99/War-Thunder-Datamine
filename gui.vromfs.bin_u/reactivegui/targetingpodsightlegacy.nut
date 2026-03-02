from "%rGui/globals/ui_library.nut" import *
let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let { turretAngles, sight, paramsTable, targetSize, launchDistanceMax, compassElem,
  lockSight, rangeFinder, vertSpeed, agmLaunchZone, detectAlly } = require("%rGui/airHudElems.nut")
let { TargetPodMask, EmptyMask, SightMask, HudColor, HudParamColor, AlertColorHigh, IsRangefinderEnabled,
  MfdColor, IsMfdEnabled } = require("%rGui/airState.nut")
let missileSalvoTimer = require("%rGui/missileSalvoTimer.nut")
let { radarHud } = require("%rGui/radar.nut")
let { isCollapsedRadarInReplay } = require("%rGui/radarState.nut")
let { isPlayingReplay } = require("%rGui/hudState.nut")
let { maxLabelWidth, maxLabelHeight } = require("%rGui/radarComponent.nut")
let { IsMlwsLwsHudVisible, IsTwsDamaged } = require("%rGui/twsState.nut")
let { twsElement } = require("%rGui/airHudComponents.nut")
let { laserPointComponent, laserDesignatorComponent, laserDesignatorStatusComponent,
  agmTrackZoneComponent, agmTrackerStatusComponent, gunDirection } = require("%rGui/airSight.nut")
let { crosshairColorOpt } = require("%rGui/options/options.nut")
let agmAim = require("%rGui/agmAim.nut")
let sensorViewIndicators = require("%rGui/hud/sensorViewIndicator.nut")

let aircraftSight = @(width, height) function() {
  let paramsTableWidth = hdpx(330)
  let paramsTableHeight = hdpx(22)
  let tablePos = Computed(@() [max(bw.get(), sw(50) - hdpx(500)), sh(50) - hdpx(100)])

  let aircraftParamsTable = paramsTable(TargetPodMask, EmptyMask,
      paramsTableWidth, paramsTableHeight,
      tablePos,
      hdpx(1), true, false, true)

  let compassSize = [hdpx(420), hdpx(40)]
  let compassPos = [sw(50) - 0.5 * compassSize[0], sh(15)]

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

  return {
    watch = [IsRangefinderEnabled, isCollapsedRadarInReplay, radarPosWatched, IsTwsDamaged]
    size = [width, height]
    children = [
      missileSalvoTimer(HudColor, sw(50) - hdpx(150), sh(90) - hdpx(174))
      turretAngles(HudColor, hdpx(150), hdpx(150), sw(50), sh(90), 0.22)
      sight(HudColor, sw(50), sh(50), hdpx(500))
      targetSize(HudColor, sw(100), sh(100))
      launchDistanceMax(HudColor, hdpx(150), hdpx(150), sw(50), sh(90))
      aircraftParamsTable(HudParamColor, false)
      compassElem(HudColor, compassSize, compassPos)
      !isCollapsedRadarInReplay.get() ? radarHud(sh(33), sh(33), radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {}, true) : null
      twsElement(IsTwsDamaged.get() ? AlertColorHigh : HudColor, twsPosWatched, twsSize)
      laserDesignatorStatusComponent(HudColor, sw(50), sh(38))
      IsRangefinderEnabled.get() ? rangeFinder(HudColor, sw(50), sh(59)) : null
      lockSight(crosshairColorOpt, hdpx(150), hdpx(100), sw(50), sh(50))
      laserPointComponent(HudColor)
    ]
  }
}

let helicopterSight = @(width, height) function() {
  let compassSize = [hdpx(420), hdpx(40)]
  let compassPos = [sw(50) - 0.5 * compassSize[0], sh(15)]

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

  let paramsTableHeightHeli = hdpx(28)
  let paramsSightTableWidth = hdpx(270)
  let positionParamsSightTable = Watched([sw(50) - hdpx(250) - hdpx(200), hdpx(480)])

  let helicopterSightParamsTable = paramsTable(SightMask, EmptyMask,
    paramsSightTableWidth, paramsTableHeightHeli,
    positionParamsSightTable,
    hdpx(3))

  return {
    watch = [HudParamColor, isCollapsedRadarInReplay, radarPosWatched, IsTwsDamaged, IsMfdEnabled]
    size = [width, height]
    children = [
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
      !isCollapsedRadarInReplay.get()
        ? radarHud(sh(33), sh(33), radarPosWatched.get()[0], radarPosWatched.get()[1], HudColor, {}, true) : null
      compassElem(MfdColor, compassSize, compassPos)
      !IsMfdEnabled.get() ? twsElement(IsTwsDamaged.get() ? AlertColorHigh : MfdColor, twsPosComputed, twsSize) : null
      sensorViewIndicators
    ]
  }
}

return {
  aircraftSight
  helicopterSight
}