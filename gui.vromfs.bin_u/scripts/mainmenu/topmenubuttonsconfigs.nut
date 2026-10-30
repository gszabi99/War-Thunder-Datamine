import "%scripts/clientState/contentState.nut" as contentStateModule
import "%scripts/encyclopedia.nut" as encyclopedia
import "%scripts/wndLib/qrWindow.nut" as openQrWindow
import "%scripts/utils/exitGamePlatform.nut" as exitGamePlatform
from "%scripts/help/helpInfoHandlerModal.nut" import HelpInfoHandlerModal
from "%scripts/clans/clansModalHandler.nut" import ClansModalHandler
from "%scripts/onlineShop/entitlementsShopData.nut" import canUseIngameShop, getShopItemsTable, needEntStoreDiscountIcon
from "%scripts/onlineShop/entitlementsShop.nut" import getEntStoreLocId, getEntStoreIcon, isEntStoreTopMenuItemHidden, getEntStoreUnseenIcon, openEntStoreTopMenuFunc
from "%sqstd/platform.nut" import is_gdk, isSony, isPC, consoleRevision, platformId
from "%scripts/changelog/changeLogState.nut" import openChangelog
from "%scripts/onlineShop/url.nut" import openUrlByObj
from "%scripts/social/crossplay.nut" import getTextWithCrossplayIcon, needShowCrossPlayInfo, isCrossPlayEnabled
from "%scripts/mainmenu/topMenuButtons.nut" import addButtonConfig
from "%scripts/user/viralAcquisition.nut" import showViralAcquisitionWnd
from "%scripts/items/itemsMarketplaceStatus.nut" import isMarketplaceEnabled
from "%scripts/items/itemsMarketplace.nut" import goToMarketplace
from "%scripts/events/eSportModal.nut" import openESportListWnd
from "%scripts/unlocks/specEventsHandler.nut" import openSpecEventsWnd
from "%scripts/user/xboxFeatures.nut" import checkAndShowMultiplayerPrivilegeWarning, checkAndShowCrossplayWarning, isMultiplayerPrivilegeAvailable
from "%scripts/debugTools/dbgUtils.nut" import debug_open_url
from "%scripts/unit/initUnits.nut" import gui_do_debug_unlock
from "%scripts/user/balanceFeatures.nut" import isShowGoldBalanceWarning
from "%scripts/user/balance.nut" import hasMultiplayerRestritionByBalance
from "%scripts/user/profileStates.nut" import isGuestLogin
from "%scripts/unlocks/battleTasks.nut" import isBattleTasksAvailable
from "%scripts/debugTools/dbgShop.nut" import setShopDevMode, getShopDevMode, ShopDevModeOption
from "%scripts/sqDagui/framework/msgBox.nut" import add_msg_box
from "%scripts/eulaWnd.nut" import openEulaWnd
from "%scripts/clientState/clientStates.nut" import isInMenu
from "%scripts/baseGuiHandlerManagerWT.nut" import loadHandler
from "%scripts/myStats.nut" import isMeNewbie
from "%scripts/items/startItemsShop.nut" import gui_start_itemsShop, gui_start_inventory, gui_start_items_list
from "%scripts/missions/startMissionsList.nut" import guiStartSkirmish, checkAndCreateGamemodeWnd, guiStartCampaign, guiStartBenchmark, guiStartTutorial
from "%scripts/replays/replayScreen.nut" import guiStartReplays
from "%scripts/wishlist/wishlistHandler.nut" import openWishlist
from "%scripts/user/wtAssistantDeeplink.nut" import openModalWTAssistantlDeeplink, isExternalOperator, hasExternalAssistantDeepLink
from "%scripts/globalWorldWarScripts.nut" import isWorldWarEnabled, canPlayWorldwar, getCantPlayWorldwarReasonText
from "%scripts/leaderboard/leaderboard.nut" import openLeaderboardWindow
from "%scripts/globalWorldwarUtils.nut" import checkPlayWorldwarAccess, openOperationsOrQueues
from "%scripts/warbonds/warbondsManager.nut" import isWarbondsShopAvailable, openWarbondsShop
from "%scripts/queue/queueManager.nut" import checkQueueAndStart
from "%scripts/items/itemsManager.nut" import isItemsManagerEnabled
from "%scripts/missions/missionsUtils.nut" import isAnyCampaignAvailable
from "%scripts/clientState/contentPacks.nut" import checkGamemodePkg
from "%scripts/gameModes/gameModeMesasge.nut" import showNotAvailableMsgBox
from "%scripts/licenseHandler.nut" import openLicenseWindow
from "%appGlobals/curCircuitOverride.nut" import getCurCircuitOverride
from "app" import get_game_version_str, is_dev_version
from "eventbus" import eventbus_send
from "%scripts/dagui_natives.nut" import script_net_assert
from "%globalScripts/gameModeNativeConsts.nut" import *
from "%globalScripts/loc_helpers.nut" import locByVendor
from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab
from "%scripts/seen/seenIds.nut" import SEEN
from "%scripts/debugTools/dbgXrayMode.nut" import setDebugXrayMode, isDebugXrayModeActive

