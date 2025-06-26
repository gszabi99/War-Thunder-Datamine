from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let interopGet = require("interopGen.nut")
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
  missionProgressHeight = 0
  hasTarget = false
  canZoom = false
  isUnitAlive = false
  isInKillerCamera = isInKillerCam()
  playerUnitName = ""
}.map(@(val, key) mkWatched(persist, key, val))

let { isInKillerCamera, isVisibleDmgIndicator } = hudState
let needShowDmgIndicator = Computed(@() isVisibleDmgIndicator.get() && !isInKillerCamera.get())
hudState.needShowDmgIndicator <- needShowDmgIndicator

eventbus_subscribe("updateDmgIndicatorStates", @(v) hudState.dmgIndicatorStates(v))
eventbus_subscribe("updateMissionProgressHeight", @(v) hudState.missionProgressHeight(v))
eventbus_subscribe("updateIsSpectatorMode", @(v) hudState.isSpectatorMode(v))
eventbus_subscribe("hud_gui_state_changed",
  @(_) isInKillerCamera(isInKillerCam()))

interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
