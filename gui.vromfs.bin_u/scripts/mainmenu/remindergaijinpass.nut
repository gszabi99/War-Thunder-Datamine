import "%scripts/mainmenu/reminderGaijinPassModal.nut" as reminderGaijinPassModal
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings, loadLocalAccountSettings
from "%scripts/user/profileStates.nut" import havePlayerTag
from "%scripts/time.nut" import getUtcDays
from "%scripts/myStats.nut" import isMeNewbie
from "%sqstd/platform.nut" import isPC
from "blkGetters" import get_game_settings_blk
from "steam" import steam_is_running
from "%scripts/dagui_library.nut" import *

function checkGaijinPassReminder() {
  let haveGP = havePlayerTag("GaijinPass")
  let have2Step = havePlayerTag("2step")
  if (!isPC || steam_is_running() || isMeNewbie() || !have2Step || haveGP
    || !hasFeature("CheckGaijinPass")
    || loadLocalAccountSettings("skipped_msg/gaijinPassDontShowThisAgain", false))
      return

  let currDays = getUtcDays()
  let deltaDaysReminder = currDays - loadLocalAccountSettings("gaijinpass/lastDayReminder", 0)
  if (deltaDaysReminder == 0)
    return

  let gmBlk = get_game_settings_blk()
  let daysCounter = max(gmBlk?.reminderGaijinPassGetting ?? 1,
    loadLocalAccountSettings("gaijinpass/daysCounter", 0))
  if (deltaDaysReminder >= daysCounter) {
    saveLocalAccountSettings("gaijinpass/daysCounter", 2 * daysCounter)
    saveLocalAccountSettings("gaijinpass/lastDayReminder", currDays)
    reminderGaijinPassModal.open()
  }
}

return freeze({
  checkGaijinPassReminder = checkGaijinPassReminder
})
