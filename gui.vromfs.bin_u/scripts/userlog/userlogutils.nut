//checked for plus_string
from "%scripts/dagui_natives.nut" import save_online_single_job, disable_user_log_entry, disable_user_log_entry_by_id
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let antiCheat = require("%scripts/penitentiary/antiCheat.nut")
let { isCrossPlayEnabled } = require("%scripts/social/crossplay.nut")
let DataBlockAdapter = require("%scripts/dataBlockAdapter.nut")
let { isArray } = require("%sqstd/underscore.nut")
let { isInMenu } = require("%scripts/baseGuiHandlerManagerWT.nut")

let saveOnlineJob = @() save_online_single_job(223) //super secure digit for job tag :)

let function disableSeenUserlogs(idsList) {
  if (u.isEmpty(idsList))
    return

  local needSave = false
  foreach (id in idsList) {
    if (!id)
      continue

    let disableFunc = u.isString(id) ? ::disable_user_log_entry_by_id : disable_user_log_entry
    if (disableFunc(id)) {
      needSave = true
      u.appendOnce(id, ::shown_userlog_notifications)
    }
  }

  if (needSave) {
    log("Userlog: Disable seen logs: save online")
    saveOnlineJob()
  }
}


let actionByLogType = {
  [EULT_PUNLOCK_ACCEPT]       = @(_log) ::gui_start_battle_tasks_wnd(),
  [EULT_PUNLOCK_EXPIRED]      = @(_log) ::gui_start_battle_tasks_wnd(),
  [EULT_PUNLOCK_CANCELED]     = @(_log) ::gui_start_battle_tasks_wnd(),
  [EULT_PUNLOCK_NEW_PROPOSAL] = @(_log) ::gui_start_battle_tasks_wnd(),
  [EULT_PUNLOCK_ACCEPT_MULTI] = @(_log) ::gui_start_battle_tasks_wnd(),
  [EULT_INVITE_TO_TOURNAMENT] = function (logObj) {
    let battleId = logObj?.battleId
    if (battleId == null)
      return

    if (!isInMenu())
      return ::g_invites.showLeaveSessionFirstPopup()

    if (!antiCheat.showMsgboxIfEacInactive({ enableEAC = true }))
      return

    if (!isCrossPlayEnabled())
      return ::g_popups.add(null, colorize("warningTextColor", loc("xbox/crossPlayRequired")))

    log($"join to tournament battle with id {battleId}")
    get_cur_gui_scene().performDelayed({}, @() ::SessionLobby.joinBattle(logObj.battleId))
  }
}

let function getTournamentRewardData(logObj) {
  let res = []

  if (!logObj?.rewardTS)
    return []

  foreach (_idx, block in logObj.rewardTS) {
    let result = clone block

    result.type <- "TournamentReward"
    result.eventId <- logObj.name
    result.reason <- block?.awardType ?? ""
    let reasonNum = block?.fieldValue ?? 0
    result.reasonNum <- reasonNum
    result.value <- reasonNum
    result[block?.fieldName ?? result.reason] <- reasonNum

    res.append(DataBlockAdapter(result))
  }

  return res
}

let function getBattleRewardDetails(reward) {
  let toArray = @(v) isArray(v) ? v : [v]
  let rewards = isArray(reward) ? reward.map(@(v) v?.event ? v.event : v)
    : toArray(reward?.event ?? reward?.unit ?? [])

  return rewards.filter(@(r) !!r?.expNoBonus || !!r?.wpNoBonus || !!r?.exp)
}

return {
  disableSeenUserlogs
  actionByLogType
  saveOnlineJob
  getTournamentRewardData
  getBattleRewardDetails
}