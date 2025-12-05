from "%rGui/globals/ui_library.nut" import *

let { isPlayingReplay, isSpectatorMode, unitType } = require("%rGui/hudState.nut")
let { rw, rh } = require("%rGui/style/screenState.nut")
let killMarks = require("%rGui/hud/humanSquad/killMarks.nut")
let { IsMainHudVisible, isParamTableActivated, HudParamColor
} = require("%rGui/airState.nut")
let { xrayIndicator } = require("%rGui/airHudLeftPanel.nut")
let { infantryHudLeftPanel } = require("%rGui/infantryHud.nut")
let { aircraftParamsTableView } = require("%rGui/aircraftHud.nut")
let { helicopterParamsTableView } = require("%rGui/helicopterHud.nut")
let { isHumanAirDrone } = require("%rGui/hudUnitType.nut")

function mkInfantryDroneMainHud() {
  let watch = [IsMainHudVisible, isParamTableActivated, unitType]

  return function() {
    let children = IsMainHudVisible.get()
      ? [
        isParamTableActivated.get()
          ? isHumanAirDrone()
            ? aircraftParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get())
            : helicopterParamsTableView(HudParamColor, isPlayingReplay.get(), isSpectatorMode.get())
          : null
      ]
      : null

    return {
      watch
      children
    }
  }
}

let xRayIndicatorPanel = {
  size = SIZE_TO_CONTENT
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  pos = [0, -shHud(30)]
  children = xrayIndicator
}

return @() {
  watch = [rw, rh]
  size = [rw.get(), rh.get()]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = [
    mkInfantryDroneMainHud()
    killMarks
    infantryHudLeftPanel
    xRayIndicatorPanel
  ]
}