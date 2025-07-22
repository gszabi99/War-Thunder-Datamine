from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let { register_command } = require("console")
let DataBlock  = require("DataBlock")
let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")

function debug_get_clan_blk() {
  let blk = DataBlock()
  blk.load("../prog/scripts/wt/debugData/debugClan.blk")
  return blk
}

function debug_show_all_clan_awards() {
  if (!is_dev_version())
    return
  let clanData = get_clan_info_table(true, debug_get_clan_blk()) 
  let placeAwardsList = ::g_clans.getClanPlaceRewardLogData(clanData)
  showUnlocksGroupWnd(placeAwardsList, "debug_show_all_clan_awards")
}

register_command(debug_show_all_clan_awards, "debug.show_all_clan_awards")
