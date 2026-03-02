from "%rGui/globals/ui_library.nut" import *
let { bw, bh, rw, rh } = require("%rGui/style/screenState.nut")
let { turretAngles, sight, paramsTable, targetSize, launchDistanceMax, lockSight, rangeFinder, airHorizon,
  agmLaunchZone, detectAlly, compassElem } = require("%rGui/airHudElems.nut")
let { TargetPodMask, EmptyMask, IsRangefinderEnabled, SightMask, AlertColorHigh,
  IsMfdEnabled } = require("%rGui/airState.nut")
let { isThermalSightActive } = require("%rGui/hudState.nut")
let missileSalvoTimer = require("%rGui/missileSalvoTimer.nut")
let { laserDesignatorStatusComponent, laserDesignatorComponent, gunDirection,
  agmTrackerStatusComponent, agmTrackZoneComponent } = require("%rGui/airSight.nut")
let { crosshairColorOpt } = require("%rGui/options/options.nut")
let HudStyle = require("%rGui/style/airHudStyle.nut")
let { mfdCameraSetting } = require("%rGui/planeMfdCamera.nut")
let tads = require("%rGui/planeCockpit/mfdTads.nut")
let litening2 = require("%rGui/planeCockpit/mfdLitening2.nut")
let shkvalKa52 = require("%rGui/planeCockpit/mfdShkvalKa52.nut")
let hudUnitType = require("%rGui/hudUnitType.nut")
let agmAim = require("%rGui/agmAim.nut")
let { isCollapsedRadarInReplay } = require("%rGui/radarState.nut")
let { radarHud } = require("%rGui/radar.nut")
let { IsTwsDamaged } = require("%rGui/twsState.nut")
let { twsElement } = require("%rGui/airHudComponents.nut")
let legacySight = require("%rGui/targetingPodSightLegacy.nut")

let useLegacyLayout = true

let baseColor = Watched(Color(255, 255, 255, 255))

let reticle = @(pos_x, pos_y) function() {
  let { isTadsApache, isLitening2, lineWidthScale, isShkvalKa52 } = mfdCameraSetting.get()

  return {
    watch = [mfdCameraSetting, baseColor]
    size = flex()
    children = [
      isTadsApache ? tads.losReticle([sh(100), sh(100)], baseColor.get(), 5) :
      isLitening2 ? litening2.reticle(sh(100), sh(100), lineWidthScale, baseColor.get()):
      isShkvalKa52 ? shkvalKa52.reticle :
      sight(baseColor, pos_x, pos_y, hdpx(500))
    ]
  }
}

let lockSightIndicator = function() {
  let { isTadsApache } = mfdCameraSetting.get()

  return {
    watch = mfdCameraSetting
    size = flex()
    children = [
      isTadsApache ? null :
      lockSight(crosshairColorOpt, hdpx(150), hdpx(100), sw(50), sh(50))
    ]
  }
}

let targetSizeIndicator = @(color, width, height) function(){
  let { isShkvalKa52 } = mfdCameraSetting.get()

  return {
    watch = mfdCameraSetting
    size = flex()
    children = [
      isShkvalKa52 ? shkvalKa52.targetSize(true) :
      targetSize(color, width, height)
    ]
  }
}

let planeAttitude = @(color_watched) function() {
  let { isShkvalKa52 } = mfdCameraSetting.get()
  let isVisible = !isShkvalKa52

  return {
    watch = [mfdCameraSetting, color_watched]
    pos = [sw(5), sh(80)]
    children = isVisible ? airHorizon(HudStyle.styleLineForeground, hdpx(40), color_watched.get()) : null
  }
}

let flirIndicator = @(color_watched) function() {
  let { isShkvalKa52 } = mfdCameraSetting.get()
  let isVisible = isThermalSightActive.get() && !isShkvalKa52

  return {
    watch = [mfdCameraSetting, isThermalSightActive]
    size = flex()
    children = isVisible ? @() {
      watch = color_watched
      size = SIZE_TO_CONTENT
      rendObj = ROBJ_TEXT
      pos = [sw(20), sh(20)]
      color = color_watched.get()
      font = Fonts.hud
      fontSize = HudStyle.hudFontHgt
      text = "FLIR"
    } : null
  }
}

