local { mkRadar} = require("radarComponent.nut")
local aamAim = require("rocketAamAim.nut")
local agmAim = require("agmAim.nut")
local tws = require("tws.nut")
local {IsMlwsLwsHudVisible} = require("twsState.nut")
local sightIndicators = require("hud/tankSightIndicators.nut")
local activeProtectionSystem = require("reactiveGui/hud/activeProtectionSystem.nut")
local { isVisibleDmgIndicator, dmgIndicatorStates } = require("reactiveGui/hudState.nut")
local { IndicatorsVisible } = require("reactiveGui/hud/tankState.nut")
local { lockSight, targetSize } = require("reactiveGui/hud/targetTracker.nut")
local { bw, bh, rw, rh } = require("style/screenState.nut")

local greenColor = Color(10, 202, 10, 250)
local redColor = Color(255, 35, 30, 255)

local styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

local radarPosComputed = Computed(@() [bw.value + 0.06 * rw.value, bh.value + 0.03 * rh.value])

local function Root() {
  local colorWacthed = Watched(greenColor)
  local colorAlertWatched = Watched(redColor)
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


local function tankDmgIndicator() {
  return function() {
    local colorWacthed = Watched(greenColor)
    local children = [activeProtectionSystem]
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
