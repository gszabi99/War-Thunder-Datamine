//checked for plus_string
from "%scripts/dagui_library.nut" import *
#default:no-func-decl-sugar
#default:no-class-decl-sugar
#default:explicit-this
#default:no-root-fallback

from "ecs" import clear_vm_entity_systems, start_es_loading, end_es_loading
clear_vm_entity_systems()
start_es_loading()

global const CLAN_SEASON_NUM_IN_YEAR_SHIFT = 1 // Because numInYear is zero-based.
global const EVENTS_SHORT_LB_VISIBLE_ROWS = 3
global const USE_STEAM_LOGIN_AUTO_SETTING_ID = "useSteamLoginAuto"
global const TANK_ALT_CROSSHAIR_ADD_NEW = -2
global const TANK_CAMO_SCALE_SLIDER_FACTOR = 0.1
global const SQUADS_VERSION = 2
global const ARMY_GROUP = "army"
global const UNIT_WEAPONS_ZERO    = 0
global const UNIT_WEAPONS_WARNING = 1
global const UNIT_WEAPONS_READY   = 2

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
require("%scripts/worldWar/worldWarConst.nut")
require("%globalScripts/ui_globals.nut")

let sqdebugger = require_optional("sqdebugger")
let console = require("console")

sqdebugger?.setObjPrintFunc(debugTableData)
console.setObjPrintFunc(debugTableData)

require("%globalScripts/version.nut")
require("%sqStdLibs/scriptReloader/scriptReloader.nut")
require("%scripts/compatibility.nut")
require("%scripts/clientState/errorHandling.nut")

let { get_local_unixtime } = require("dagor.time")
let { set_rnd_seed } = require("dagor.random")

if (::disable_network())
  ::get_charserver_time_sec = get_local_unixtime

::eula_version <- 6

::TEXT_EULA <- 0

::is_dev_version <- false // WARNING : this is unsecure

::INVALID_USER_ID <- ::make_invalid_user_id()
::RESPAWNS_UNLIMITED <- -1

::custom_miss_flight <- false
::is_debug_mode_enabled <- false
::first_generation <- true

::show_console_buttons <- false
::ps4_vsync_enabled <- true


::cross_call_api <- {
  hasFeature = require("%scripts/user/features.nut").hasFeature
}

::FORCE_UPDATE <- true

registerPersistentData("MainGlobals", getroottable(),
  [
    "eula_version",
    "is_debug_mode_enabled", "first_generation",
    "show_console_buttons", "is_dev_version"
  ])

global const LOST_DELAYED_ACTION_MSEC = 500
//------- vvv enums vvv ----------

global enum EVENT_TYPE { //bit values for easy multi-type search
  UNKNOWN         = 0
  SINGLE          = 1,
  CLAN            = 2,
  TOURNAMENT      = 4,
  NEWBIE_BATTLES  = 8,

  //basic filters
  ANY             = 15,
  ANY_BASE_EVENTS = 5,
}
 global enum GAME_EVENT_TYPE {
  // Used for events that are neither race nor tournament.
  TM_NONE = "TM_NONE"

  // Race events.
  TM_NONE_RACE = "TM_NONE_RACE"

  // Different tournament events.
  TM_ELO_PERSONAL = "TM_ELO_PERSONAL"
  TM_ELO_GROUP = "TM_ELO_GROUP"
  TM_ELO_GROUP_DETAIL = "TM_ELO_GROUP_DETAIL"
  TM_DOUBLE_ELIMINATION = "TM_DOUBLE_ELIMINATION"
}

global enum weaponsItem {
  primaryWeapon
  weapon  //secondary, weapon presets
  modification
  bullets          //bullets are modifications too, uses only in filling tab panel
  expendables
  spare
  bundle
  nextUnit
  curUnit
  unknown
}

global enum BATTLE_TYPES {
  AIR      = 0,
  TANK     = 1,
  UNKNOWN
}

