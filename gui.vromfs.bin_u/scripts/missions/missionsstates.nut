from "%scripts/dagui_library.nut" import *

let matchSearchGm = mkWatched(persist, "matchSearchGm", -1)
let isRemoteMissionVar = mkWatched(persist, "isRemoteMissionVar", false)
let currentCampaignId = mkWatched(persist, "currentCampaignId", null)
let currentCampaignMission = mkWatched(persist, "currentCampaignMission", null)

return {
  matchSearchGm
  isRemoteMissionVar
  currentCampaignId
  currentCampaignMission
}