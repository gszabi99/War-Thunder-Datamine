local u = require("sqStdLibs/helpers/u.nut")
local antiCheat = require("scripts/penitentiary/antiCheat.nut")
local { isCrossPlayEnabled } = require("scripts/social/crossplay.nut")

local saveOnlineJob = @() ::save_online_single_job(223) //super secure digit for job tag :)

local function disableSeenUserlogs(idsList) {
  if (u.isEmpty(idsList))
    return

  local needSave = false
  foreach (id in idsList) {
    if (!id)
      continue

    local disableFunc = u.isString(id) ? ::disable_user_log_entry_by_id : ::disable_user_log_entry
    if (disableFunc(id))
    {
      needSave = true
      u.appendOnce(id, ::shown_userlog_notifications)
    }
  }

  if (needSave)
  {
    ::dagor.debug("Userlog: Disable seen logs: save online")
    saveOnlineJob()
  }
}


local actionByLogType = {
  [::EULT_PUNLOCK_ACCEPT]       = @(log) ::gui_start_battle_tasks_wnd(),
  [::EULT_PUNLOCK_EXPIRED]      = @(log) ::gui_start_battle_tasks_wnd(),
  [::EULT_PUNLOCK_CANCELED]     = @(log) ::gui_start_battle_tasks_wnd(),
  [::EULT_PUNLOCK_NEW_PROPOSAL] = @(log) ::gui_start_battle_tasks_wnd(),
  [::EULT_PUNLOCK_ACCEPT_MULTI] = @(log) ::gui_start_battle_tasks_wnd(),
  [::EULT_INVITE_TO_TOURNAMENT] = function (log)
  {
    local battleId = log?.battleId
    if (battleId == null)
      return

    if (!::isInMenu())
      return ::g_invites.showLeaveSessionFirstPopup()

    if (!antiCheat.showMsgboxIfEacInactive({enableEAC = true}))
      return

    if (!isCrossPlayEnabled())
      return ::g_popups.add(null, ::colorize("warningTextColor", ::loc("xbox/crossPlayRequired")))

    ::dagor.debug($"join to tournament battle with id {battleId}")
    ::get_cur_gui_scene().performDelayed({}, @() ::SessionLobby.joinBattle(log.battleId))
  }
}

local function getTournamentRewardData(log) {
  local res = []

  if (!log?.rewardTS)
    return []

  foreach(idx, block in log.rewardTS)
  {
    local result = clone block

    result.type <- "TournamentReward"
    result.eventId <- log.name
    result.reason <- block?.awardType ?? ""
    local reasonNum = block?.fieldValue ?? 0
    result.reasonNum <- reasonNum
    result.value <- reasonNum
    result[block?.fieldName ?? result.reason] <- reasonNum

    res.append(::DataBlockAdapter(result))
  }

  return res
}

return {
  disableSeenUserlogs
  actionByLogType
  saveOnlineJob
  getTournamentRewardData
}