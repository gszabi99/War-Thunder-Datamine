import "%rGui/hud/humanSquad/killMarks.nut" as killMarks
from "%rGui/hudState.nut" import isPlayingReplay, isSpectatorMode, unitType, isUnitAlive
from "%rGui/style/screenState.nut" import rw, rh
from "%rGui/airState.nut" import IsMainHudVisible, isParamTableActivated, HudParamColor, HasFPVCamera, IsSightHudVisible, IsPilotHudVisible
from "%rGui/airHudLeftPanel.nut" import xrayIndicator
from "%rGui/aircraftHud.nut" import aircraftParamsTableView
from "%rGui/helicopterHud.nut" import helicopterParamsTableView
from "%rGui/hudUnitType.nut" import isHumanAirDrone
from "%rGui/utils/builders.nut" import createScriptComponent
from "%rGui/globals/ui_library.nut" import *

let { infantryHudLeftPanel } = require("%rGui/infantryHud.nut")

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

let droneHud = createScriptComponent("%rGui/planeCockpit/infantryFpvDrone.das")
let droneReconHud = createScriptComponent("%rGui/planeCockpit/infantryFpvDroneRecon.das")

let xRayIndicatorPanel = {
  size = SIZE_TO_CONTENT
  hplace = ALIGN_RIGHT
  vplace = ALIGN_BOTTOM
  pos = [0, -shHud(30)]
  children = xrayIndicator
}

return @() {
  watch = [rw, rh, HasFPVCamera, isUnitAlive, IsSightHudVisible, IsPilotHudVisible]
  size = [rw.get(), rh.get()]
  hplace = ALIGN_CENTER
  vplace = ALIGN_CENTER
  children = IsSightHudVisible.get() ? [
    droneReconHud(rw.get(), rh.get())
  ] : IsPilotHudVisible.get() && isUnitAlive.get() ? [
    droneHud(rw.get(), rh.get())
  ] : [
    mkInfantryDroneMainHud()
    killMarks
    infantryHudLeftPanel
    xRayIndicatorPanel
    HasFPVCamera.get() && isUnitAlive.get() ? droneHud(rw.get(), rh.get()) : null
  ]
}