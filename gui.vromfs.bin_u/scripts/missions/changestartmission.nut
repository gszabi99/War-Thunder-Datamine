from "%scripts/dagui_library.nut" import *
let { get_ranks_blk } = require("blkGetters")

local startMissionInsteadOfQueue = null







let updateStartMissionInsteadOfQueue = function() {
  let rBlk = get_ranks_blk()

  let mInfo = rBlk?.custom_single_mission
  if (mInfo?.name == null)
    startMissionInsteadOfQueue = null
  else {
    startMissionInsteadOfQueue = {}
    foreach (name, val in mInfo)
      startMissionInsteadOfQueue[name] <- val
  }
}
updateStartMissionInsteadOfQueue()

return startMissionInsteadOfQueue