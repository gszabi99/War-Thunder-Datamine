local interopGet = require("daRg/helpers/interopGen.nut")

local hudState = persist("hudState", @(){
  unitType = Watched("")
  cursorVisible = Watched(false)
  playerArmyForHud = Watched(-1)
  isPlayingReplay = Watched(false)
  isVisibleDmgIndicator = Watched(false)
})


interopGet({
  stateTable = hudState
  prefix = "hud"
  postfix = "Update"
})


return hudState
