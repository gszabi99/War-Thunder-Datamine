from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import COLOR_TAG
from "ecs" import start_es_loading, end_es_loading
let { is_gdk, isSony, isPS5 } = require("%sqstd/platform.nut")
let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")

let colorTagToColors = {
  [COLOR_TAG.ACTIVE] = "activeTextColor",
  [COLOR_TAG.USERLOG] = "userlogColoredText",
  [COLOR_TAG.TEAM_BLUE] = "teamBlueColor",
  [COLOR_TAG.TEAM_RED] = "teamRedColor",
}

local isFullScriptsLoaded = false
function loadScriptsAfterLoginOnce() {
  if (isFullScriptsLoaded)
    return
  isFullScriptsLoaded = true
  start_es_loading()
  
  require("%scripts/baseGuiHandlerWT.nut")
  

  require("%scripts/onScriptLoadAfterLogin.nut")

  
  require("%scripts/social/playerInfoUpdater.nut")
  require("%scripts/squads/elems/voiceChatElem.nut")
  require("%scripts/matching/serviceNotifications/showInfo.nut")
  require("%scripts/unit/unitContextMenu.nut")
  require("%sqDagui/guiBhv/bhvUpdateByWatched.nut").setAssertFunction(script_net_assert_once)
  require("%scripts/social/activityFeed/activityFeedModule.nut")
  require("%scripts/controls/controlsPseudoAxes.nut")
  require("%scripts/utils/delayedTooltip.nut")
  require("%scripts/slotbar/elems/remainingTimeUnitElem.nut")
  require("%scripts/bhvHangarControlTracking.nut")
  require("%scripts/hangar/hangarEvent.nut")
  require("%scripts/dirtyWordsFilter.nut").continueInitAfterLogin()
  require("%scripts/debugTools/dbgImage.nut")

  if (is_gdk)
    require("%scripts/global/xboxCallbacks.nut")

  if (isSony) {
    require("%scripts/global/psnCallbacks.nut")
    require("%scripts/social/psnSessionManager/loadPsnSessionManager.nut")
    require("%scripts/social/psnMatches.nut").enableMatchesReporting()
  }

  if (isPS5) {
    require("%scripts/user/psnFeatures.nut").enablePremiumFeatureReporting()
    require("%scripts/gameModes/enablePsnActivitiesGameIntents.nut")
  }

  require("%scripts/contacts/steamContactManager.nut")
  

  require("%scripts/utils/systemMsg.nut").registerColors(colorTagToColors)
  end_es_loading()
}

return {
  loadScriptsAfterLoginOnce
}
