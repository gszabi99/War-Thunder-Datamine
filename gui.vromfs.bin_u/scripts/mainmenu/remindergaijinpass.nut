local reminderGaijinPassModal = require("scripts/mainmenu/reminderGaijinPassModal.nut")

local function checkGaijinPassReminder()
{
  local haveGP = ::g_user_utils.haveTag("GaijinPass")
  local have2Step = ::g_user_utils.haveTag("2step")
  if (!::is_platform_pc || ::steam_is_running() || ::is_me_newbie() || !have2Step || haveGP
    || !::has_feature("CheckGaijinPass")
    || ::load_local_account_settings("skipped_msg/gaijinPassDontShowThisAgain", false))
      return

  local currDays = time.getUtcDays()
  local deltaDaysReminder = currDays - ::load_local_account_settings("gaijinpass/lastDayReminder", 0)
  if (deltaDaysReminder == 0)
    return

  local gmBlk = ::get_game_settings_blk()
  local daysCounter = ::max(gmBlk?.reminderGaijinPassGetting ?? 1,
    ::load_local_account_settings("gaijinpass/daysCounter", 0))
  if (deltaDaysReminder >= daysCounter)
  {
    ::save_local_account_settings("gaijinpass/daysCounter", 2 * daysCounter)
    ::save_local_account_settings("gaijinpass/lastDayReminder", currDays)
    reminderGaijinPassModal.open()
  }
}

return {
  checkGaijinPassReminder = checkGaijinPassReminder
}
