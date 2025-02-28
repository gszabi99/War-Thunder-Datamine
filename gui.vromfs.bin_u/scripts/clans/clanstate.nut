from "%scripts/dagui_natives.nut" import clan_get_my_clan_id
from "%scripts/dagui_library.nut" import *

const MY_CLAN_UPDATE_DELAY_MSEC = -60000

let lastUpdateMyClanTime = mkWatched(persist, "lastUpdateMyClanTime", MY_CLAN_UPDATE_DELAY_MSEC)
let myClanInfo = mkWatched(persist, "myClanInfo", null)

let is_in_clan = @() clan_get_my_clan_id() != "-1"

function is_in_my_clan(name = null, uid = null) {
  let myClanInfoV = myClanInfo.get()
  if (myClanInfoV == null)
    return false
  if ("members" not in myClanInfoV)
    return false

  foreach (_i, block in myClanInfoV.members) {
    if (name)
      if (name == block.nick)
        return true
    if (uid)
      if (uid == block.uid)
        return true
  }
  return false
}

return {
  MY_CLAN_UPDATE_DELAY_MSEC
  lastUpdateMyClanTime
  is_in_clan
  is_in_my_clan
  myClanInfo
}