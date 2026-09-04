import "DataBlock" as DataBlock
from "console" import register_command
from "%scripts/dagui_library.nut" import *
from "app" import is_dev_version

let showUnlocksGroupWnd = require("%scripts/unlocks/unlockGroupWnd.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { getClanPlaceRewardLogData } = require("%scripts/clans/clanInfo.nut")

function debug_get_clan_blk() {
  let blk = DataBlock()
  blk.load("../prog/scripts/wt/debugData/debugClan.blk")
  return blk
}

function debug_show_all_clan_awards() {
  if (!is_dev_version())
    return
  let clanData = get_clan_info_table(true, debug_get_clan_blk()) 
  let placeAwardsList = getClanPlaceRewardLogData(clanData)
  showUnlocksGroupWnd(placeAwardsList, "debug_show_all_clan_awards")
}

register_command(debug_show_all_clan_awards, "debug.show_all_clan_awards")
