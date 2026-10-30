import "%scripts/rewards/clanRewardsModal.nut" as clanRewardsModal
import "%sqStdLibs/helpers/u.nut" as u
from "%scripts/tasker.nut" import addTask
from "%scripts/clans/clanInfoTable.nut" import get_clan_info_table
from "%scripts/penitentiary/banhammer.nut" import gui_modal_complain
from "%scripts/clans/clanInfo.nut" import getClanPlaceRewardLogData
from "%scripts/dagui_library.nut" import *
from "%globalScripts/clanNativeConsts.nut" import *
from "%scripts/dagui_natives.nut" import clan_request_info

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
    rewards = getClanPlaceRewardLogData(clanData),
    clanId = clanData?.id
  })
}

return freeze({
  openComplainWnd
  requestOpenComplainWnd
  showClanRewardLog
})