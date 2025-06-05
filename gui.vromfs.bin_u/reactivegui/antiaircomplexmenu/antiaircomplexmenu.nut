from "%rGui/globals/ui_library.nut" import *
let string = require("string")
let { targets, TargetsTrigger, HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale, DistanceMax, DistanceMin } = require("%rGui/radarState.nut")
let { PI, floor, lerp } = require("%sqstd/math.nut")
let dasVerticalViewIndicator = load_das("%rGui/antiAirComplexMenu/verticalViewIndicator.das")
let dasRadarHud = load_das("%rGui/radar.das")
let { eventbus_subscribe } = require("eventbus")
let { setAllowedControlsMask } = require("controlsMask")
let { playerUnitName, isUnitAlive } = require("%rGui/hudState.nut")
let { isInFlight } = require("%rGui/globalState.nut")
let { radarSwitchToTarget } = require("antiAirComplexMenuControls")

let radarColor = 0xFF00FF00

let verticalViewIndicator = {
  size = [hdpx(480), hdpx(240)]
  pos =  [pw(1), ph(45)]
  rendObj = ROBJ_DAS_CANVAS
  script = dasVerticalViewIndicator
  drawFunc = "draw"
  setupFunc = "setup"
  font = Fonts.hud
  color = radarColor
}

let circularRadar = {
  size = [hdpx(716), hdpx(752)]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  rendObj = ROBJ_DAS_CANVAS
  script = dasRadarHud
  drawFunc = "draw_radar_hud"
  setupFunc = "setup_radar_data"
  font = Fonts.hud
  color = radarColor
  handleClicks = true
}

function createTargetListElement(index, azimuth, distance, height, speed, typeId, fontSize, isDetected = false, onClick = null){
  return {
    size = [flex(), hdpx(27)]
    rendObj = ROBJ_SOLID
    color = isDetected ? 0xAA404040 :0xAA101010
    borderWidth = 0
    flow = FLOW_HORIZONTAL
    gap = hdpx(10)

    behavior = onClick != null ? Behaviors.Button : null
    onClick = onClick

    children = [
      {
        size = [pw(4), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        valign = ALIGN_CENTER
        text = index
      }
      {
        size = [pw(13), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        text = azimuth
      }
      {
        size = [pw(17), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        text = distance
      }
      {
        size = [pw(17), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        text = height
      }
      {
        size = [pw(17), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        text = speed
      }
      {
        size = [flex(), flex()]
        rendObj = ROBJ_TEXT
        fontSize = fontSize
        valign = ALIGN_CENTER
        text = typeId
      }
    ]
  }
}

function createTargetDist(index, hasAzimuthScale, azimuthMin, azimuthRange, hasDistanceScale, distanceMin, distanceMax) {
  let target = targets[index]

  let radToDeg = 180.0 / PI
  let azimuth = (azimuthMin + azimuthRange * target.azimuthRel) * radToDeg
  let azimuthText = hasAzimuthScale ? string.format("%d", floor(azimuth)) : "-"

  let distance = lerp(0.0, 1.0, distanceMin, distanceMax, target.distanceRel)
  let distanceText = hasDistanceScale ? string.format("%.1f", distance) : "-"

  let heightText = string.format("%.1f", target.heightRel * 0.001)

  let speedText = target.radSpeed > -3000.0 ? string.format("%.1f", target.radSpeed) : "-"

  let typeIdText = target.typeId

  local onClick = function() {
    radarSwitchToTarget(target.objectId)
  }
  return createTargetListElement(index, azimuthText, distanceText, heightText, speedText, typeIdText, hdpx(22), target.isDetected, onClick)
}

let targetList = @() {
  watch = [TargetsTrigger, HasAzimuthScale, AzimuthMin, AzimuthRange, HasDistanceScale, DistanceMin, DistanceMax]
  size = flex()
  flow = FLOW_VERTICAL
  gap = hdpx(10)
  children = targets.map(function(t, i) {
    if (t == null)
      throw null
    return createTargetDist(i, HasAzimuthScale.get(), AzimuthMin.get(), AzimuthRange.get(), HasDistanceScale.get(), DistanceMin.get(), DistanceMax.get())
  })
}

let targetListMain = {
  size = [hdpx(480), hdpx(660)]
  pos = [pw(70), ph(5)]
  flow = FLOW_VERTICAL
  gap = hdpx(10)

  children = [
    createTargetListElement("#", loc("hud/AAComplexMenu/azimuth"),
      loc("hud/AAComplexMenu/distance"), loc("hud/AAComplexMenu/height"),
      loc("hud/AAComplexMenu/speed"), loc("hud/AAComplexMenu/type"), hdpx(15)),
    targetList
  ]
}

let aaComplexMenuShownByUnitName = {}
let isAAComplexMenuActive = Watched(false)

function onAAComplexMenuRequest(evt) {
  let { show } = evt
  let pUnitName = playerUnitName.get()

  aaComplexMenuShownByUnitName[pUnitName] <- show

  isAAComplexMenuActive.set(show)

  let controllMask = show ?
      CtrlsInGui.CTRL_IN_AA_COMPLEX_MENU
    | CtrlsInGui.CTRL_ALLOW_FULL
    : CtrlsInGui.CTRL_ALLOW_FULL
  setAllowedControlsMask(controllMask)
}

eventbus_subscribe("on_aa_complex_menu_request", onAAComplexMenuRequest)

isInFlight.subscribe(function(v) {
  if (v)
    return
  onAAComplexMenuRequest({ show = false })
  aaComplexMenuShownByUnitName.clear()
})

playerUnitName.subscribe(function(_) {
  let pUnitName = playerUnitName.get()

  let isShowAAComplexMenu = !!aaComplexMenuShownByUnitName?[pUnitName]
  onAAComplexMenuRequest({ show = isShowAAComplexMenu })
})

isUnitAlive.subscribe(function(v) {
  if (v)
    return
  let pUnitName = playerUnitName.get()
  aaComplexMenuShownByUnitName[pUnitName] <- false
  onAAComplexMenuRequest({ show = false })
})


let aaComplexMenu = {
  size = flex()

  rendObj = ROBJ_SOLID
  color = 0xDD101010

  children = [
    targetListMain,
    circularRadar,
    verticalViewIndicator
  ]
}

return { aaComplexMenu, isAAComplexMenuActive }