global enum ps4_activity_feed {
  MISSION_SUCCESS,
  PURCHASE_UNIT,
  CLAN_DUEL_REWARD,
  RESEARCHED_UNIT,
  MISSION_SUCCESS_AFTER_UPDATE,
  MAJOR_UPDATE
}

global enum bit_activity {
  NONE              = 0,
  PS4_ACTIVITY_FEED = 1
}

global enum itemsTab {
  INVENTORY
  SHOP
  WORKSHOP

  TOTAL
}

global enum itemType { //bit values for easy multitype search
  UNKNOWN      = 0

  TROPHY          = 0x0000000001  //chest
  BOOSTER         = 0x0000000002
  TICKET          = 0x0000000004  //tournament ticket
  WAGER           = 0x0000000008
  DISCOUNT        = 0x0000000010
  ORDER           = 0x0000000020
  FAKE_BOOSTER    = 0x0000000040
  UNIVERSAL_SPARE = 0x0000000080
  MOD_OVERDRIVE   = 0x0000000100
  MOD_UPGRADE     = 0x0000000200
  SMOKE           = 0x0000000400

  //external inventory
  VEHICLE         = 0x0000010000
  SKIN            = 0x0000020000
  DECAL           = 0x0000040000
  ATTACHABLE      = 0x0000080000
  KEY             = 0x0000100000
  CHEST           = 0x0000200000
  WARBONDS        = 0x0000400000
  INTERNAL_ITEM   = 0x0000800000 //external inventory coupon which gives internal item
  ENTITLEMENT     = 0x0001000000
  WARPOINTS       = 0x0002000000
  UNLOCK          = 0x0004000000
  BATTLE_PASS     = 0x0008000000
  RENTED_UNIT     = 0x0010000000
  UNIT_COUPON_MOD = 0x0020000000
  PROFILE_ICON    = 0x0040000000

  //workshop
  CRAFT_PART      = 0x1000000000
  RECIPES_BUNDLE  = 0x2000000000
  CRAFT_PROCESS   = 0x4000000000

  //masks
  ALL             = 0xFFFFFFFFFF
  INVENTORY_ALL   = 0xAFFFBFFFFF //~CRAFT_PART ~CRAFT_PROCESS ~WARBONDS
}

global enum PREVIEW_MODE {
  NONE      = 0x0000
  UNIT      = 0x0001
  SKIN      = 0x0002
  DECORATOR = 0x0004
}

global enum prizesStack {
  NOT_STACKED
  DETAILED
  BY_TYPE
}

global enum HELP_CONTENT_SET {
  MISSION
  LOADING
  CONTROLS
}

global enum HUD_TYPE {
  CUTSCENE,
  SPECTATOR,
  BENCHMARK,
  AIR,
  TANK,
  SHIP,
  HELICOPTER,
  FREECAM,

  NONE
}

global enum RespawnOptUpdBit {
  NEVER         = 0x00
  UNIT_ID       = 0x01
  UNIT_WEAPONS  = 0x02
  RESPAWN_BASES = 0x04
  SMOKE_TYPE    = 0x08
}

global enum INFO_DETAIL { //text detalization level. for weapons and modifications names and descriptions
  LIMITED_11 //must to fit in 11 symbols
  SHORT      //short info, like name. mostly in a single string.
  FULL       //full description
  EXTENDED   //full description + addtitional info for more detailed tooltip
}

global enum voiceChatStats {
  online
  offline
  talking
  muted
}

global enum squadMemberState {
  NOT_IN_SQUAD
  SQUAD_LEADER //leader cant be offline or not ready.
  SQUAD_MEMBER
  SQUAD_MEMBER_READY
  SQUAD_MEMBER_OFFLINE
}

global const SAVE_ONLINE_JOB_DIGIT = 123 //super secure digit for job tag :)
global const SAVE_WEAPON_JOB_DIGIT = 321

global enum COLOR_TAG {
  ACTIVE = "av"
  USERLOG = "ul"
  TEAM_BLUE = "tb"
  TEAM_RED = "tr"
}