function commonSight(width, height) {
  let { isShkvalKa52, isTadsApache, isLitening2 } = mfdCameraSetting.get()

  let turretAnglesStyle = isShkvalKa52 ? {
    launchPermittedIndicator = {
      text = "ПР"
    }
  } : isTadsApache || isLitening2 ? {
    launchPermittedIndicator = {
      text = "MSL READY"
    }
  } : {}

  if (hudUnitType.isHelicopter())
    turretAnglesStyle.__update({
      showAltitude = true
      showVerticalSpeed = true
    })

  let compassSize = [hdpx(420), hdpx(40)]
  let compassPos = [sw(50) - 0.5 * compassSize[0], hdpx(15)]

  let radarSize = [sh(33), sh(33)]
  let radarPos = Computed(@() [
    bw.get() + rw.get() - radarSize[0],
    bh.get() + 0.5 * rh.get() - radarSize[1] * 0.5
  ])

  let twsSize = sh(20)
  let twsPos= Computed(@() [
      bw.get() + 0.02 * rw.get(),
      bh.get() + 0.5 * rh.get() - twsSize * 0.5
    ])

  return @() {
    size = [width, height]
    watch = [IsRangefinderEnabled, mfdCameraSetting, isCollapsedRadarInReplay, radarPos,
      IsMfdEnabled, IsTwsDamaged]
    children = [
      compassElem(baseColor, compassSize, compassPos)
      missileSalvoTimer(baseColor, sw(50) - hdpx(150), sh(90) - hdpx(174))
      turretAngles(baseColor, hdpx(150), hdpx(150), sw(50), sh(90), 0.22, false, turretAnglesStyle)
      reticle(sw(50), sh(50))
      lockSightIndicator
      targetSizeIndicator(baseColor, sw(100), sh(100))
      launchDistanceMax(baseColor, hdpx(150), hdpx(150), sw(50), sh(90))
      laserDesignatorStatusComponent(baseColor, sw(50), sh(35))
      laserDesignatorComponent(baseColor, sw(50), sh(37))
      IsRangefinderEnabled.get() ? rangeFinder(baseColor, sw(50), sh(63.5)) : null
      planeAttitude(baseColor)
      flirIndicator(baseColor)
      !isCollapsedRadarInReplay.get()
        ? radarHud(radarSize[0], radarSize[1], radarPos.get()[0], radarPos.get()[1], baseColor, {}, true): null
      !IsMfdEnabled.get() ? twsElement(IsTwsDamaged.get() ? AlertColorHigh : baseColor, twsPos, twsSize) : null
    ]
  }
}

let sightTableWidthHeli = hdpx(270)
let sightTableHeightHeli = hdpx(28)
let positionParamsSightTable = Watched([hdpx(20), hdpx(20)])

let helicopterSightParamsTable = paramsTable(SightMask, EmptyMask,
  sightTableWidthHeli, sightTableHeightHeli,
  positionParamsSightTable,
  hdpx(3))

let helicopterTargetingPodSight = {
  children = useLegacyLayout ? legacySight.helicopterSight(sw(100), sh(100)) : [
    commonSight(sw(100), sh(100))
    agmLaunchZone(baseColor, sw(100), sh(100))
    helicopterSightParamsTable(baseColor)
    agmTrackZoneComponent(baseColor)
    agmTrackerStatusComponent(baseColor, sw(50), sh(41))
    detectAlly(sw(51), sh(35))
    agmAim(baseColor, AlertColorHigh)
    gunDirection(baseColor, true)
  ]
}

let paramsTableWidthAircraft = hdpx(330)
let paramsTableHeightAircraft = hdpx(22)
let aircraftParamsTablePos = Computed(@() [max(bw.get(), sw(20) - hdpx(660)), max(bh.get(), sh(10) - hdpx(100))])

let aircraftParamsTable = paramsTable(TargetPodMask, EmptyMask,
        paramsTableWidthAircraft, paramsTableHeightAircraft,
        aircraftParamsTablePos,
        hdpx(1), true, false, true)

let aircraftTargetingPodSight = @(width, height) {
  children = useLegacyLayout ? legacySight.aircraftSight(width, height) : [
    commonSight(width, height)
    aircraftParamsTable(baseColor, false)
  ]
}

return {
  aircraftTargetingPodSight
  helicopterTargetingPodSight
}