let workshop = require("%scripts/items/workshop/workshop.nut")


let list = {
  SKIRMISH = {
    text = @() "#mainmenu/btnSkirmish"
    onClickFunc = function(_obj, handler) {
      if (!isMultiplayerPrivilegeAvailable.get()) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      let cbOpenMissionList = Callback(@() this.goForwardIfOnline(guiStartSkirmish, false), handler)
      checkGamemodePkg(GM_SKIRMISH, @() checkQueueAndStart(cbOpenMissionList, null, "isCanNewflight"))
    }

    isInactiveInQueue = true
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.get()
      || hasMultiplayerRestritionByBalance()
    tooltip = function() {
      if (!isMultiplayerPrivilegeAvailable.get() || hasMultiplayerRestritionByBalance())
        return loc("xbox/noMultiplayer")
      return ""
    }
  }
  WORLDWAR = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("mainmenu/btnWorldwar"))
    onClickFunc = function(_obj, handler) {
      if (!checkPlayWorldwarAccess())
        return

      checkQueueAndStart(
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
    isInactiveInQueue = true
  }
  DYNAMIC = {
    text = @() "#mainmenu/btnDynamic"
    onClickFunc = @(_obj, handler) checkAndCreateGamemodeWnd(handler, GM_DYNAMIC)
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
    isHidden = @(...) !isAnyCampaignAvailable()
    isVisualDisabled = @() contentStateModule.isHistoricalCampaignDownloading()
    isInactiveInQueue = true
  }
  TOURNAMENTS = {
    text = @() "#mainmenu/btnTournament"
    onClickFunc = function(...) {
      if (!isMultiplayerPrivilegeAvailable.get()) {
        checkAndShowMultiplayerPrivilegeWarning()
        return
      }

      if (isShowGoldBalanceWarning())
        return

      openESportListWnd()
    }
    isHidden = @(...) !hasFeature("ESport")
    isVisualDisabled = @() !isMultiplayerPrivilegeAvailable.get()
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
  }
  CLANS = {
    text = @() "#mainmenu/btnClans"
    onClickFunc = @(...) loadHandler(ClansModalHandler)
  }
  REPLAY = {
    text = @() "#mainmenu/btnReplays"
    onClickFunc = @(_obj, handler) isSony ? showNotAvailableMsgBox() : handler.checkedNewFlight(guiStartReplays)
    isHidden = @(...) !hasFeature("ClientReplay")
  }
  VIRAL_AQUISITION = {
    text = @() "#mainmenu/btnGetLink"
    onClickFunc = @(...) showViralAcquisitionWnd()
    isHidden = @(...) !hasFeature("Invites") || isGuestLogin.get()
  }
  CHANGE_LOG = {
    text = @() "#mainmenu/btnChangelog"
    onClickFunc = @(...) openChangelog()
    isHidden = @(...) !hasFeature("Changelog") || !isInMenu.get()
  }
  EXIT = {
    text = @() "#mainmenu/btnExit"
    onClickFunc = function(...) {
      add_msg_box("topmenu_question_quit_game", loc("mainmenu/questionQuitGame"),
        [
          ["yes", exitGamePlatform],
          ["no", @() null ]
        ], "no", { cancel_fn = @() null })
    }
    isHidden = @(...) !isPC && !(isSony && is_dev_version())
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
  DEBUG_XRAY_MODE = {
    text = @() $"[DEV] Debug X-ray"
    onClickFunc = function(_obj, _handler) {
      let isDbgXrayActive = isDebugXrayModeActive()
      add_msg_box("debug xray unlock", $"Debug X-ray mode {!isDbgXrayActive ? "enabled" : "disabled"}", [["ok", @() setDebugXrayMode(!isDbgXrayActive) ]], "ok")
    }
    isHidden = @(...) !hasFeature("DebugXrayMode")
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
  TSS = {
    text = @() getTextWithCrossplayIcon(needShowCrossPlayInfo(), loc("topmenu/tss"))
    onClickFunc = function(obj, _handler) {
      if (!needShowCrossPlayInfo() || isCrossPlayEnabled())
        openUrlByObj(obj)
      else if (!isMultiplayerPrivilegeAvailable.get())
        checkAndShowMultiplayerPrivilegeWarning()
      else if (!isShowGoldBalanceWarning())
        checkAndShowCrossplayWarning(@() showInfoMsgBox(locByVendor("xbox/actionNotAvailableCrossNetworkPlay")))
    }
    isDelayed = false
    link = @() getCurCircuitOverride("tssMainURL", loc("url/tss"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !hasFeature("Tournaments") || isMeNewbie()
  }
  REPORT_AN_ISSUE = {
    text = @() loc("topmenu/reportAnIssue")
    onClickFunc = @(obj, _handler) !isPC
      ? openQrWindow({
          headerText = loc("topmenu/reportAnIssue")
          additionalInfoText = loc("qrWindow/info/reportAnIssue")
          qrCodesData = [
            { url = getCurCircuitOverride("reportAnIssueURL", loc("url/reportAnIssue")).subst(
              { platform = consoleRevision.len() > 0 ? $"{platformId}_{consoleRevision}" : platformId, version = get_game_version_str() }) }
          ]
          needUrlWithQrRedirect = true
        })
      : openUrlByObj(obj, true)
    isDelayed = false
    link = @() getCurCircuitOverride("reportAnIssueURL", loc("url/reportAnIssue")).subst({
      platform = consoleRevision.len() > 0 ? $"{platformId}_{consoleRevision}"
        : is_gdk ? "pc_ms_live"
        : platformId
      version = get_game_version_str()
    })
    isLink = @() isPC
    isFeatured = @() true
    isHidden = @(...) !hasFeature("ReportAnIssue") || (!hasFeature("AllowExternalLink") && isPC) || !isInMenu.get()
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
       || !isInMenu.get()
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
    isHidden = @(...) !hasFeature("SpendGold") || !isInMenu.get()
  }
  PREMIUM = {
    text = @() "#charServer/chapter/premium"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("premium")
    image = @() "#ui/gameuiskin#sub_premiumaccount.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("EnablePremiumPurchase") || !isInMenu.get()
  }
  WARPOINTS = {
    text = @() "#charServer/chapter/warpoints"
    onClickFunc = @(_obj, handler) handler.startOnlineShop("warpoints")
    image = @() "#ui/gameuiskin#shop_warpoints.svg"
    needDiscountIcon = true
    isHidden = @(...) !hasFeature("SpendGold") || !isInMenu.get()
  }
  WISHLIST = {
    text = @() "#mainmenu/wishlist"
    onClickFunc = @(...) openWishlist()
    image = @() "#ui/gameuiskin#open_wishlist.svg"
    isHidden = @(...) !hasFeature("Wishlist") || !isInMenu.get()
  }
  INVENTORY = {
    text = @() "#items/inventory"
    onClickFunc = @(...) gui_start_inventory()
    image = @() "#ui/gameuiskin#inventory_icon.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu.get()
    unseenIcon = @() SEEN.INVENTORY
  }
  ITEMS_SHOP = {
    text = @() "#items/shop"
    onClickFunc = @(...) gui_start_itemsShop()
    image = @() "#ui/gameuiskin#store_icon.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu.get()
      || !hasFeature("ItemsShopInTopMenu")
    unseenIcon = @() SEEN.ITEMS_SHOP
  }
  WORKSHOP = {
    text = @() "#items/workshop"
    onClickFunc = @(...) gui_start_items_list(itemsTab.WORKSHOP)
    image = @() "#ui/gameuiskin#btn_modifications.svg"
    isHidden = @(...) !isItemsManagerEnabled() || !isInMenu.get()
      || !workshop.isAvailable()
    unseenIcon = @() SEEN.WORKSHOP
  }
  WARBONDS_SHOP = {
    text = @() "#mainmenu/btnWarbondsShop"
    onClickFunc = @(...) openWarbondsShop()
    image = @() "#ui/gameuiskin#wb.svg"
    isHidden = @(...) !isBattleTasksAvailable()
      || !isWarbondsShopAvailable()
      || !isInMenu.get()
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
    isHidden = @(...) !isMarketplaceEnabled() || !isInMenu.get()
  }
  SPEC_EVENTS = {
    text = @() "#mainmenu/btnSpecEvents"
    onClickFunc = @(_obj, _handler) openSpecEventsWnd()
    isHidden = @(...) !hasFeature("HasSpecialEventWindow") || !isInMenu.get()
    image = @() "#ui/gameuiskin#event_hub_icon.svg"
  }








  WINDOW_HELP = {
    text = @() "#flightmenu/btnControlsHelp"
    onClickFunc = function(_obj, handler) {
      if (!("getWndHelpConfig" in handler))
        return

      HelpInfoHandlerModal.openHelp(handler)
    }
    isHidden = @(handler = null) !("getWndHelpConfig" in handler)
  }
  FAQ = {
    text = @() "#mainmenu/faq"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("faqURL", loc("url/faq"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !isInMenu.get()
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
      || !isInMenu.get()
  }
  WIKI = {
    text = @() "#mainmenu/wiki"
    onClickFunc = @(obj, _handler) openUrlByObj(obj)
    isDelayed = false
    link = @() getCurCircuitOverride("wikiURL", loc("url/wiki"))
    isLink = @() true
    isFeatured = @() true
    isHidden = @(...) !hasFeature("AllowExternalLink") || !isInMenu.get()
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
    isHidden = @(...) !isInMenu.get()
  }

  LICENSE = {
    text = @() "#mainmenu/license"
    onClickFunc = @(_obj, _handler) openLicenseWindow()
    isHidden = @(...) !isInMenu.get()
  }

  DEBUG_PS4_SHOP_DATA = {
    text = @() "Debug PS4 Data" 
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
