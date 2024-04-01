from "%scripts/dagui_library.nut" import *

let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let reminderGaijinPassModal = require("%scripts/mainmenu/reminderGaijinPassModal.nut")
let { havePlayerTag } = require("%scripts/user/profileStates.nut")
let { getUtcDays } = require("%scripts/time.nut")
let { get_game_settings_blk } = require("blkGetters")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { steam_is_running } = require("steam")

function checkGaijinPassReminder() {
  let haveGP = havePlayerTag("GaijinPass")
  let have2Step = havePlayerTag("2step")
  if (!is_platform_pc || steam_is_running() || isMeNewbie() || !have2Step || haveGP
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

return {
  checkGaijinPassReminder = checkGaijinPassReminder
}
