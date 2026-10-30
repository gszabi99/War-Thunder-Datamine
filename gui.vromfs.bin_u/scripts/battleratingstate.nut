from "%scripts/crossModuleEvents.nut" import BATTLE_RATING_CHANGED
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *






let hardPersistWatched = mkHardPersistWatched("battleRatingState")
let brInfoByGamemodeId = hardPersistWatched("brInfoByGamemodeId", {})
let recentBrGameModeId = hardPersistWatched("recentBrGameModeId", "")
let recentBrSourceGameModeId = hardPersistWatched("recentBrSourceGameModeId", null)
let recentBR = Computed(@() brInfoByGamemodeId.get()?[recentBrSourceGameModeId.get()].br ?? 0)
let recentBRData = Computed(@() brInfoByGamemodeId.get()?[recentBrSourceGameModeId.get()].brData)

recentBR.subscribe(@(_) broadcastEvent(BATTLE_RATING_CHANGED))

return freeze({
  brInfoByGamemodeId
  recentBrGameModeId
  recentBrSourceGameModeId
  recentBR
  recentBRData
})
