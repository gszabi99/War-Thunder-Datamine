local interopGet = require("interopGen.nut")

local hudState = persist("hudState", @(){
  unitType = Watched("")
  cursorVisible = Watched(false)
  playerArmyForHud = Watched(-1)
  isPlayingReplay = Watched(false)
  isVisibleDmgIndicator = Watched(false)
  dmgIndicatorStates = Watched({ size = [0, 0], pos = [0, 0]})
})


interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
