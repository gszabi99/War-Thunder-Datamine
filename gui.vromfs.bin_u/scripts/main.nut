from "%scripts/dagui_library.nut" import *
from "%sqDagui/daguiNativeApi.nut" import DaGuiObject
from "%scripts/dagui_natives.nut" import run_reactive_gui
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "frp" import warn_on_deprecated_methods
from "dagor.system" import DBGLEVEL

warn_on_deprecated_methods(DBGLEVEL > 0)

let { isPC, is_gdk } = require("%sqstd/platform.nut")
let { registerGlobalModule } = require("%scripts/global_modules.nut")
registerGlobalModule("g_squad_manager")
registerGlobalModule("events")

let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
require("%scripts/mainConsts.nut")

clear_vm_entity_systems()
start_es_loading()

let u = require("%sqStdLibs/helpers/u.nut")
let { loadOnce, registerPersistentData, isInReloading
} = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
let { getSystemConfigOption, setSystemConfigOption } = require("%globalScripts/systemConfig.nut")
require("%scripts/worldWar/worldWarConst.nut")
require("%globalScripts/ui_globals.nut")

let sqdebugger = require_optional("sqdebugger")
let console = require("console")

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData)

require("%globalScripts/version.nut")
require("%scripts/compatibility.nut")
require("%scripts/clientState/errorHandling.nut")

let { ref_time_ticks } = require("dagor.time")
let { set_rnd_seed } = require("dagor.random")

::cross_call_api <- {
  hasFeature = require("%scripts/user/features.nut").hasFeature
}

registerPersistentData("MainGlobals", getroottable(),
  [
    "showConsoleButtons.value"
  ])

set_rnd_seed(ref_time_ticks())



let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
subscriptions.setDefaultPriority(require("g_listener_priority.nut").DEFAULT)

foreach (fn in [
  "%scripts/debugTools/dbgToString.nut"
  "%sqDagui/framework/framework.nut"
])
  require(fn)

require("onScriptLoad.nut")

foreach (fn in [
  "%sqstd/math.nut"

  "%sqDagui/guiBhv/allBhv.nut"
  "%scripts/onlineShop/urlType.nut"
  "%scripts/onlineShop/url.nut"

  "%scripts/viewUtils/layeredIcon.nut"

  "%sqDagui/timer/timer.nut"

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
  loadOnce(fn)
}

u.registerClass(
  "DaGuiObject",
  DaGuiObject,
  @(obj1, obj2) obj1.isValid() && obj2.isValid() && obj1.isEqual(obj2),
  @(obj) !obj.isValid()
)

  
require("%scripts/matching/matchingGameSettings.nut")
require("%sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(script_net_assert_once)
require("%scripts/clientState/elems/dlDataStatElem.nut")
require("%scripts/clientState/elems/copyrightText.nut")
require("%sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")
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

let { isAuthorized } = require("%appGlobals/login/loginState.nut")
let { shouldDisableMenu } = require("%globalScripts/clientState/initialState.nut")
let { loadScriptsAfterLoginOnce } = require("%scripts/loadScriptsAfterLogin.nut")
if (isAuthorized.get() || shouldDisableMenu) { 
  loadScriptsAfterLoginOnce()
  if (!isInReloading())
    run_reactive_gui()
}


