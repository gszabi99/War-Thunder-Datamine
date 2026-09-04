import "%rGui/interopGen.nut" as interopGet
from "%rGui/hudSpectatorState.nut" import isSpectatorMode
from "%rGui/hud/hudPartVisibleState.nut" import isDmgPanelVisible
from "%sqstd/underscore.nut" import isEqual
from "gameplayBinding" import isDmgIndicatorVisible
from "eventbus" import eventbus_subscribe
from "hudState" import getHudGuiState, HudGuiState
from "%rGui/globals/ui_library.nut" import *

let isInKillerCam = @() getHudGuiState() == HudGuiState.GUI_STATE_KILLER_CAMERA

let hudState = {
  unitType = ""
  playerArmyForHud = -1
  isPlayingReplay = false
  isVisibleDmgIndicator = isDmgIndicatorVisible()
  tacticalMapStates = { size = const [0, 0], pos = const [0, 0] }
  missionProgressHeight = 0
  hasTarget = false
  canZoom = false
  isUnitAlive = false
  isUnitDelayed = false
  isInKillerCamera = isInKillerCam()
  playerUnitName = ""
  isThermalSightActive = false
  isMissionProgressVisible = false
}.map(@(val, key) mkWatched(persist, key, val))
hudState.isSpectatorMode <- isSpectatorMode

let { isInKillerCamera, isVisibleDmgIndicator } = hudState
let needShowDmgIndicator = Computed(@() isVisibleDmgIndicator.get() && !isInKillerCamera.get() && isDmgPanelVisible.get())
hudState.needShowDmgIndicator <- needShowDmgIndicator

eventbus_subscribe("updateTacticalMapStates", function(v) {
  if (!isEqual(hudState.tacticalMapStates.get(), v))
    hudState.tacticalMapStates.set(v)
})
eventbus_subscribe("updateMissionProgressHeight", @(v) hudState.missionProgressHeight.set(v))
eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera.set(isInKillerCam()))

eventbus_subscribe("hudProgress:visibilityChanged", @(v) hudState.isMissionProgressVisible.set(v.isVisible))

interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})

return hudState