let colorTagToColors = {
  [COLOR_TAG.ACTIVE] = "activeTextColor",
  [COLOR_TAG.USERLOG] = "userlogColoredText",
  [COLOR_TAG.TEAM_BLUE] = "teamBlueColor",
  [COLOR_TAG.TEAM_RED] = "teamRedColor",
}


global enum SEEN {
  TITLES = "titles"
  AVATARS = "avatars"
  EVENTS = "events"
  WW_MAPS_AVAILABLE = "wwMapsAvailable"
  WW_MAPS_OBJECTIVE = "wwMapsObjective"
  WW_OPERATION_AVAILABLE = "wwOperationAvailable"
  INVENTORY = "inventory"
  ITEMS_SHOP = "items_shop"
  WORKSHOP = "workshop"
  WARBONDS_SHOP = "warbondsShop"
  EXT_XBOX_SHOP = "ext_xbox_shop"
  EXT_PS4_SHOP  = "ext_ps4_shop"
  EXT_EPIC_SHOP = "ext_epic_shop"
  BATTLE_PASS_SHOP = "battle_pass_shop"
  UNLOCK_MARKERS = "unlock_markers"
  MANUAL_UNLOCKS = "manual_unlocks"

  //sublists
  S_EVENTS_WINDOW = "##events_window##"
}

global enum xboxMediaItemType { //values by microsoft IDE, others not used
  GameContent = 4
  GameConsumable = 5
}

global enum contactEvent {
  CONTACTS_UPDATED = "ContactsUpdated"
  CONTACTS_GROUP_ADDED = "ContactsGroupAdd"
  CONTACTS_GROUP_UPDATE = "ContactsGroupUpdate"
}

global enum TOP_MENU_ELEMENT_TYPE {
  BUTTON,
  EMPTY_BUTTON,
  CHECKBOX,
  LINE_SEPARATOR
}

global enum USERLOG_POPUP {
  UNLOCK                = 0x0001
  FINISHED_RESEARCHES   = 0x0002
  OPEN_TROPHY           = 0x0004

  //masks
  ALL                   = 0xFFFF
  NONE                  = 0x0000
}

global enum squadState {
  NOT_IN_SQUAD
  JOINING
  IN_SQUAD
  LEAVING
}

global enum ONLINE_SHOP_TYPES {
  WARPOINTS = "warpoints"
  PREMIUM = "premium"
  BUNDLE = "bundle"
  EAGLES = "eagles"
}

global const LEADERBOARD_VALUE_TOTAL = "value_total"
global const LEADERBOARD_VALUE_INHISTORY = "value_inhistory"

set_rnd_seed(get_local_unixtime())

//------- vvv files before login vvv ----------

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
::g_listener_priority <- require("g_listener_priority.nut")
subscriptions.setDefaultPriority(::g_listener_priority.DEFAULT)

::add_big_query_record <- require("chard")?.addBigQueryRecord
  ?? ::add_big_query_record // Compatibility with 2.15.0.X

foreach (fn in [
  "%scripts/debugTools/dbgToString.nut"
  "%sqDagui/framework/framework.nut"
])
  require(fn)

require("onScriptLoad.nut")

foreach (fn in [
  "%globalScripts/sharedEnums.nut"

  "%sqstd/math.nut"

  "%sqDagui/guiBhv/allBhv.nut"
  "%scripts/bhvCreditsScroll.nut"
  "%globalScripts/cubicBezierSolver.nut"
  "%scripts/onlineShop/urlType.nut"
  "%scripts/onlineShop/url.nut"

  "%sqDagui/daguiUtil.nut"
  "%scripts/viewUtils/layeredIcon.nut"
  "%scripts/viewUtils/projectAwards.nut"

  "%scripts/util.nut"
  "%sqStdLibs/helpers/datablockUtils.nut"
  "%sqDagui/timer/timer.nut"

  "%scripts/clientState/localProfile.nut"
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

  "%scripts/hangarLights.nut"

  "%scripts/webRPC.nut"
  "%scripts/matching/client.nut"

  "%scripts/wndLib/editBoxHandler.nut"
  "%scripts/wndLib/rightClickMenu.nut"
  "%scripts/actionsList.nut"
  //used before xbox login
  "%scripts/social/xboxSquadManager/xboxSquadManager.nut"

  //used for SSO login
  "%scripts/onlineShop/browserWnd.nut"
]) {
  loadOnce(fn)
}

