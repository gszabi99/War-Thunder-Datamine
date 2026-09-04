from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent
from "%scripts/dagui_library.nut" import *

let { BATTLE_RATING_CHANGED } = require("%scripts/crossModuleEvents.nut")







let brInfoByGamemodeId = mkWatched(persist, "brInfoByGamemodeId", {})
let recentBrGameModeId = mkWatched(persist, "recentBrGameModeId", "")
let recentBrSourceGameModeId = mkWatched(persist, "recentBrSourceGameModeId", null)
let recentBR = Computed(@() brInfoByGamemodeId.get()?[recentBrSourceGameModeId.get()].br ?? 0)
let recentBRData = Computed(@() brInfoByGamemodeId.get()?[recentBrSourceGameModeId.get()].brData)

recentBR.subscribe(@(_) broadcastEvent(BATTLE_RATING_CHANGED))

return {
  brInfoByGamemodeId
  recentBrGameModeId
  recentBrSourceGameModeId
  recentBR
  recentBRData
}
