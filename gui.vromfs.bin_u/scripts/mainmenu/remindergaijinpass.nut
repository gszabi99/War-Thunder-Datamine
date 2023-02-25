//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let reminderGaijinPassModal = require("%scripts/mainmenu/reminderGaijinPassModal.nut")
let { havePlayerTag } = require("%scripts/user/userUtils.nut")
let { getUtcDays } = require("%scripts/time.nut")

let function checkGaijinPassReminder() {
  let haveGP = havePlayerTag("GaijinPass")
  let have2Step = havePlayerTag("2step")
  if (!is_platform_pc || ::steam_is_running() || ::is_me_newbie() || !have2Step || haveGP
    || !hasFeature("CheckGaijinPass")
    || ::load_local_account_settings("skipped_msg/gaijinPassDontShowThisAgain", false))
      return

  let currDays = getUtcDays()
  let deltaDaysReminder = currDays - ::load_local_account_settings("gaijinpass/lastDayReminder", 0)
  if (deltaDaysReminder == 0)
    return

  let gmBlk = ::get_game_settings_blk()
  let daysCounter = max(gmBlk?.reminderGaijinPassGetting ?? 1,
    ::load_local_account_settings("gaijinpass/daysCounter", 0))
  if (deltaDaysReminder >= daysCounter) {
    ::save_local_account_settings("gaijinpass/daysCounter", 2 * daysCounter)
    ::save_local_account_settings("gaijinpass/lastDayReminder", currDays)
    reminderGaijinPassModal.open()
  }
}

return {
  checkGaijinPassReminder = checkGaijinPassReminder
}
