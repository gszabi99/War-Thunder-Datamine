let interopGet = require("interopGen.nut")
let { isDmgIndicatorVisible } = ::require_native("gameplayBinding")

let hudState = persist("hudState", @(){
  unitType = Watched("")
  playerArmyForHud = Watched(-1)
  isPlayingReplay = Watched(false)
  isVisibleDmgIndicator = Watched(isDmgIndicatorVisible())
  dmgIndicatorStates = Watched({ size = [0, 0], pos = [0, 0], padding = [0, 0, 0, 0]})
  hasTarget = Watched(false)
  canZoom = Watched(false)
})


interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
