from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { register_command } = require("console")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")

let function debug_get_clan_blk() {
  let blk = ::DataBlock()
  blk.load("../prog/scripts/wt/debugData/debugClan.blk")
  return blk
}

let function debug_show_all_clan_awards() {
  if (!::is_dev_version)
    return
  let clanData = ::get_clan_info_table(debug_get_clan_blk())
  let placeAwardsList = ::g_clans.getClanPlaceRewardLogData(clanData)
  showUnlocksGroupWnd(placeAwardsList, "debug_show_all_clan_awards")
}

register_command(debug_show_all_clan_awards, "debug.show_all_clan_awards")
