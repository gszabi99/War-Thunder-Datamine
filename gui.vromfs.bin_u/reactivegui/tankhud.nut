let { mkRadar} = require("radarComponent.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let tws = require("tws.nut")
let {IsMlwsLwsHudVisible} = require("twsState.nut")
let sightIndicators = require("hud/tankSightIndicators.nut")
let activeProtectionSystem = require("reactiveGui/hud/activeProtectionSystem.nut")
let { isVisibleDmgIndicator, dmgIndicatorStates } = require("reactiveGui/hudState.nut")
let { IndicatorsVisible } = require("reactiveGui/hud/tankState.nut")
let { lockSight, targetSize } = require("reactiveGui/hud/targetTracker.nut")
let { bw, bh, rw, rh } = require("style/screenState.nut")

let greenColor = Color(10, 202, 10, 250)
let redColor = Color(255, 35, 30, 255)

let styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

let radarPosComputed = Computed(@() [bw.value + 0.06 * rw.value, bh.value + 0.03 * rh.value])

let function Root() {
  let colorWacthed = Watched(greenColor)
  let colorAlertWatched = Watched(redColor)
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    watch = IndicatorsVisible
    size = [sw(100), sh(100)]
    children = [
      mkRadar(radarPosComputed)
      aamAim(false, colorWacthed, colorAlertWatched)
      agmAim(false, colorWacthed)
      IndicatorsVisible.value
        ? @() {
            children = [
              sightIndicators(styleAamAim, colorWacthed)
              lockSight(colorWacthed, hdpx(150), hdpx(100), sw(50), sh(50))
              targetSize(colorWacthed, sw(100), sh(100), false)
            ]
          }
        : null
    ]
  }
}


let function tankDmgIndicator() {
  return function() {
    let colorWacthed = Watched(greenColor)
    let children = [activeProtectionSystem]
    if (IsMlwsLwsHudVisible.value)
      children.append(tws({
        colorWatched = colorWacthed,
        posWatched = Watched([0, 0]),
        sizeWatched = Watched([pw(80), ph(80)]),
        relativCircleSize = 49,
        needDrawCentralIcon = false
      }))
    return {
      size = dmgIndicatorStates.value.size
      pos = dmgIndicatorStates.value.pos
      halign = ALIGN_CENTER
      valign = ALIGN_CENTER
      watch = [ isVisibleDmgIndicator, IsMlwsLwsHudVisible, dmgIndicatorStates ]
      children = isVisibleDmgIndicator.value ? children : null
    }
  }
}


return {
  Root
  tankDmgIndicator
}
