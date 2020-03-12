local startMissionInsteadOfQueue = null
/* Debug sample
  startMissionInsteadOfQueue = {
    name = "guadalcanal_night_fight"
    //isBotsAllowed = true
  }
*/

local updateStartMissionInsteadOfQueue = function()
{
  local rBlk = ::get_ranks_blk()

  local mInfo = rBlk?.custom_single_mission
  if (mInfo?.name == null)
    startMissionInsteadOfQueue = null
  else
  {
    startMissionInsteadOfQueue = {}
    foreach(name, val in mInfo)
      startMissionInsteadOfQueue[name] <- val
  }
}
updateStartMissionInsteadOfQueue()

return startMissionInsteadOfQueue