from "%rGui/globals/ui_library.nut" import *

let cross_call = require("%rGui/globals/cross_call.nut")
let interopGet = require("interopGen.nut")
let { isDmgIndicatorVisible } = require("gameplayBinding")
let { subscribe } = require("eventbus")

let hudState = persist("hudState", @() {
  unitType = Watched("")
  playerArmyForHud = Watched(-1)
  isSpectatorMode = Watched(cross_call.isPlayerDedicatedSpectator())
  isPlayingReplay = Watched(false)
  isVisibleDmgIndicator = Watched(isDmgIndicatorVisible())
  dmgIndicatorStates = Watched({ size = [0, 0], pos = [0, 0] })
  missionProgressHeight = Watched(0)
  hasTarget = Watched(false)
  canZoom = Watched(false)
})

subscribe("updateDmgIndicatorStates", @(v) hudState.dmgIndicatorStates(v))
subscribe("updateMissionProgressHeight", @(v) hudState.missionProgressHeight(v))
subscribe("updateIsSpectatorMode", @(v) hudState.isSpectatorMode(v))

interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
