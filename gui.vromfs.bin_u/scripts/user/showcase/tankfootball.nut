from "%scripts/dagui_library.nut" import *

let { defaultShowcaseType } = require("%scripts/user/showcase/showcaseValues.nut")
let { getConditionsToUnlockShowcaseById } = require("%scripts/unlocks/unlocksViewModule.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")

let DataBlock = require("DataBlock")

let tankFootballer = {
  lines = [
    ["football_goals", "football_passes", "football_saves"],
    ["football_wins", "football_matches"]
  ]
  hasGameMode = false
  getShowCaseType = @(terseInfo, params = null)
    terseInfo?.showcase.mode ?? (params?.skipDefault ? null : defaultShowcaseType)
  terseName = "tank_footballer"
  locName = "tank_footballer/name"
  titleIcon = "#ui/gameuiskin#ic_soccer_ball.svg"
  hasOnlySecondTitle = true
  hasSecondTitleInEditMode = true
  getSecondTitle = @(_terseInfo) loc("tank_footballer/name")
  isDisabled = @() !isUnlockOpened("tank_footballer")
  hintForDisabled = @() "{\"id\":\"tank_footballer\",\"ttype\":\"UNLOCK_SHORT\"}"
  textForDisabled = @() getConditionsToUnlockShowcaseById("tank_footballer")
  getSaveData = function(_terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "tank_footballer"
    return data
  }
}

return {
  tankFootballer
}