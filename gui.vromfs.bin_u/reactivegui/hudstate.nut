from "%rGui/globals/ui_library.nut" import *

let { isEqual } = require("%sqstd/underscore.nut")
let cross_call = require("%rGui/globals/cross_call.nut")
let interopGet = require("%rGui/interopGen.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let { eventbus_subscribe } = require("eventbus")
let { getHudGuiState, HudGuiState } = require("hudState")

let isInKillerCam = @() getHudGuiState() == HudGuiState.GUI_STATE_KILLER_CAMERA

let hudState = {
  unitType = ""
  playerArmyForHud = -1
  isSpectatorMode = cross_call.isPlayerDedicatedSpectator()
  isPlayingReplay = false
  isVisibleDmgIndicator = isDmgIndicatorVisible()
  dmgIndicatorStates = { size = [0, 0], pos = [0, 0] }
  tacticalMapStates = { size = [0, 0], pos = [0, 0] }
  missionProgressHeight = 0
  hasTarget = false
  canZoom = false
  isUnitAlive = false
  isUnitDelayed = false
  isInKillerCamera = isInKillerCam()
  playerUnitName = ""
  isThermalSightActive = false
}.map(@(val, key) mkWatched(persist, key, val))

let { isInKillerCamera, isVisibleDmgIndicator } = hudState
let needShowDmgIndicator = Computed(@() isVisibleDmgIndicator.get() && !isInKillerCamera.get())
hudState.needShowDmgIndicator <- needShowDmgIndicator

eventbus_subscribe("updateDmgIndicatorStates", function(v) {
  if (!isEqual(hudState.dmgIndicatorStates.get(), v))
    hudState.dmgIndicatorStates.set(v)
})
eventbus_subscribe("updateTacticalMapStates", function(v) {
  if (!isEqual(hudState.tacticalMapStates.get(), v))
    hudState.tacticalMapStates.set(v)
})
eventbus_subscribe("updateMissionProgressHeight", @(v) hudState.missionProgressHeight.set(v))
eventbus_subscribe("updateIsSpectatorMode", @(v) hudState.isSpectatorMode.set(v))
eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera.set(isInKillerCam()))

interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
