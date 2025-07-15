from "%scripts/dagui_natives.nut" import char_send_clan_oneway_blk, clan_request_info
from "%scripts/dagui_library.nut" import *

let { addTask } = require("%scripts/tasker.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let clanRewardsModal = require("%scripts/rewards/clanRewardsModal.nut")
let { get_clan_info_table } = require("%scripts/clans/clanInfoTable.nut")
let { gui_modal_complain } = require("%scripts/penitentiary/banhammer.nut")
let { tribunal } = require("%scripts/penitentiary/tribunal.nut")

function openComplainWnd(clanData) {
  local leader = u.search(clanData.members, @(member) member.role == ECMR_LEADER)
  if (leader == null)
    leader = clanData.members[0]
  gui_modal_complain({ name = leader.nick, userId = leader.uid, clanData = clanData })
}

function requestOpenComplainWnd(clanId) {
  if (!tribunal.canComplaint())
    return

  let taskId = clan_request_info(clanId, "", "")
  let onSuccess = function() {
    let clanData = get_clan_info_table(true)
    openComplainWnd(clanData)
  }

  addTask(taskId, { showProgressBox = true }, onSuccess)
}

function showClanRewardLog(clanData) {
  clanRewardsModal.open({
    rewards = ::g_clans.getClanPlaceRewardLogData(clanData),
    clanId = clanData?.id
  })
}

return {
  openComplainWnd
  requestOpenComplainWnd
  showClanRewardLog
}