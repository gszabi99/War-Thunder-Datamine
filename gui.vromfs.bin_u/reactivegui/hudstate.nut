local interopGet = require("interopGen.nut")
local { isDmgIndicatorVisible } = ::require_native("gameplayBinding")

local hudState = persist("hudState", @(){
  unitType = Watched("")
  playerArmyForHud = Watched(-1)
  isPlayingReplay = Watched(false)
  isVisibleDmgIndicator = Watched(isDmgIndicatorVisible())
  dmgIndicatorStates = Watched({ size = [0, 0], pos = [0, 0], padding = [0, 0, 0, 0]})
})


interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
