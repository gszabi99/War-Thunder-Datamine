from "%scripts/dagui_natives.nut" import disable_network, run_reactive_gui, steam_is_running, make_invalid_user_id, get_cur_circuit_name
from "%scripts/dagui_library.nut" import *
from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
from "%scripts/mainConsts.nut" import COLOR_TAG

let { registerGlobalModule } = require("%scripts/global_modules.nut")
registerGlobalModule("g_squad_manager")

let { script_net_assert_once } = require("%sqStdLibs/helpers/net_errors.nut")
require("%scripts/mainConsts.nut")

clear_vm_entity_systems()
start_es_loading()

let colorTagToColors = {
  [COLOR_TAG.ACTIVE] = "activeTextColor",
  [COLOR_TAG.USERLOG] = "userlogColoredText",
  [COLOR_TAG.TEAM_BLUE] = "teamBlueColor",
  [COLOR_TAG.TEAM_RED] = "teamRedColor",
}

let test_flight_unit_info = {}
::get_test_flight_unit_info <- @() freeze(test_flight_unit_info)
::update_test_flight_unit_info <- function(info) {
  test_flight_unit_info.clear()
  test_flight_unit_info.__update(info)
}

::get_mp_kick_countdown <- @() 1000000

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

let { get_local_unixtime } = require("dagor.time")
let { set_rnd_seed } = require("dagor.random")

::INVALID_USER_ID <- make_invalid_user_id()
::RESPAWNS_UNLIMITED <- -1

::custom_miss_flight <- false
::is_debug_mode_enabled <- false
::first_generation <- true

::ps4_vsync_enabled <- true


::cross_call_api <- {
  hasFeature = require("%scripts/user/features.nut").hasFeature
}

::FORCE_UPDATE <- true

registerPersistentData("MainGlobals", getroottable(),
  [
    "is_debug_mode_enabled", "first_generation",
    "showConsoleButtons.value"
  ])

set_rnd_seed(get_local_unixtime())

//------- vvv files before login vvv ----------

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
  "%scripts/bhvCreditsScroll.nut"
  "%scripts/onlineShop/urlType.nut"
  "%scripts/onlineShop/url.nut"

  "%scripts/viewUtils/layeredIcon.nut"
  "%scripts/viewUtils/projectAwards.nut"

  "%scripts/util.nut"
  "%sqDagui/timer/timer.nut"

  "%scripts/options/optionsExtNames.nut"
  "%scripts/options/fonts.nut"
  "%scripts/options/consoleMode.nut"
  "%scripts/options/optionsBeforeLogin.nut"
  "%scripts/options/privacyOptionsManager.nut"

  //probably used before login on ps4
  "%scripts/controls/guiSceneCursorVisibility.nut"
  "%scripts/controls/controlsConsts.nut"
  "%scripts/controls/rawShortcuts.nut"
  "%scripts/controls/controlsManager.nut"

  "%scripts/baseGuiHandlerManagerWT.nut"

  "%scripts/langUtils/localization.nut"
  "%scripts/langUtils/language.nut"

  "%scripts/clientState/keyboardState.nut"
  "%scripts/clientState/contentPacks.nut"
  "%scripts/utils/errorMsgBox.nut"
  "%scripts/tasker.nut"
  "%scripts/utils/delayedActions.nut"

  "%scripts/clientState/fpsDrawer.nut"

  "%scripts/clientState/applyRendererSettingsChange.nut"

  //used in loading screen
  "%scripts/controls/input/inputBase.nut"
  "%scripts/controls/input/nullInput.nut"
  "%scripts/controls/shortcutType.nut"
  "%scripts/viewUtils/hintTags.nut"
  "%scripts/viewUtils/hints.nut"
  "%scripts/viewUtils/bhvHint.nut"

  "%scripts/loading/loading.nut"

  "%scripts/options/gamepadCursorControls.nut"
  "%scripts/unit/unitType.nut"
  "%scripts/loading/bhvLoadingTip.nut"
  "%scripts/options/countryFlagsPreset.nut"

  "%scripts/webRPC.nut"
  "%scripts/matching/client.nut"

  "%scripts/wndLib/editBoxHandler.nut"
  "%scripts/wndLib/rightClickMenu.nut"
  "%scripts/actionsList.nut"
  "%scripts/eulaWnd.nut"
  "%scripts/controls/input/button.nut"
  //used before xbox login
  "%scripts/social/xboxSquadManager/xboxSquadManager.nut"

  //used for SSO login
  "%scripts/onlineShop/browserWnd.nut"
]) {
  loadOnce(fn)
}

