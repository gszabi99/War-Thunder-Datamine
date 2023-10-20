from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let interopGet = require("interopGen.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let { subscribe } = require("eventbus")

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
}.map(@(val, key) mkWatched(persist, key, val))

subscribe("updateDmgIndicatorStates", @(v) hudState.dmgIndicatorStates(v))
subscribe("updateMissionProgressHeight", @(v) hudState.missionProgressHeight(v))
subscribe("updateIsSpectatorMode", @(v) hudState.isSpectatorMode(v))

interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
