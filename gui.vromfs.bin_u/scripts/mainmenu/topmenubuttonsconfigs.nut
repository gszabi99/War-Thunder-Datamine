from "%scripts/dagui_natives.nut" import script_net_assert
from "app" import is_dev_version
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab
from "%scripts/mainConsts.nut" import SEEN

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { get_game_version_str } = require("app")
let { canUseIngameShop, getShopItemsTable, needEntStoreDiscountIcon
} = require("%scripts/onlineShop/entitlementsShopData.nut")
let { getEntStoreLocId, getEntStoreIcon, isEntStoreTopMenuItemHidden,
  getEntStoreUnseenIcon, openEntStoreTopMenuFunc
} = require("%scripts/onlineShop/entitlementsShop.nut")
let contentStateModule = require("%scripts/clientState/contentState.nut")
let workshop = require("%scripts/items/workshop/workshop.nut")
let { isPlatformSony, isPlatformPC, consoleRevision, targetPlatform
} = require("%scripts/clientState/platform.nut")
let encyclopedia = require("%scripts/encyclopedia.nut")
let { openChangelog } = require("%scripts/changelog/changeLogState.nut")
let { openUrlByObj } = require("%scripts/onlineShop/url.nut")
let { getCurCircuitOverride } = require("%appGlobals/curCircuitOverride.nut")
let openQrWindow = require("%scripts/wndLib/qrWindow.nut")
let { getTextWithCrossplayIcon, needShowCrossPlayInfo, isCrossPlayEnabled
} = require("%scripts/social/crossplay.nut")
let topMenuHandlerClass = require("%scripts/mainmenu/topMenuHandler.nut")
let { addButtonConfig } = require("%scripts/mainmenu/topMenuButtons.nut")
let exitGame = require("%scripts/utils/exitGame.nut")
let { showViralAcquisitionWnd } = require("%scripts/user/viralAcquisition.nut")
let { isMarketplaceEnabled, goToMarketplace } = require("%scripts/items/itemsMarketplace.nut")
let { openESportListWnd } = require("%scripts/events/eSportModal.nut")
let { checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning,
  isMultiplayerPrivilegeAvailable } = require("%scripts/user/xboxFeatures.nut")