u.registerClass(
  "DaGuiObject",
  ::DaGuiObject,
  @(obj1, obj2) obj1.isValid() && obj2.isValid() && obj1.isEqual(obj2),
  @(obj) !obj.isValid()
)

  // Independent Modules (before login)
require("%scripts/matching/matchingGameSettings.nut")
require("%sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(script_net_assert_once)
require("%scripts/clientState/elems/dlDataStatElem.nut")
require("%scripts/clientState/elems/copyrightText.nut")
require("%sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")
require("%scripts/options/bhvHarmonizedImage.nut")

  //debug scripts
require("%scripts/debugTools/dbgAvatarsList.nut")
require("%scripts/debugTools/dbgFonts.nut")
require("%scripts/debugTools/dbgUtils.nut")
require("%scripts/debugTools/dbgImage.nut")
require("%scripts/debugTools/dbgMarketplace.nut")
require("%scripts/debugTools/dbgCrewLock.nut")
require("%scripts/debugTools/dbgDedicLogerrs.nut")
require("%sqstd/regScriptProfiler.nut")("dagui", dlog) // warning disable: -forbidden-function
require("%scripts/wndLib/qrWindow.nut") // for ability to show qr code window from openUrl

  // end of Independent Modules

end_es_loading()

let platform = require("%scripts/clientState/platform.nut")

if (platform.isPlatformXboxOne) {
  require("%scripts/xbox/onLoad.nut")
}

//------- ^^^ files before login ^^^ ----------

//------- vvv files after login vvv ----------

local isFullScriptsLoaded = false
::load_scripts_after_login_once <- function load_scripts_after_login_once() {
  if (isFullScriptsLoaded)
    return
  isFullScriptsLoaded = true
  start_es_loading()
  // Independent Modules with mainHandler. Need load this befor rest handlers
  require("%scripts/baseGuiHandlerWT.nut")
  // end of Independent Modules with mainHandler

  require("%scripts/onScriptLoadAfterLogin.nut")

  // Independent Modules (after login)
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

  if (platform.isPlatformXboxOne)
    require("%scripts/global/xboxCallbacks.nut")

  if (platform.isPlatformSony) {
    require("%scripts/global/psnCallbacks.nut")
    require("%scripts/social/psnSessionManager/loadPsnSessionManager.nut")
    require("%scripts/social/psnMatches.nut").enableMatchesReporting()
  }

  if (platform.isPlatformPS5) {
    require("%scripts/user/psnFeatures.nut").enablePremiumFeatureReporting()
    require("%scripts/gameModes/enablePsnActivitiesGameIntents.nut")
  }

  if (steam_is_running())
    require("%scripts/inventory/steamCheckNewItems.nut")
  // end of Independent Modules

  require("%scripts/utils/systemMsg.nut").registerColors(colorTagToColors)
  end_es_loading()
}

//app does not exist on script load, so we cant to use ::app->shouldDisableMenu
{
  let { getFromSettingsBlk } = require("%scripts/clientState/clientStates.nut")
  let shouldDisableMenu = (disable_network() && getFromSettingsBlk("debug/disableMenu", false))
    || getFromSettingsBlk("benchmarkMode", false)
    || getFromSettingsBlk("viewReplay", false)

  ::should_disable_menu <- function should_disable_menu() {
    return shouldDisableMenu
  }
}

if (is_platform_pc && get_cur_circuit_name().indexof("production") == null
  && getSystemConfigOption("debug/netLogerr") == null)
    setSystemConfigOption("debug/netLogerr", true)

if (::g_login.isAuthorized() || ::should_disable_menu()) { //scripts reload
  ::load_scripts_after_login_once()
  if (!isInReloading())
    run_reactive_gui()
}

//------- ^^^ files after login ^^^ ----------
