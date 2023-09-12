//checked for plus_string
from "%scripts/dagui_library.nut" import *
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { TIME_HOUR_IN_SECONDS } = require("%sqstd/time.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsStore.nut")
let { debriefingRows } = require("%scripts/debriefing/debriefingFull.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { register_command } = require("console")
let { is_running } = require("steam")
let { request_review } = require("%xboxLib/impl/store.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")

let steamOpenReviewWnd = require("%scripts/user/steamRateGameWnd.nut")
local openReviewWnd = isPlatformXboxOne ? @(...) request_review(null)
  : is_running() ? steamOpenReviewWnd.open
  : @(...) null

let logP = log_with_prefix("[ShowRate] ")

let needShowRateWnd = persist("needShowRateWnd", @() Watched(false)) //need this, because debriefing data destroys after debriefing modal is closed

let winsInARow = persist("winsInARow", @() Watched(0))
let haveMadeKills = persist("haveMadeKills", @() Watched(false))
let havePurchasedSpecUnit = persist("havePurchasedSpecUnit", @() Watched(false))
let havePurchasedPremium = persist("havePurchasedPremium", @() Watched(false))

const RATE_WND_SAVE_ID = "seen/rateWnd"
const RATE_WND_TIME_SAVE_ID = "seen/rateWndTime"

local isConfigInited = false
let cfg = { // Overridden by gui.blk values
  totalPvpBattlesMin = 7
  totalPlayedHoursMax = 300
  minPlaceOnWin = 3
  totalWinsInARow = 3
  minKillsNum = 1
  hideSteamRateLanguages = ""
  hideSteamRateLanguagesArray = []
  reqUnlock = ""
}

let function initConfig() {
  if (isConfigInited)
    return
  isConfigInited = true

  let guiBlk = GUI.get()
  let cfgBlk = guiBlk?.suggestion_rate_game
  foreach (k, _v in cfg)
    cfg[k] = cfgBlk?[k] ?? cfg[k]
  cfg.hideSteamRateLanguagesArray = cfg.hideSteamRateLanguages.split(";")
}

let function setNeedShowRate(debriefingResult, myPlace) {
  //can be on any platform in future,
  //no need to specify platform in func name
  if ((!isPlatformXboxOne && !is_running()) || debriefingResult == null)
    return

  if (loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0)) {
    logP("Already seen by time")
    return
  }

  if (loadLocalAccountSettings(RATE_WND_SAVE_ID, false)) {
    //Save for already seen window too
    //It must not be rewritten, because of check by time before
    saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
    logP("Already seen")
    return
  }

  initConfig()

  //Record reqUnlock will be prior before other old checks
  //Because checks such as wins or sessions could be written in unlock config
  //So no need to continue check old terms
  if (cfg.reqUnlock != "") {
    logP("Check only unlock")
    if (isUnlockOpened(cfg.reqUnlock)) {
      logP("Passed by unlock")
      needShowRateWnd(true)
    }
    return
  }

  // Newbies
  if (::my_stats.getPvpPlayed() < cfg.totalPvpBattlesMin) {
    logP("Break checks by battle stats, player is newbie")
    return
  }

  // Old players
  if (!::my_stats.isStatsLoaded()
    || (::my_stats.getTotalTimePlayedSec() / TIME_HOUR_IN_SECONDS) > cfg.totalPlayedHoursMax) {
    logP("Break checks by old player, too long playing, or no stats loaded at all")
    return
  }

  let isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == GM_DOMINATION)
  if (isWin && (havePurchasedPremium.value || havePurchasedSpecUnit.value || myPlace <= cfg.minPlaceOnWin)) {
    logP($"Passed by win and prem {havePurchasedPremium.value || havePurchasedSpecUnit.value} or win and place {myPlace} condition")
    needShowRateWnd(true)
    return
  }

  if (isWin) {
    winsInARow(winsInARow.value + 1)

    local totalKills = 0
    debriefingRows.each(function(b) {
      if (b.id.contains("Kills"))
        totalKills += debriefingResult.exp?[$"num{b.id}"] ?? 0
    })

    haveMadeKills(haveMadeKills.value || totalKills >= cfg.minKillsNum)
    logP($"Update kills count {totalKills}; haveMadeKills {haveMadeKills.value}")
  }
  else {
    winsInARow(0)
    haveMadeKills(false)
  }

  if (winsInARow.value >= cfg.totalWinsInARow && haveMadeKills.value) {
    logP("Passed by wins in a row and kills")
    needShowRateWnd(true)
    return
  }
}

let function tryOpenXboxRateReviewWnd() {
  if (!isPlatformXboxOne)
    return

  openReviewWnd()
  saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "xbox" })
}

let function tryOpenSteamRateReview() {
  if (!is_running() || !hasFeature("SteamRateGame"))
    return

  if (cfg.hideSteamRateLanguagesArray.contains(::g_language.getLanguageName()))
    return

  //On Steam we already know that there will be no errors on displaying to player web page
  saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam" })

  //Send additional data if player accepted opening web page
  openReviewWnd(@(openedBrowser)
    sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", openedBrowser = openedBrowser })
  )
}

let forceOpenSteamRateReviewWnd = @() steamOpenReviewWnd.open(@(...) null)

let function checkShowRateWnd() {
  if (!needShowRateWnd.value
    || loadLocalAccountSettings(RATE_WND_SAVE_ID, false)
    || loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) > 0)
    return

  tryOpenXboxRateReviewWnd()
  tryOpenSteamRateReview()

  // in case of error, show in next launch.
  needShowRateWnd(false)
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    let unit = getAircraftByName(p?.unitName)
    if (unit && ::isUnitSpecial(unit))
      havePurchasedSpecUnit(true)
  }
  EntitlementStoreItemPurchased = function(p) {
    if (getShopItem(p?.id)?.isMultiConsumable == false) //isMultiConsumable == true - eagles
      havePurchasedSpecUnit(true)
  }
  OnlineShopPurchaseSuccessful = function(p) {
    if (p?.purchData.chapter == ONLINE_SHOP_TYPES.PREMIUM)
      havePurchasedPremium(true)
  }
})

register_command(forceOpenSteamRateReviewWnd, "debug.show_steam_rate_wnd")
register_command(tryOpenXboxRateReviewWnd, "debug.show_xbox_rate_wnd")

return {
  setNeedShowRate
  checkShowRateWnd
  tryOpenSteamRateReview
}