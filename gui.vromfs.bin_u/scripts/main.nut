#default:no-func-decl-sugar
#default:no-class-decl-sugar

require("%globalScripts/ui_globals.nut")

let __string = require("string")
foreach (name, func in require("dagor.localize"))
  ::dagor[name] <- func

::regexp<-__string.regexp
::split <-__string.split
::format <-__string.format
::strip<-__string.strip
let __math = require("math")
::fabs<-__math.fabs
::kwarg <- require("%sqstd/functools.nut").kwarg
::memoize <- require("%sqstd/functools.nut").memoize

let frp = require("frp")
::Watched <- frp.Watched
::Computed <-frp.Computed

::script_protocol_version <- null
require("%globalScripts/version.nut")
require("%sqStdLibs/scriptReloader/scriptReloader.nut")
require("%globalScripts/sqModuleHelpers.nut")
require("%sqStdLibs/helpers/backCompatibility.nut")
require("%scripts/compatibility.nut")
require("%scripts/clientState/errorHandling.nut")
let { get_local_unixtime } = require("dagor.time")
if (::disable_network())
  ::get_charserver_time_sec = get_local_unixtime

::nda_version <- -1
::nda_version_tanks <-5
::eula_version <- 6

::TEXT_EULA <- 0
::TEXT_NDA <- 1

::target_platform <- ::get_platform()
::is_platform_pc <- ["win32", "win64", "macosx", "linux64"].indexof(::target_platform) != null
::is_platform_windows <- ["win32", "win64"].indexof(::target_platform) != null
::is_platform_android <- ::target_platform == "android"
::is_platform_xbox <- ::target_platform == "xboxOne" || ::target_platform == "xboxScarlett"

::is_dev_version <- false // WARNING : this is unsecure

::INVALID_USER_ID <- ::make_invalid_user_id()
::RESPAWNS_UNLIMITED <- -1

::custom_miss_flight <- false
::is_debug_mode_enabled <- false
::first_generation <- true

::show_console_buttons <- false
::ps4_vsync_enabled <- true

::cross_call_api <- {}

::FORCE_UPDATE <- true
global const LOST_DELAYED_ACTION_MSEC = 500

::g_script_reloader.registerPersistentData("MainGlobals", ::getroottable(),
  [
    "nda_version", "nda_version_tanks", "eula_version",
    "is_debug_mode_enabled", "first_generation",
    "show_console_buttons", "is_dev_version"
  ])

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

global enum GAME_EVENT_TYPE
{
  /** Used for events that are neither race nor tournament. */
  TM_NONE = "TM_NONE"

  /** Race events. */
  TM_NONE_RACE = "TM_NONE_RACE"

  // Different tournament events.
  TM_ELO_PERSONAL = "TM_ELO_PERSONAL"
  TM_ELO_GROUP = "TM_ELO_GROUP"
  TM_ELO_GROUP_DETAIL = "TM_ELO_GROUP_DETAIL"
  TM_DOUBLE_ELIMINATION = "TM_DOUBLE_ELIMINATION"
}

