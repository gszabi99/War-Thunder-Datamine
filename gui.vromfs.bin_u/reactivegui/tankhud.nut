from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let { mkRadar } = require("radarComponent.nut")
let aamAim = require("rocketAamAim.nut")
let agmAim = require("agmAim.nut")
let tankGunsAmmo = require("hud/tankGunsAmmo.nut")
let tws = require("tws.nut")
let { IsMlwsLwsHudVisible } = require("twsState.nut")
let sightIndicators = require("hud/tankSightIndicators.nut")
let activeProtectionSystem = require("%rGui/hud/activeProtectionSystem.nut")
let { isVisibleDmgIndicator, dmgIndicatorStates } = require("%rGui/hudState.nut")
let { IndicatorsVisible } = require("%rGui/hud/tankState.nut")
let { lockSight, targetSize } = require("%rGui/hud/targetTracker.nut")
let { bw, bh } = require("style/screenState.nut")
//



let greenColor = Color(10, 202, 10, 250)
let redColor = Color(255, 35, 30, 255)

let styleAamAim = {
  color = greenColor
  fillColor = Color(0, 0, 0, 0)
  lineWidth = hdpx(2.0)
}

let radarPosComputed = Computed(@() [bw.value, bh.value])

let tankXrayIndicator = @() {
  rendObj = ROBJ_XRAYDOLL
  rotateWithCamera = true
  size = [pw(62), ph(62)]
  behavior = Behaviors.RecalcHandler
  function onRecalcLayout(_initial, elem) {
    if (elem.getWidth() > 1 && elem.getHeight() > 1) {
      cross_call.update_damage_panel_state({
        pos = [elem.getScreenPosX(), elem.getScreenPosY()]
        size = [elem.getWidth(), elem.getHeight()]
        visible = true
      })
    }
  }
}

let xraydoll = {
  rendObj = ROBJ_XRAYDOLL     ///Need add ROBJ_XRAYDOLL in scene for correct update isVisibleDmgIndicator state
  size = [1, 1]
}

let function tankDmgIndicator() {
  if (!isVisibleDmgIndicator.value)
    return {
      watch = isVisibleDmgIndicator
      children = xraydoll
    }

  let colorWacthed = Watched(greenColor)
  let children = [
    tankXrayIndicator,
    activeProtectionSystem,
    //


  ]
  if (IsMlwsLwsHudVisible.value)
    children.append(tws({
      colorWatched = colorWacthed,
      posWatched = Watched([0, 0]),
      sizeWatched = Watched([pw(80), ph(80)]),
      relativCircleSize = 49,
      needDrawCentralIcon = false
    }))
  return {
    rendObj = ROBJ_IMAGE
    watch = [ IsMlwsLwsHudVisible, isVisibleDmgIndicator, dmgIndicatorStates ]
    pos = dmgIndicatorStates.value?.pos ?? [0, 0]
    size = dmgIndicatorStates.value.size
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    image = Picture($"ui/gameuiskin/bg_dmg_board.svg:{dmgIndicatorStates.value.size[0]}:{dmgIndicatorStates.value.size[1]}")
    children
  }
}

let function Root() {
  let colorWacthed = Watched(greenColor)
  let colorAlertWatched = Watched(redColor)
  let isTankGunsAmmoVisible = cross_call.isVisibleTankGunsAmmoIndicator()

  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    watch = IndicatorsVisible
    size = [sw(100), sh(100)]
    children = [
      mkRadar(radarPosComputed)
      aamAim(colorWacthed, colorAlertWatched)
      agmAim(colorWacthed)
      tankDmgIndicator
      isTankGunsAmmoVisible ? tankGunsAmmo : null
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

return Root