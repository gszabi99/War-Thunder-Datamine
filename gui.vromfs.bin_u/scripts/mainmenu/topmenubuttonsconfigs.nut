local { canUseIngameShop,
        getShopItemsTable,
        getEntStoreLocId,
        getEntStoreIcon,
        isEntStoreTopMenuItemHidden,
        getEntStoreUnseenIcon,
        needEntStoreDiscountIcon,
        openEntStoreTopMenuFunc } = require("scripts/onlineShop/entitlementsStore.nut")
local contentStateModule = require("scripts/clientState/contentState.nut")
local workshop = require("scripts/items/workshop/workshop.nut")
local { isPlatformSony,
        isPlatformPC } = require("scripts/clientState/platform.nut")
local encyclopedia = require("scripts/encyclopedia.nut")
local { openChangelog } = require("scripts/changelog/openChangelog.nut")
local openPersonalUnlocksModal = require("scripts/unlocks/personalUnlocksModal.nut")
local { openUrlByObj } = require("scripts/onlineShop/url.nut")
local openQrWindow = require("scripts/wndLib/qrWindow.nut")
local { getTextWithCrossplayIcon,
        needShowCrossPlayInfo,
        isCrossPlayEnabled } = require("scripts/social/crossplay.nut")

local { openOptionsWnd } = require("scripts/options/handlers/optionsWnd.nut")
local topMenuHandlerClass = require("scripts/mainmenu/topMenuHandler.nut")
local { buttonsListWatch } = require("scripts/mainmenu/topMenuButtons.nut")
local { openCollectionsWnd, hasAvailableCollections } = require("scripts/collections/collectionsWnd.nut")
local exitGame = require("scripts/utils/exitGame.nut")
local {
  checkAndShowMultiplayerPrivilegeWarning,
  isMultiplayerPrivilegeAvailable } = require("scripts/user/xboxFeatures.nut")
local { showViralAcquisitionWnd } = require("scripts/user/viralAcquisition.nut")
local { isMarketplaceEnabled, goToMarketplace } = require("scripts/items/itemsMarketplace.nut")

local template = {
  id = ""
  text = @() ""
  tooltip = @() ""
  image = @() null
  link = null
  isLink = @() false
  isFeatured = @() false
  needDiscountIcon = false
  unseenIcon = null
  onClickFunc = @(obj, handler = null) null
  onChangeValueFunc = @(value) null
  isHidden = @(handler = null) false
  isVisualDisabled = @() false
  isInactiveInQueue = false
  elementType = TOP_MENU_ELEMENT_TYPE.BUTTON
  isButton = @() elementType == TOP_MENU_ELEMENT_TYPE.BUTTON
  isDelayed = true
  checkbox = @() elementType == TOP_MENU_ELEMENT_TYPE.CHECKBOX //param name only because of checkbox.tpl
  isLineSeparator = @() elementType == TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  isEmptyButton = @() elementType == TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  funcName = @() isButton()? "onClick" : checkbox()? "onChangeCheckboxValue" : null
}

