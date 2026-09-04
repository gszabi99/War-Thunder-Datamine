
#default:forbid-root-table

import "console" as console
from "%sqStdLibs/helpers/net_errors.nut" import script_net_assert_once
from "%globalScripts/systemConfig.nut" import getSystemConfigOption, setSystemConfigOption
from "%appGlobals/login/loginState.nut" import isAuthorized
from "%globalScripts/clientState/initialState.nut" import shouldDisableMenu
from "%sqstd/platform.nut" import isPC, is_gdk
from "dagor.time" import ref_time_ticks
from "dagor.random" import set_rnd_seed
from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import run_reactive_gui
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "frp" import warn_on_deprecated_methods, set_slow_subscriber_threshold_usec
from "dagor.system" import DBGLEVEL
warn_on_deprecated_methods(DBGLEVEL > 0)
set_slow_subscriber_threshold_usec(1000000) 

clear_vm_entity_systems()
start_es_loading()

require("%scripts/worldWar/worldWarConst.nut")
require("%globalScripts/ui_globals.nut")

let sqdebugger = require_optional("sqdebugger")

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData)

require("%globalScripts/version.nut")
require("%scripts/clientState/errorHandling.nut")


require("%scripts/user/features.nut")

set_rnd_seed(ref_time_ticks())



let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
subscriptions.setDefaultPriority(require("%scripts/g_listener_priority.nut").DEFAULT)

foreach (fn in [
  "%scripts/debugTools/dbgToString.nut"
  "%scripts/sqDagui/framework/framework.nut"
])
  require(fn)

require("%scripts/onScriptLoad.nut")

foreach (fn in [
  "%sqstd/math.nut"

  "%scripts/sqDagui/guiBhv/allBhv.nut"
  "%scripts/onlineShop/urlType.nut"
  "%scripts/onlineShop/url.nut"

  "%scripts/viewUtils/layeredIcon.nut"

  "%scripts/sqDagui/timer/timer.nut"

  "%scripts/options/optionsExtNames.nut"
  "%scripts/options/fonts.nut"
  "%scripts/options/consoleMode.nut"
  "%scripts/options/privacyOptionsManager.nut"

  
  "%scripts/controls/guiSceneCursorVisibility.nut"
  "%scripts/controls/rawShortcuts.nut"
  "%scripts/controls/controlsManager.nut"

  "%scripts/baseGuiHandlerManagerWT.nut"

  "%scripts/langUtils/localization.nut"
  "%scripts/langUtils/language.nut"

  "%scripts/clientState/keyboardState.nut"
  "%scripts/clientState/contentPacks.nut"
  "%scripts/utils/errorMsgBox.nut"
  "%scripts/tasker.nut"

  "%scripts/clientState/fpsDrawer.nut"

  "%scripts/clientState/applyRendererSettingsChange.nut"

  
  "%scripts/controls/input/inputBase.nut"
  "%scripts/controls/input/nullInput.nut"
  "%scripts/controls/shortcutType.nut"
  "%scripts/viewUtils/hints.nut"
  "%scripts/viewUtils/bhvHint.nut"

  "%scripts/loading/loading.nut"

  "%scripts/loading/bhvLoadingTip.nut"
  "%scripts/options/countryFlagsPreset.nut"

  "%scripts/webRPC.nut"

  "%scripts/actionsList.nut"
  "%scripts/eulaWnd.nut"
  "%scripts/controls/input/button.nut"
  
  "%scripts/social/xboxSquadManager/xboxSquadManager.nut"

  
  "%scripts/onlineShop/browserWnd.nut"
]) {
  require(fn)
}

  
require("%scripts/matching/matchingGameSettings.nut")
require("%scripts/sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(script_net_assert_once)
require("%scripts/clientState/elems/dlDataStatElem.nut")
require("%scripts/clientState/elems/copyrightText.nut")
require("%scripts/sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")
require("%scripts/options/bhvHarmonizedImage.nut")
require("%scripts/hangar/initHangar.nut")

  
require("%scripts/debugTools/dbgAvatarsList.nut")
require("%scripts/debugTools/dbgFonts.nut")
require("%scripts/debugTools/dbgUtils.nut")
require("%scripts/debugTools/dbgCrewLock.nut")
require("%scripts/debugTools/dbgDedicLogerrs.nut")
require("%sqstd/regScriptProfiler.nut")("dagui", dlog) 
require("%scripts/wndLib/qrWindow.nut") 

  

end_es_loading()

if (is_gdk) {
  require("%scripts/gdk/onLoad.nut")
}






if (isPC && getSystemConfigOption("debug/netLogerr") == null)
  setSystemConfigOption("debug/netLogerr", true)

let { loadScriptsAfterLoginOnce } = require("%scripts/loadScriptsAfterLogin.nut")
let isLoadedOnce = keepref(mkWatched(persist, "isLoadedOnce", false))
if (isAuthorized.get() || shouldDisableMenu) { 
  loadScriptsAfterLoginOnce()
  if (!isLoadedOnce.get()) {
    isLoadedOnce.set(true)
    run_reactive_gui()
  }
}