global enum weaponsItem
{
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

global enum BATTLE_TYPES
{
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
  PS4_ACTIVITY_FEED = 1,
  FACEBOOK          = 2,
  ALL               = 3
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

global enum PREVIEW_MODE
{
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

global enum HELP_CONTENT_SET
{
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

global enum INFO_DETAIL //text detalization level. for weapons and modifications names and descriptions
{
  LIMITED_11 //must to fit in 11 symbols
  SHORT      //short info, like name. mostly in a single string.
  FULL       //full description
  EXTENDED   //full description + addtitional info for more detailed tooltip
}

global enum voiceChatStats
{
  online
  offline
  talking
  muted
}

global enum squadMemberState
{
  NOT_IN_SQUAD
  SQUAD_LEADER //leader cant be offline or not ready.
  SQUAD_MEMBER
  SQUAD_MEMBER_READY
  SQUAD_MEMBER_OFFLINE
}

::ES_UNIT_TYPE_TOTAL_RELEASED <- 3

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
  INVENTORY = "inventory"
  ITEMS_SHOP = "items_shop"
  WORKSHOP = "workshop"
  WARBONDS_SHOP = "warbondsShop"
  EXT_XBOX_SHOP = "ext_xbox_shop"
  EXT_PS4_SHOP  = "ext_ps4_shop"
  EXT_EPIC_SHOP = "ext_epic_shop"
  BATTLE_PASS_SHOP = "battle_pass_shop"
  UNLOCK_MARKERS = "unlock_markers"

  //sublists
  S_EVENTS_WINDOW = "##events_window##"
}

global enum xboxMediaItemType { //values by microsoft IDE, others not used
  GameContent = 4
  GameConsumable = 5
}

global enum contactEvent
{
  CONTACTS_UPDATED = "ContactsUpdated"
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

global enum squadState
{
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

::randomize <- function randomize()
{
  ::math.init_rnd(get_local_unixtime())
}
randomize()

//------- vvv files before login vvv ----------

::g_string <- require("%sqstd/string.nut") //put g_string to root_table
::u <- require("%sqStdLibs/helpers/u.nut") //put u to roottable
::Callback <- require("%sqStdLibs/helpers/callback.nut").Callback

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
::g_listener_priority <- {
  DEFAULT = 0
  DEFAULT_HANDLER = 1
  UNIT_CREW_CACHE_UPDATE = 2
  USER_PRESENCE_UPDATE = 2
  CONFIG_VALIDATION = 2
  LOGIN_PROCESS = 3
  MEMOIZE_VALIDATION = 4
}
subscriptions.setDefaultPriority(::g_listener_priority.DEFAULT)
::broadcastEvent <- subscriptions.broadcast
::add_event_listener <- subscriptions.addEventListener
::subscribe_handler <- subscriptions.subscribeHandler

::has_feature <- require("%scripts/user/features.nut").hasFeature

let guiOptions = require("guiOptions")
foreach(name in [
  "get_gui_option", "set_gui_option", "get_unit_option", "set_unit_option",
  "get_cd_preset", "set_cd_preset"
])
  if (name not in ::getroottable())
    ::getroottable()[name] <- guiOptions[name]

foreach(fn in [
  "%scripts/debugTools/dbgToString.nut"
  "%sqDagui/framework/framework.nut"
])
  require(fn)

let { getShortAppName } = ::require_native("app")
let game = getShortAppName()
let gameMnt = { mecha = "%mechaScripts", vrThunder = "%vrtScripts", wt = "%wtScripts" }?[game]
::dagor.debug($"Load UI scripts by game: {game} (mnt = {gameMnt})")
require_optional($"{gameMnt}/onScriptLoad.nut")


foreach (fn in [
  "%globalScripts/sharedEnums.nut"

  "%sqstd/math.nut"

  "%sqDagui/guiBhv/allBhv.nut"
  "%scripts/bhvCreditsScroll.nut"
  "%scripts/cubicBezierSolver.nut"
  "%scripts/onlineShop/urlType.nut"
  "%scripts/onlineShop/url.nut"

  "%sqStdLibs/helpers/handyman.nut"

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

  //probably used before login on ps4
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
  "%scripts/loading/loadingTips.nut"
  "%scripts/options/countryFlagsPreset.nut"

  "%scripts/hangarLights.nut"

  "%scripts/webRPC.nut"
  "%scripts/matching/api.nut"
  "%scripts/matching/client.nut"
  "%scripts/matching/matchingConnect.nut"

  "%scripts/wndLib/editBoxHandler.nut"
  "%scripts/wndLib/rightClickMenu.nut"
  "%scripts/actionsList.nut"

  "%scripts/debugTools/dbgEnum.nut"
  "%scripts/debugTools/debugWnd.nut"
  "%scripts/debugTools/dbgTimer.nut"
  "%scripts/debugTools/dbgDumpTools.nut"
  "%scripts/debugTools/dbgUtils.nut"
  "%scripts/debugTools/dbgImage.nut"
  "%scripts/debugTools/dbgFonts.nut"
  "%scripts/debugTools/dbgAvatarsList.nut"
  "%scripts/debugTools/dbgMarketplace.nut"

  //used before xbox login
  "%scripts/social/xboxSquadManager.nut"

  //used for SSO login
  "%scripts/onlineShop/browserWnd.nut"
])
{
  ::g_script_reloader.loadOnce(fn)
}

if (::g_script_reloader.isInReloading)
  foreach(bhvName, bhvClass in ::gui_bhv)
    ::replace_script_gui_behaviour(bhvName, bhvClass)

foreach(bhvName, bhvClass in ::gui_bhv_deprecated)
  ::add_script_gui_behaviour(bhvName, bhvClass)

::u.registerClass(
  "DaGuiObject",
  ::DaGuiObject,
  @(obj1, obj2) obj1.isValid() && obj2.isValid() && obj1.isEqual(obj2),
  @(obj) !obj.isValid()
)

  // Independent Modules (before login)
require("%sqDagui/elemUpdater/bhvUpdater.nut").setAssertFunction(::script_net_assert_once)
require("%scripts/clientState/elems/dlDataStatElem.nut")
require("%scripts/clientState/elems/copyrightText.nut")
require("%sqDagui/framework/progressMsg.nut").setTextLocIdDefault("charServer/purchase0")
  // end of Independent Modules

let platform = require("%scripts/clientState/platform.nut")
::cross_call_api.platform <- {
  getPlayerName = platform.getPlayerName
  is_pc = @() platform.isPlatformPC
}

let { is_stereo_mode } = ::require_native("vr")
::cross_call_api.isInVr <- @() is_stereo_mode()

//------- ^^^ files before login ^^^ ----------


//------- vvv files after login vvv ----------

local isFullScriptsLoaded = false
::load_scripts_after_login_once <- function load_scripts_after_login_once()
{
  if (isFullScriptsLoaded)
    return
  isFullScriptsLoaded = true

  // Independent Modules with mainHandler. Need load this befor rest handlers
  require("%scripts/baseGuiHandlerWT.nut")
  // end of Independent Modules with mainHandler

  ::dagor.debug($"Load UI scripts by game after login: {game} (mnt = {gameMnt})")
  require_optional($"{gameMnt}/onScriptLoadAfterLogin.nut")

  // Independent Modules (after login)
  require("%scripts/social/playerInfoUpdater.nut")
  require("%scripts/squads/elems/voiceChatElem.nut")
  require("%scripts/matching/serviceNotifications/showInfo.nut")
  require("%scripts/unit/unitContextMenu.nut")
  require("%sqDagui/guiBhv/bhvUpdateByWatched.nut").setAssertFunction(::script_net_assert_once)
  require("%scripts/social/activityFeed/activityFeedModule.nut")
  require("%scripts/controls/controlsPseudoAxes.nut")
  require("%scripts/controls/guiSceneCursorVisibility.nut")
  require("%scripts/utils/delayedTooltip.nut")

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
  // end of Independent Modules

  require("%scripts/utils/systemMsg.nut").registerColors(colorTagToColors)
}

//app does not exist on script load, so we cant to use ::app->shouldDisableMenu
{
  let shouldDisableMenu = (::disable_network() && ::getFromSettingsBlk("debug/disableMenu", false))
    || ::getFromSettingsBlk("benchmarkMode", false)
    || ::getFromSettingsBlk("viewReplay", false)

  ::should_disable_menu <- function should_disable_menu()
  {
    return shouldDisableMenu
  }
}

if (::is_platform_pc && !::isProductionCircuit() && getSystemConfigOption("debug/netLogerr") == null)
  ::setSystemConfigOption("debug/netLogerr", true)

if (::g_login.isAuthorized() //scripts reload
    || ::should_disable_menu())
{
  ::load_scripts_after_login_once()
  if (!::g_script_reloader.isInReloading)
    ::run_reactive_gui()
}

//------- ^^^ files after login ^^^ ----------