local list = {
  UNKNOWN = {}
  SKIRMISH = {
    text = @() "#mainmenu/btnSkirmish"
    onClickFunc = function(obj, handler)
    {
      if (!::is_custom_battles_enabled())
        return ::show_not_available_msg_box()
      if (!::check_gamemode_pkg(::GM_SKIRMISH))
        return

      if (!checkAndShowMultiplayerPrivilegeWarning())
        return

      ::queues.checkAndStart(
        ::Callback(@() goForwardIfOnline(::gui_start_skirmish, false), handler),
        null,
        "isCanNewflight"
      )
    }

    isHidden = @(...) !::is_custom_battles_enabled()
    isInactiveInQueue = true
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable()
    tooltip = function() {
      if (!isMultiplayerPrivilegeAvailable())
        return ::loc("xbox/noMultiplayer")
      return ""
    }
  }
  WORLDWAR = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), ::loc("mainmenu/btnWorldwar"))
    onClickFunc = function(obj, handler)
    {
      if (!::g_world_war.checkPlayWorldwarAccess())
        return

      ::queues.checkAndStart(
        ::Callback(@() goForwardIfOnline(@() ::g_world_war.openOperationsOrQueues(), false), handler),
        null,
        "isCanNewflight"
      )
    }
    tooltip = @() ::is_worldwar_enabled() ? ::g_world_war.getCantPlayWorldwarReasonText() : ""
    isVisualDisabled = @() ::is_worldwar_enabled() && !::g_world_war.canPlayWorldwar()
    isHidden = @(...) !::is_worldwar_enabled()
    isInactiveInQueue = true
    unseenIcon = @() ::is_worldwar_enabled() && ::g_world_war.canPlayWorldwar() ?
      SEEN.WW_MAPS_AVAILABLE : null
  }
  TUTORIAL = {
    text = @() "#mainmenu/btnTutorial"
    onClickFunc = @(obj, handler) handler.checkedNewFlight(::gui_start_tutorial)
    isHidden = @(...) !::has_feature("Tutorials")
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    text = @() "#mainmenu/btnSingleMission"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_SINGLE_MISSION)
    isHidden = @(...) !::has_feature("ModeSingleMissions")
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = @() "#mainmenu/btnDynamic"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_DYNAMIC)
    isHidden = @(...) !::has_feature("ModeDynamic")
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    text = @() "#mainmenu/btnCampaign"
    onClickFunc = function(obj, handler) {
      if (contentStateModule.isHistoricalCampaignDownloading())
        return ::showInfoMsgBox(::loc("mainmenu/campaignDownloading"), "question_wait_download")

      if (::is_any_campaign_available())
        return handler.checkedNewFlight(@() ::gui_start_campaign())

      if (!::has_feature("OnlineShopPacks"))
        return ::show_not_available_msg_box()

      ::scene_msg_box("question_buy_campaign", null, ::loc("mainmenu/questionBuyHistorical"),
        [
          ["yes", ::purchase_any_campaign],
          ["no", function() {}]
        ], "yes", { cancel_fn = function() {}})
    }
    isHidden = @(...) !::has_feature("HistoricalCampaign")
    isVisualDisabled = @() contentStateModule.isHistoricalCampaignDownloading()
    isInactiveInQueue = true
  }
  BENCHMARK = {
    text = @() "#mainmenu/btnBenchmark"
    onClickFunc = @(obj, handler) handler.checkedNewFlight(::gui_start_benchmark)
    isHidden = @(...) !::has_feature("Benchmark")
    isInactiveInQueue = true
  }
  USER_MISSION = {
    text = @() "#mainmenu/btnUserMission"
    onClickFunc = @(obj, handler) ::checkAndCreateGamemodeWnd(handler, ::GM_USER_MISSION)
    isHidden = @(...) !::has_feature("UserMissions")
    isInactiveInQueue = true
  }
  PERSONAL_UNLOCKS = {
    text = @() "#mainmenu/btnPersonalUnlocks"
    onClickFunc = @(obj, handler) openPersonalUnlocksModal()
    isHidden = @(...) !::has_feature("PersonalUnlocks")
  }
  OPTIONS = {
    text = @() "#mainmenu/btnGameplay"
    onClickFunc = @(obj, handler) openOptionsWnd()
  }
  CONTROLS = {
    text = @() "#mainmenu/btnControls"
    onClickFunc = @(...) ::gui_start_controls()
  }
  LEADERBOARDS = {
    text = @() "#mainmenu/btnLeaderboards"
    onClickFunc = @(obj, handler) handler.goForwardIfOnline(::gui_modal_leaderboards, false, true)
    isHidden = @(...) !::has_feature("Leaderboards")
  }
  CLANS = {
    text = @() "#mainmenu/btnClans"
    onClickFunc = @(...) ::has_feature("Clans")? ::gui_modal_clans() : ::show_not_available_msg_box()
    isHidden = @(...) !::has_feature("Clans")
  }
  REPLAY = {
    text = @() "#mainmenu/btnReplays"
    onClickFunc = @(obj, handler) isPlatformSony? ::show_not_available_msg_box() : handler.checkedNewFlight(::gui_start_replays)
    isHidden = @(...) !::has_feature("ClientReplay")
  }
  VIRAL_AQUISITION = {
    text = @() "#mainmenu/btnGetLink"
    onClickFunc = @(...) showViralAcquisitionWnd()
    isHidden = @(...) !::has_feature("Invites")
  }
  CHANGE_LOG = {
    text = @() "#mainmenu/btnChangelog"
    onClickFunc = @(...) openChangelog()
    isHidden = @(...) !::has_feature("Changelog") || !::isInMenu()
  }
  EXIT = {
    text = @() "#mainmenu/btnExit"
    onClickFunc = function(...) {
      ::add_msg_box("topmenu_question_quit_game", ::loc("mainmenu/questionQuitGame"),
        [
          ["yes", exitGame],
          ["no", @() null ]
        ], "no", { cancel_fn = @() null })
    }
    isHidden = @(...) !isPlatformPC && !(isPlatformSony && ::is_dev_version)
  }
  DEBUG_UNLOCK = {
    text = @() "#mainmenu/btnDebugUnlock"
    onClickFunc = @(obj, handler) ::add_msg_box("debug unlock", "Debug unlock enabled", [["ok", ::gui_do_debug_unlock]], "ok")
    isHidden = @(...) !::is_dev_version
  }
  ENCYCLOPEDIA = {
    text = @() "#mainmenu/btnEncyclopedia"
    onClickFunc = @(...) encyclopedia.open()
    isHidden = @(...) !::has_feature("Encyclopedia")
  }
  CREDITS = {
    text = @() "#mainmenu/btnCredits"
    onClickFunc = @(obj, handler) handler.checkedForward(::gui_start_credits)
    isHidden = @(handler = null) !::has_feature("Credits") || !(handler instanceof topMenuHandlerClass.getHandler())
  }
  TSS = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), ::loc("topmenu/tss"))
    onClickFunc = function(obj, handler) {
      if (checkAndShowMultiplayerPrivilegeWarning() &&
          (!needShowCrossPlayInfo() || isCrossPlayEnabled())
         )
        openUrlByObj(obj)
      else if (!::xbox_try_show_crossnetwork_message())
        ::showInfoMsgBox(::loc("xbox/actionNotAvailableCrossNetworkPlay"))
    }
    isDelayed = false
    link = "#url/tss"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || !::has_feature("Tournaments") || ::is_vendor_tencent() || ::is_me_newbie()
  }
  STREAMS_AND_REPLAYS = {
    text = @() "#topmenu/streamsAndReplays"
    onClickFunc = @(obj, handler) ::has_feature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = ::loc("topmenu/streamsAndReplays")
          baseUrl = ::loc("url/streamsAndReplays")
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = "#url/streamsAndReplays"
    isLink = @() !::has_feature("ShowUrlQrCode")
    isFeatured = @() !::has_feature("ShowUrlQrCode")
    isHidden = @(...) !::has_feature("ServerReplay") || (!::has_feature("AllowExternalLink") && !::has_feature("ShowUrlQrCode"))
       || ::is_vendor_tencent() || !::isInMenu()
  }
  EAGLES = {
    text = @() "#charServer/chapter/eagles"
    onClickFunc = @(obj, handler) ::has_feature("EnableGoldPurchase")
      ? handler.startOnlineShop("eagles", null, "topmenu")
      : ::showInfoMsgBox(::loc("msgbox/notAvailbleGoldPurchase"))
    image = @() "#ui/gameuiskin#shop_warpoints_premium"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  PREMIUM = {
    text = @() "#charServer/chapter/premium"
    onClickFunc = @(obj, handler) handler.startOnlineShop("premium")
    image = @() "#ui/gameuiskin#sub_premiumaccount"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("EnablePremiumPurchase") || !::isInMenu()
  }
  WARPOINTS = {
    text = @() "#charServer/chapter/warpoints"
    onClickFunc = @(obj, handler) handler.startOnlineShop("warpoints")
    image = @() "#ui/gameuiskin#shop_warpoints"
    needDiscountIcon = true
    isHidden = @(...) !::has_feature("SpendGold") || !::isInMenu()
  }
  INVENTORY = {
    text = @() "#items/inventory"
    onClickFunc = @(...) ::gui_start_inventory()
    image = @() "#ui/gameuiskin#inventory_icon"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu()
    unseenIcon = @() SEEN.INVENTORY
  }
  ITEMS_SHOP = {
    text = @() "#items/shop"
    onClickFunc = @(...) ::gui_start_itemsShop()
    image = @() "#ui/gameuiskin#store_icon.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu() || !::has_feature("ItemsShopInTopMenu")
    unseenIcon = @() SEEN.ITEMS_SHOP
  }
  WORKSHOP = {
    text = @() "#items/workshop"
    onClickFunc = @(...) ::gui_start_items_list(itemsTab.WORKSHOP)
    image = @() "#ui/gameuiskin#btn_modifications.svg"
    isHidden = @(...) !::ItemsManager.isEnabled() || !::isInMenu() || !workshop.isAvailable()
    unseenIcon = @() SEEN.WORKSHOP
  }
  WARBONDS_SHOP = {
    text = @() "#mainmenu/btnWarbondsShop"
    onClickFunc = @(...) ::g_warbonds.openShop()
    image = @() "#ui/gameuiskin#wb.svg"
    isHidden = @(...) !::g_battle_tasks.isAvailableForUser()
      || !::g_warbonds.isShopAvailable()
      || !::isInMenu()
    unseenIcon = @() SEEN.WARBONDS_SHOP
  }
  ONLINE_SHOP = {
    text = getEntStoreLocId
    onClickFunc = openEntStoreTopMenuFunc
    link = ""
    isLink = @() !canUseIngameShop()
    isFeatured = @() !canUseIngameShop()
    image = getEntStoreIcon
    needDiscountIcon = needEntStoreDiscountIcon
    isHidden = isEntStoreTopMenuItemHidden
    unseenIcon = getEntStoreUnseenIcon
  }
  MARKETPLACE = {
    text = @() "#mainmenu/marketplace"
    onClickFunc = @(obj, handler) goToMarketplace()
    link = ""
    isLink = @() true
    isFeatured = @() true
    image = @() "#ui/gameuiskin#gc.svg"
    isHidden = @(...) !isMarketplaceEnabled() || !::isInMenu()
  }
  COLLECTIONS = {
    text = @() "#mainmenu/btnCollections"
    onClickFunc = @(...) openCollectionsWnd()
    image = @() "#ui/gameuiskin#collection.svg"
    isHidden = @(...) !hasAvailableCollections() || !::isInMenu()
  }
  WINDOW_HELP = {
    text = @() "#flightmenu/btnControlsHelp"
    onClickFunc = function(obj, handler) {
      if (!("getWndHelpConfig" in handler))
        return

      ::gui_handlers.HelpInfoHandlerModal.open(handler.getWndHelpConfig(), handler.scene)
    }
    isHidden = @(handler = null) !("getWndHelpConfig" in handler) || !::has_feature("HangarWndHelp")
  }
  FAQ = {
    text = @() "#mainmenu/faq"
    onClickFunc = @(obj, handler) openUrlByObj(obj)
    isDelayed = false
    link = "#url/faq"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  SUPPORT = {
    text = @() "#mainmenu/support"
    onClickFunc = @(obj, handler) ::has_feature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = ::loc("mainmenu/support")
          baseUrl = ::loc("url/support")
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = "#url/support"
    isLink = @() !::has_feature("ShowUrlQrCode")
    isFeatured = @() !::has_feature("ShowUrlQrCode")
    isHidden = @(...) (!::has_feature("AllowExternalLink") && !::has_feature("ShowUrlQrCode"))
      || ::is_vendor_tencent() || !::isInMenu()
  }
  WIKI = {
    text = @() "#mainmenu/wiki"
    onClickFunc = @(obj, handler) openUrlByObj(obj)
    isDelayed = false
    link = "#url/wiki"
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !::has_feature("AllowExternalLink") || ::is_vendor_tencent() || !::isInMenu()
  }
  EULA = {
    text = @() "#mainmenu/licenseAgreement"
    onClickFunc = @(obj, handler) ::gui_start_eula(::TEXT_EULA, true)
    isDelayed = false
    isHidden = @(...) !::has_feature("EulaInMenu") || !::isInMenu()
  }
  DEBUG_PS4_SHOP_DATA = {
    text = @() "Debug PS4 Data" //intentionally without localization
    onClickFunc = function(obj, handler) {
      local itemInfo = []
      foreach (id, item in getShopItemsTable())
      {
        itemInfo.append(item.id)
        itemInfo.append(item.imagePath)
        itemInfo.append(item.getDescription())
      }
      local data = ::g_string.implode(itemInfo, "\n")
      ::dagor.debug(data)
      ::script_net_assert("PS4 Internal debug shop data")
    }
    isHidden = @(...) !::has_feature("DebugLogPS4ShopData")
  }
  EMPTY = {
    elementType = TOP_MENU_ELEMENT_TYPE.EMPTY_BUTTON
  }
  LINE_SEPARATOR = {
    elementType = TOP_MENU_ELEMENT_TYPE.LINE_SEPARATOR
  }
}

local fillButtonConfig = function(buttonCfg, name) {
  return template.__merge(buttonCfg.__merge({
    id = name.tolower()
    typeName = name
  }))
}

buttonsListWatch(list.map(fillButtonConfig))

return {
  addButtonConfig = function(newBtnConfig, name) {
    buttonsListWatch.value[name] <- fillButtonConfig(newBtnConfig, name)
  }
}