if (isInReloading())
  foreach (bhvName, bhvClass in ::gui_bhv)
    ::replace_script_gui_behaviour(bhvName, bhvClass)

foreach (bhvName, bhvClass in ::gui_bhv_deprecated)
  ::add_script_gui_behaviour(bhvName, bhvClass)

u.registerClass(
  "DaGuiObject",
  ::DaGuiObject,
  @(obj1, obj2) obj1.isValid() && obj2.isValid() && obj1.isEqual(obj2),
  @(obj) !obj.isValid()
)

  // Independent Modules (before login)
require("%scripts/matching/matchingGameSettings.nut")
require("%sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(::script_net_assert_once)
require("%scripts/clientState/elems/dlDataStatElem.nut")
require("%scripts/clientState/elems/copyrightText.nut")
require("%sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")

  //debug scripts
require("%scripts/debugTools/dbgAvatarsList.nut")
require("%scripts/debugTools/dbgDumpTools.nut")
require("%scripts/debugTools/dbgFonts.nut")
require("%scripts/debugTools/dbgUtils.nut")
require("%scripts/debugTools/dbgImage.nut")
require("%scripts/debugTools/dbgMarketplace.nut")
require("%scripts/debugTools/dbgCrewLock.nut")
require("%scripts/debugTools/dbgDedicLogerrs.nut")
require("%globalScripts/debugTools/dbgTimer.nut").registerConsoleCommand("dagui")
  // end of Independent Modules

end_es_loading()

let platform = require("%scripts/clientState/platform.nut")

::cross_call_api.platform <- {
  getPlayerName = platform.getPlayerName
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
  require("%sqDagui/guiBhv/bhvUpdateByWatched.nut").setAssertFunction(::script_net_assert_once)
  require("%scripts/social/activityFeed/activityFeedModule.nut")
  require("%scripts/controls/controlsPseudoAxes.nut")
  require("%scripts/utils/delayedTooltip.nut")
  require("%scripts/slotbar/elems/remainingTimeUnitElem.nut")

  if (platform.isPlatformXboxOne)
    require("%scripts/global/xboxCallbacks.nut")

  if (platform.isPlatformSony) {
    require("%scripts/global/psnCallbacks.nut")
    require("%scripts/social/psnSessionManager/loadPsnSessionManager.nut")
    if (require("sony.webapi").getPreferredVersion() == 2)
      require("%scripts/social/psnMatches.nut").enableMatchesReporting()
  }

  if (platform.isPlatformPS5) {
    require("%scripts/user/psnFeatures.nut").enablePremiumFeatureReporting()
    require("%scripts/gameModes/psnActivities.nut").enableGameIntents()
  }

  if (::steam_is_running())
    require("%scripts/inventory/steamCheckNewItems.nut")
  // end of Independent Modules

  require("%scripts/utils/systemMsg.nut").registerColors(colorTagToColors)
  end_es_loading()
}

//app does not exist on script load, so we cant to use ::app->shouldDisableMenu
{
  let shouldDisableMenu = (::disable_network() && ::getFromSettingsBlk("debug/disableMenu", false))
    || ::getFromSettingsBlk("benchmarkMode", false)
    || ::getFromSettingsBlk("viewReplay", false)

  ::should_disable_menu <- function should_disable_menu() {
    return shouldDisableMenu
  }
}

if (is_platform_pc && !::isProductionCircuit() && ::getSystemConfigOption("debug/netLogerr") == null)
  ::setSystemConfigOption("debug/netLogerr", true)

if (::g_login.isAuthorized() || ::should_disable_menu()) { //scripts reload
  ::load_scripts_after_login_once()
  if (!isInReloading())
    ::run_reactive_gui()
}

//------- ^^^ files after login ^^^ ----------
