import "DataBlock" as DataBlock
from "%scripts/user/showcase/showcaseValues.nut" import defaultShowcaseType
from "%scripts/dagui_library.nut" import *

let favoriteShowcase = {
  lines = [
    ["battles", "victories", "respawns"],
    ["playerVehicleDestroys", "aiVehicleDestroys", "totalScore"]
  ]
  blockedGameTypes = ["arcade", "historical", "simulation"]
  scorePeriod = "value_total"
  hasGameMode = true
  getShowCaseType = @(terseInfo, params = null)
    terseInfo?.showcase.mode ?? (params?.skipDefault ? null : defaultShowcaseType)
  terseName = "favorite_mode"
  locName = "showcase/favorite_mode"
  writeGameMode = @(terseInfo, mode) terseInfo.showcase.mode <- mode
  getSaveData = function(terseInfo) {
    let data = DataBlock()
    data.showcaseType <- "favorite_mode"
    data.favoriteMode <- terseInfo.showcase.mode
    return data
  }
}

return {
  favoriteShowcase
}