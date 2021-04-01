local radarComponent = require("radarComponent.nut")
local aamAim = require("rocketAamAim.nut")
local agmAim = require("agmAim.nut")
local tws = require("tws.nut")
local {IsMlwsLwsHudVisible} = require("twsState.nut")
local sightIndicators = require("hud/tankSightIndicators.nut")
local activeProtectionSystem = require("reactiveGui/hud/activeProtectionSystem.nut")
local { isVisibleDmgIndicator, dmgIndicatorStates } = require("reactiveGui/hudState.nut")

local greenColor = Color(10, 202, 10, 250)
local redColor = Color(255, 35, 30, 255)
local getColor = @() greenColor

local styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}

local styleLws = {
  color = redColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(1) * 2.0
}

local function Root() {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = [sw(100), sh(100)]
    children = [
      radarComponent.mkRadar()
      aamAim(styleAamAim, getColor)
      agmAim(styleAamAim, getColor)
      sightIndicators(styleAamAim, getColor)
    ]
  }
}


local function tankDmgIndicator() {
  return function() {
    local children = [activeProtectionSystem]
    if (IsMlwsLwsHudVisible.value)
      children.append(tws({
        colorStyle = styleLws,
        pos = [0, 0],
        size = [pw(80), ph(80)],
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
