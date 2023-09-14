//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { get_ranks_blk } = require("blkGetters")

local startMissionInsteadOfQueue = null
/* Debug sample
  startMissionInsteadOfQueue = {
    name = "guadalcanal_night_fight"
    //isBotsAllowed = true
  }
*/

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