let { gui_do_debug_unlock, debug_open_url } = require("%scripts/debugTools/dbgUtils.nut")
let { isShowGoldBalanceWarning } = require("%scripts/user/balanceFeatures.nut")
let { hasMultiplayerRestritionByBalance } = require("%scripts/user/balance.nut")
let { isGuestLogin } = require("%scripts/user/profileStates.nut")
let { isBattleTasksAvailable } = require("%scripts/unlocks/battleTasks.nut")
let { setShopDevMode, getShopDevMode, ShopDevModeOption } = require("%scripts/debugTools/dbgShop.nut")
let { add_msg_box } = require("%sqDagui/framework/msgBox.nut")
let { openEulaWnd } = require("%scripts/eulaWnd.nut")
let { isInMenu, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { isMeNewbie } = require("%scripts/myStats.nut")
let { gui_start_itemsShop, gui_start_inventory, gui_start_items_list
} = require("%scripts/items/startItemsShop.nut")
let { guiStartSkirmish, checkAndCreateGamemodeWnd, guiStartCampaign, guiStartBenchmark,
  guiStartTutorial
} = require("%scripts/missions/startMissionsList.nut")
let { guiStartCredits } = require("%scripts/credits.nut")
let { guiStartReplays } = require("%scripts/replays/replayScreen.nut")
let { openWishlist } = require("%scripts/wishlist/wishlistHandler.nut")
let { openModalWTAssistantlDeeplink, isExternalOperator, hasExternalAssistantDeepLink } = require("%scripts/user/wtAssistantDeeplink.nut")
let { isWorldWarEnabled, canPlayWorldwar, getCantPlayWorldwarReasonText
} = require("%scripts/globalWorldWarScripts.nut")
let { openLeaderboardWindow } = require("%scripts/leaderboard/leaderboard.nut")
let { checkPlayWorldwarAccess, openOperationsOrQueues } = require("%scripts/globalWorldwarUtils.nut")
let { isWarbondsShopAvailable, openWarbondsShop } = require("%scripts/warbonds/warbondsManager.nut")
let { queues } = require("%scripts/queue/queueManager.nut")
let { isItemsManagerEnabled } = require("%scripts/items/itemsManager.nut")
let { isAnyCampaignAvailable } = require("%scripts/missions/missionsUtils.nut")

let list = {
  SKIRMISH = {
    text = @() "#mainmenu/btnSkirmish"
    onClickFunc = function(_obj, handler) {
      if (!::check_gamemode_pkg(GM_SKIRMISH))
        return

      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      queues.checkAndStart(
        Callback(@() this.goForwardIfOnline(guiStartSkirmish, false), handler),
        null,
        "isCanNewflight"
      )
    }

    isInactiveInQueue = true
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.value
      || hasMultiplayerRestritionByBalance()
    tooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.value || hasMultiplayerRestritionByBalance())
        return loc("xbox/noMultiplayer")
      return ""
    }
  }
  WORLDWAR = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("mainmenu/btnWorldwar"))
    onClickFunc = function(_obj, handler) {
      if (!checkPlayWorldwarAccess())
        return

      queues.checkAndStart(
        Callback(@() this.goForwardIfOnline(@() openOperationsOrQueues(), false), handler),
        null,
        "isCanNewflight"
      )
    }
    tooltip = @() isWorldWarEnabled() ? getCantPlayWorldwarReasonText() : ""
    isVisualDisabled = @() isWorldWarEnabled() && !canPlayWorldwar()
    isHidden = @(...) !isWorldWarEnabled()
    isInactiveInQueue = true
    unseenIcon = @() isWorldWarEnabled() && canPlayWorldwar() ?
      SEEN.WW_MAPS_AVAILABLE : null
  }
  TUTORIAL = {
    text = @() "#mainmenu/btnTutorial"
    onClickFunc = @(_obj, handler) handler.checkedNewFlight(guiStartTutorial)
    isHidden = @(...) !hasFeature("Tutorials")
    isInactiveInQueue = true
  }
  SINGLE_MISSION = {
    text = @() "#mainmenu/btnSingleMission"
    onClickFunc = @(_obj, handler) checkAndCreateGamemodeWnd(handler, GM_SINGLE_MISSION)
    isHidden = @(...) !hasFeature("ModeSingleMissions")
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = @() "#mainmenu/btnDynamic"
    onClickFunc = @(_obj, handler) checkAndCreateGamemodeWnd(handler, GM_DYNAMIC)
    isHidden = @(...) !hasFeature("ModeDynamic")
    isInactiveInQueue = true
  }
  CAMPAIGN = {
    text = @() "#mainmenu/btnCampaign"
    onClickFunc = function(_obj, handler) {
      if (contentStateModule.isHistoricalCampaignDownloading())
        return showInfoMsgBox(loc("mainmenu/campaignDownloading"), "question_wait_download")

      if (isAnyCampaignAvailable())
        return handler.checkedNewFlight(@() guiStartCampaign())
    }
    isHidden = @(...) !hasFeature("HistoricalCampaign") || !isAnyCampaignAvailable()
    isVisualDisabled = @() contentStateModule.isHistoricalCampaignDownloading()
    isInactiveInQueue = true
  }
  TOURNAMENTS = {
    text = @() "#mainmenu/btnTournament"
    onClickFunc = function(...) {
      if (!isMultiplayerPrivilegeAvailable.value) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      openESportListWnd()
    }
    isHidden = @(...) !hasFeature("ESport")
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.value
      || hasMultiplayerRestritionByBalance()
    isInactiveInQueue = true
  }
  BENCHMARK = {
    text = @() "#mainmenu/btnBenchmark"
    onClickFunc = @(_obj, handler) handler.checkedNewFlight(guiStartBenchmark)
    isHidden = @(...) !hasFeature("Benchmark")
    isInactiveInQueue = true
  }
  USER_MISSION = {
    text = @() "#mainmenu/btnUserMission"
    onClickFunc = @(_obj, handler) checkAndCreateGamemodeWnd(handler, GM_USER_MISSION)
    isHidden = @(...) !hasFeature("UserMissions")
    isInactiveInQueue = true
  }
  LEADERBOARDS = {
    text = @() "#mainmenu/btnLeaderboards"
    onClickFunc = @(_obj, handler) handler.goForwardIfOnline(openLeaderboardWindow, false, true)
    isHidden = @(...) !hasFeature("Leaderboards")
  }
  CLANS = {
    text = @() "#mainmenu/btnClans"
    onClickFunc = @(...) hasFeature("Clans") ? loadHandler(gui_handlers.ClansModalHandler)
      : ::show_not_available_msg_box()
    isHidden = @(...) !hasFeature("Clans")
  }
  REPLAY = {
    text = @() "#mainmenu/btnReplays"
    onClickFunc = @(_obj, handler) isPlatformSony ? ::show_not_available_msg_box() : handler.checkedNewFlight(guiStartReplays)
    isHidden = @(...) !hasFeature("ClientReplay")
  }
  VIRAL_AQUISITION = {
    text = @() "#mainmenu/btnGetLink"
    onClickFunc = @(...) showViralAcquisitionWnd()
    isHidden = @(...) !hasFeature("Invites") || isGuestLogin.value
  }
  CHANGE_LOG = {
    text = @() "#mainmenu/btnChangelog"
    onClickFunc = @(...) openChangelog()
    isHidden = @(...) !hasFeature("Changelog") || !isInMenu()
  }
  EXIT = {
    text = @() "#mainmenu/btnExit"
    onClickFunc = function(...) {
      add_msg_box("topmenu_question_quit_game", loc("mainmenu/questionQuitGame"),
        [
          ["yes", exitGame],
          ["no", @() null ]
        ], "no", { cancel_fn = @() null })
    }
    isHidden = @(...) !isPlatformPC && !(isPlatformSony && is_dev_version())
  }
  DEBUG_UNLOCK = {
    text = @() "#mainmenu/btnDebugUnlock"
    onClickFunc = @(_obj, _handler) add_msg_box("debug unlock", "Debug unlock enabled", [["ok", gui_do_debug_unlock]], "ok")
    isHidden = @(...) !is_dev_version()
  }
  DEBUG_SHOP = {
    text = @() $"[DEV] Debug Shop"
    onClickFunc = function(_obj, _handler) {
      let isDevModeEnabled = !!getShopDevMode()
      let devMode = isDevModeEnabled ? null : ShopDevModeOption.SHOW_ALL_BATTLE_RATINGS
      let stateText = isDevModeEnabled ? "disabled" : "enabled"
      add_msg_box("Shop Debug", $"Shop Developer Mode: {stateText}", [["ok", @() setShopDevMode(devMode)]], "ok")
    }
    isHidden = @(...) !hasFeature("DevShopMode")
  }
  DEBUG_URL = {
    text = @() "Debug: Enter Url"
    onClickFunc = @(_obj, _handler) debug_open_url()
    isHidden = @(...) !hasFeature("DebugEnterUrl")
  }
  ENCYCLOPEDIA = {
    text = @() "#mainmenu/btnEncyclopedia"
    onClickFunc = @(...) encyclopedia.open()
    isHidden = @(...) !hasFeature("Encyclopedia")
  }
  CREDITS = {
    text = @() "#mainmenu/btnCredits"
    onClickFunc = @(_obj, handler) handler.checkedForward(guiStartCredits)
    isHidden = @(handler = null) !hasFeature("Credits") || !(handler instanceof topMenuHandlerClass.getHandler())
  }
  TSS = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("topmenu/tss"))
    onClickFunc = function(obj, _handler) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrlByObj(obj)
      else if (!isMultiplayerPrivilegeAvailable.value)
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() showInfoMsgBox(loc("xbox/actionNotAvailableCrossNetworkPlay")))
    }
    isDelayed = false
    link = @() getCurCircuitOverride("tssMainURL", loc("url/tss"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !hasFeature("Tournaments") || isMeNewbie()
  }
  REPORT_AN_ISSUE = {
    text = @() loc("topmenu/reportAnIssue")
    onClickFunc = @(obj, _handler) !isPlatformPC
      ? openQrWindow({
          headerText = loc("topmenu/reportAnIssue")
          additionalInfoText = loc("qrWindow/info/reportAnIssue")
          qrCodesData = [
            { url = getCurCircuitOverride("reportAnIssueURL", loc("url/reportAnIssue")).subst(
              { platform = consoleRevision.len() > 0 ? $"{targetPlatform}_{consoleRevision}" : targetPlatform, version = get_game_version_str() }) }
          ]
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj, true)
    isDelayed = false
    link = @() getCurCircuitOverride("reportAnIssueURL", loc("url/reportAnIssue")).subst(
      { platform = consoleRevision.len() > 0 ? $"{targetPlatform}_{consoleRevision}" : targetPlatform, version = get_game_version_str() })
    isLink = @() isPlatformPC
    isFeatured = @() true
    isHidden = @(...) !hasFeature("ReportAnIssue") || (!hasFeature("AllowExternalLink") && isPlatformPC) || !isInMenu()
  }
  STREAMS_AND_REPLAYS = {
    text = @() "#topmenu/streamsAndReplays"
    onClickFunc = @(obj, _handler) hasFeature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = loc("topmenu/streamsAndReplays")
          qrCodesData = [
            {url = getCurCircuitOverride("streamsAndReplaysURL", loc("url/streamsAndReplays"))}
          ]
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("streamsAndReplaysURL", loc("url/streamsAndReplays"))
    isLink = @() !hasFeature("ShowUrlQrCode")
    isFeatured = @() !hasFeature("ShowUrlQrCode")
    isHidden = @(...) !hasFeature("ServerReplay") || (!hasFeature("AllowExternalLink") && !hasFeature("ShowUrlQrCode"))
       || !isInMenu()
  }
  WT_ASSISTANT = {
    text = @() "#topmenu/wtAssistantDeeplink"
    onClickFunc = @(...) openModalWTAssistantlDeeplink("COMMUNITY")
    isHidden = @(...) isExternalOperator()
      ? !hasFeature("AllowWTAssistantDeeplink") || !hasExternalAssistantDeepLink()
      : !hasFeature("AllowWTAssistantDeeplink")
  }
  EAGLES = {
    text = @() "#charServer/chapter/eagles"
    onClickFunc = @(_obj, handler) hasFeature("EnableGoldPurchase")
      ? handler.startOnlineShop("eagles", null, "topmenu")
      : showInfoMsgBox(loc("msgbox/notAvailbleGoldPurchase"))
    image = @() "#ui/gameuiskin#shop_warpoints_premium.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("SpendGold") || !isInMenu()
  }
  PREMIUM = {
    text = @() "#charServer/chapter/premium"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("premium")
    image = @() "#ui/gameuiskin#sub_premiumaccount.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("EnablePremiumPurchase") || !isInMenu()
  }
  WARPOINTS = {
    text = @() "#charServer/chapter/warpoints"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("warpoints")
    image = @() "#ui/gameuiskin#shop_warpoints.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("SpendGold") || !isInMenu()
  }
  WISHLIST = {
    text = @() "#mainmenu/wishlist"
    onClickFunc = @(...) openWishlist()
    image = @() "#ui/gameuiskin#open_wishlist.svg"
    isHidden = @(...) !hasFeature("Wishlist") || !isInMenu()
  }
  INVENTORY = {
    text = @() "#items/inventory"
    onClickFunc = @(...) gui_start_inventory()
    image = @() "#ui/gameuiskin#inventory_icon.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu()
    unseenIcon = @() SEEN.INVENTORY
  }
  ITEMS_SHOP = {
    text = @() "#items/shop"
    onClickFunc = @(...) gui_start_itemsShop()
    image = @() "#ui/gameuiskin#store_icon.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu()
      || !hasFeature("ItemsShopInTopMenu")
    unseenIcon = @() SEEN.ITEMS_SHOP
  }
  WORKSHOP = {
    text = @() "#items/workshop"
    onClickFunc = @(...) gui_start_items_list(itemsTab.WORKSHOP)
    image = @() "#ui/gameuiskin#btn_modifications.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu()
      || !workshop.isAvailable()
    unseenIcon = @() SEEN.WORKSHOP
  }
  WARBONDS_SHOP = {
    text = @() "#mainmenu/btnWarbondsShop"
    onClickFunc = @(...) openWarbondsShop()
    image = @() "#ui/gameuiskin#wb.svg"
    isHidden = @(...) !isBattleTasksAvailable()
      || !isWarbondsShopAvailable()
      || !isInMenu()
    unseenIcon = @() SEEN.WARBONDS_SHOP
  }
  ONLINE_SHOP = {
    text = getEntStoreLocId
    onClickFunc = openEntStoreTopMenuFunc
    link = @()""
    isLink = @() !canUseIngameShop()
    isFeatured = @() !canUseIngameShop()
    image = getEntStoreIcon
    needDiscountIcon = needEntStoreDiscountIcon
    isHidden = @(...) isEntStoreTopMenuItemHidden()
    unseenIcon = getEntStoreUnseenIcon
  }
  MARKETPLACE = {
    text = @() "#mainmenu/marketplace"
    onClickFunc = @(_obj, _handler) goToMarketplace()
    link = @() ""
    isLink = @() true
    isFeatured = @() true
    image = @() "#ui/gameuiskin#gc.svg"
    isHidden = @(...) !isMarketplaceEnabled() || !isInMenu()
  }
  WINDOW_HELP = {
    text = @() "#flightmenu/btnControlsHelp"
    onClickFunc = function(_obj, handler) {
      if (!("getWndHelpConfig" in handler))
        return

      gui_handlers.HelpInfoHandlerModal.openHelp(handler)
    }
    isHidden = @(handler = null) !("getWndHelpConfig" in handler) || !hasFeature("HangarWndHelp")
  }
  FAQ = {
    text = @() "#mainmenu/faq"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("faqURL", loc("url/faq"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !isInMenu()
  }
  SUPPORT = {
    text = @() "#mainmenu/support"
    onClickFunc = @(obj, _handler) hasFeature("ShowUrlQrCode")
      ? openQrWindow({
          headerText = loc("mainmenu/support")
          qrCodesData = [
            {url = getCurCircuitOverride("supportURL", loc("url/support"))}
          ]
        })
      : openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("supportURL", loc("url/support"))
    isLink = @() !hasFeature("ShowUrlQrCode")
    isFeatured = @() !hasFeature("ShowUrlQrCode")
    isHidden = @(...) (!hasFeature("AllowExternalLink") && !hasFeature("ShowUrlQrCode"))
      || !isInMenu()
  }
  WIKI = {
    text = @() "#mainmenu/wiki"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("wikiURL", loc("url/wiki"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !isInMenu()
  }
  EULA = {
    text = @() "#mainmenu/licenseAgreement"
    onClickFunc = @(obj, _handler) (hasFeature("AllowExternalLink"))
      ? openUrlByObj(obj)
      : openEulaWnd()
    isDelayed = false
    link = @() getCurCircuitOverride("eulaURL", loc("url/eula"))
    isLink = @() hasFeature("AllowExternalLink")
    isFeatured = true
    isHidden = @(...) !hasFeature("EulaInMenu") || !isInMenu()
  }
  DEBUG_PS4_SHOP_DATA = {
    text = @() "Debug PS4 Data" //intentionally without localization
    onClickFunc = function(_obj, _handler) {
      let itemInfo = []
      foreach (_id, item in getShopItemsTable()) {
        itemInfo.append(item.id)
        itemInfo.append(item.imagePath)
        itemInfo.append(item.getDescription())
      }
      let data = "\n".join(itemInfo, true)
      log(data)
      script_net_assert("PS4 Internal debug shop data")
    }
    isHidden = @(...) !hasFeature("DebugLogPS4ShopData")
  }
}

list.each(addButtonConfig)
