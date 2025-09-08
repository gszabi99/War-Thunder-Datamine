from "%scripts/dagui_library.nut" import *
from "%scripts/onlineShop/onlineShopConsts.nut" import ONLINE_SHOP_TYPES

let { is_gdk } = require("%sqstd/platform.nut")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { TIME_HOUR_IN_SECONDS, daysToSeconds, minutesToSeconds } = require("%sqstd/time.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsShopData.nut")
let { debriefingRows } = require("%scripts/debriefing/debriefingFull.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { register_command } = require("console")
let { steam_is_running } = require("steam")
let { request_review } = require("%gdkLib/impl/store.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { get_charserver_time_sec } = require("chard")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let steamOpenReviewWnd = require("%scripts/user/steamRateGameWnd.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { isStatsLoaded, getPvpPlayed, getTotalTimePlayedSec } = require("%scripts/myStats.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { rnd_int, frnd } = require("dagor.random")

let logP = log_with_prefix("[ShowRate] ")
let needShowRateWnd = mkWatched(persist, "needShowRateWnd", false) 

let winsInARow = mkWatched(persist, "winsInARow", 0)
let haveMadeKills = mkWatched(persist, "haveMadeKills", false)
let havePurchasedSpecUnit = mkWatched(persist, "havePurchasedSpecUnit", false)
let havePurchasedPremium = mkWatched(persist, "havePurchasedPremium", false)

const RATE_WND_SAVE_ID = "seen/rateWnd"
const RATE_WND_TIME_SAVE_ID = "seen/rateWndTime"

let configSteamReviewWnd = {
  SteamRateGame = {
    wndTimeSaveId = RATE_WND_TIME_SAVE_ID
    feedbackRateSaveId = "seen/feedbackRateWnd"
    showWndCountSaveId = "seen/rateWndShowCount"
    bqKey = "SteamRateGame"
    feature = "SteamRateGame"
    descLocId = "msgbox/steam/rate_review_short"
    backgroundImg = "#ui/images/kittens"
    backgroundImgRatio = 1080.0/1920
    canReShow = true
  }
  SteamRateImprove = {
    wndTimeSaveId = "seen/afterImprovementRateWndTime"
    feedbackRateSaveId = "seen/feedbackAfterImprovementRateWnd"
    feature = "SteamRateImprove"
    descLocId = "msgbox/steam/rate_review_after_improve"
    backgroundImg = "#ui/images/kittens"
    backgroundImgRatio = 1080.0/1920
  }
  SteamRateMoreImprove = {
    wndTimeSaveId = "seen/moreImprovementRateWndTime"
    feedbackRateSaveId = "seen/feedbackMoreImprovementRateWnd"
    feature = "SteamRateMoreImprove"
    descLocId = "msgbox/steam/rate_review_more_improvement"
    backgroundImg = "#ui/images/kittens"
    backgroundImgRatio = 1080.0/1920
  }
}

let regularSteamRateReview = [
  configSteamReviewWnd.SteamRateGame,
]

let sortedAdditionalSteamRateReview = [
  configSteamReviewWnd.SteamRateMoreImprove,
  configSteamReviewWnd.SteamRateImprove,
]

local isConfigInited = false
let cfg = { 
  totalPvpBattlesMin = 7
  totalPlayedHoursMax = 300
  minPlaceOnWin = 3
  totalWinsInARow = 3
  minKillsNum = 1
  hideSteamRateLanguages = ""
  hideSteamRateLanguagesArray = []
  reqUnlock = ""

  reShowInDays = 0
  reShowInSec = 0
  reShowChancePercent = 10
  totalPlayedHoursMaxReShow = null
  showPromoblockTimeMin = 1440
}

function initConfig() {
  if (isConfigInited)
    return
  isConfigInited = true

  let guiBlk = GUI.get()
  let cfgBlk = guiBlk?.suggestion_rate_game
  foreach (k, _v in cfg)
    cfg[k] = cfgBlk?[k] ?? cfg[k]
  cfg.hideSteamRateLanguagesArray = cfg.hideSteamRateLanguages.split(";")
  cfg.reShowInSec = daysToSeconds(cfg.reShowInDays)
}

function needShowRateForSteam() {
  if (!steam_is_running())
    return false

  initConfig()
  let { reShowInSec } = cfg
  foreach (config in configSteamReviewWnd) {
    let { feedbackRateSaveId, wndTimeSaveId, canReShow = false } = config
    let seenTime = loadLocalAccountSettings(wndTimeSaveId, 0)
    let hasFeedBack = loadLocalAccountSettings(feedbackRateSaveId, true)

    if (seenTime > 0 && hasFeedBack) {
      logP("Already seen and feedback")
      return false
    }
    if (seenTime > 0 && canReShow
        && (reShowInSec == 0 || (seenTime + reShowInSec) > get_charserver_time_sec())) {
      logP("Already seen")
      return false
    }
  }
  return true
}

let needShowRateForXbox = @() is_gdk && loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) == 0

function setNeedShowRate(debriefingResult, myPlace) {
  
  
  if ((!needShowRateForXbox() && !needShowRateForSteam()) || debriefingResult == null)
    return

  let seenTime = loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0)
  if (loadLocalAccountSettings(RATE_WND_SAVE_ID, false) && seenTime == 0) {
    
    saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
    saveLocalAccountSettings(RATE_WND_SAVE_ID, null)
    logP("Already seen")
    return
  }

  initConfig()

  
  
  
  if (cfg.reqUnlock != "") {
    logP("Check only unlock")
    if (isUnlockOpened(cfg.reqUnlock)) {
      logP("Passed by unlock")
      needShowRateWnd.set(true)
    }
    return
  }

  
  if (getPvpPlayed() < cfg.totalPvpBattlesMin) {
    logP("Break checks by battle stats, player is newbie")
    return
  }

  
  let { totalPlayedHoursMax, totalPlayedHoursMaxReShow } = cfg
  let totalPlayedHoursMaxForCheck = seenTime == 0 ? totalPlayedHoursMax
    : totalPlayedHoursMaxReShow ?? totalPlayedHoursMax
  if (!isStatsLoaded()
      || (getTotalTimePlayedSec() / TIME_HOUR_IN_SECONDS) > totalPlayedHoursMaxForCheck) {
    logP("Break checks by old player, too long playing, or no stats loaded at all")
    return
  }

  let isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == GM_DOMINATION)
  if (isWin && (havePurchasedPremium.get() || havePurchasedSpecUnit.get() || myPlace <= cfg.minPlaceOnWin)) {
    logP($"Passed by win and prem {havePurchasedPremium.get() || havePurchasedSpecUnit.get()} or win and place {myPlace} condition")
    needShowRateWnd.set(true)
    return
  }

  if (isWin) {
    winsInARow.set(winsInARow.get() + 1)

    local totalKills = 0
    debriefingRows.each(function(b) {
      if (b.id.contains("Kills"))
        totalKills += debriefingResult.exp?[$"num{b.id}"] ?? 0
    })

    haveMadeKills.set(haveMadeKills.get() || totalKills >= cfg.minKillsNum)
    logP($"Update kills count {totalKills}; haveMadeKills {haveMadeKills.get()}")
  }
  else {
    winsInARow.set(0)
    haveMadeKills.set(false)
  }

  if (winsInARow.get() >= cfg.totalWinsInARow && haveMadeKills.get()) {
    logP("Passed by wins in a row and kills")
    needShowRateWnd.set(true)
    return
  }
}

function tryOpenXboxRateReviewWnd() {
  if (!is_gdk || loadLocalAccountSettings(RATE_WND_TIME_SAVE_ID, 0) > 0)
    return false

  saveLocalAccountSettings(RATE_WND_TIME_SAVE_ID, get_charserver_time_sec())
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "xbox" })
  request_review(null)
  return true
}

function implOpenSteamRateReview(popupConfig, externalReason = null) {
  let { feedbackRateSaveId, feature, descLocId,
    backgroundImg = null, bqKey = null, backgroundImgRatio = 1, showWndCountSaveId = null } = popupConfig
  let reason = externalReason ?? bqKey ?? feature
  let count = showWndCountSaveId == null ? 1
   : loadLocalAccountSettings(showWndCountSaveId, 1)
  sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", reason, count })
  steamOpenReviewWnd.open({
    descLocId
    backgroundImg
    backgroundImgRatio
    reason
    onApplyFunc = function(openedBrowser) {
      saveLocalAccountSettings(feedbackRateSaveId, openedBrowser)
      sendBqEvent("CLIENT_POPUP_1", "rate", { from = "steam", openedBrowser, reason, count })
    }
  })
}

function tryOpenSteamRateReview(popupConfig) {
  let { wndTimeSaveId, feature, showWndCountSaveId = null, canReShow = false } = popupConfig
  let seenTime = loadLocalAccountSettings(wndTimeSaveId, 0)
  if (!hasFeature(feature) || (seenTime > 0 && !canReShow))
    return false

  if (seenTime > 0 && canReShow) {
    let needShowLater = clamp((frnd() * 100).tointeger(), 0, 100) <= cfg.reShowChancePercent
    if (needShowLater) {
      saveLocalAccountSettings(wndTimeSaveId, get_charserver_time_sec())
      return false
    }
    if (showWndCountSaveId != null) {
      let newCount = loadLocalAccountSettings(showWndCountSaveId, 1) + 1
      saveLocalAccountSettings(showWndCountSaveId, newCount)
    }
  }
  saveLocalAccountSettings(wndTimeSaveId, get_charserver_time_sec())
  implOpenSteamRateReview(popupConfig)
  return true
}

function openSteamRateReviewFromPromoBlock(popupConfig) {
  let { feature, bqKey = null } = popupConfig
  let reason = $"{bqKey ?? feature}FromPromoblock"
  implOpenSteamRateReview(popupConfig, reason)
  return true
}

function checkShowRateWnd() {
  if (needShowRateWnd.get() && is_gdk) {
    tryOpenXboxRateReviewWnd()
    needShowRateWnd.set(false)
    return
  }

  if (!steam_is_running())
    return
  if (cfg.hideSteamRateLanguagesArray.contains(getLanguageName()))
    return

  foreach (config in sortedAdditionalSteamRateReview)
    if (tryOpenSteamRateReview(config))
      return
  if (!needShowRateWnd.get())
    return

  let rateGameCount = regularSteamRateReview.len()
  let idx = rateGameCount > 1 ? rnd_int(0, rateGameCount - 1)
    : 0
  tryOpenSteamRateReview(regularSteamRateReview[idx])
  needShowRateWnd.set(false)
}

function updateSteamReviewBtnVisible() {
  if (!steam_is_running())
    return
  updateExtWatched({ canShowSteamReviewBtn = hasFeature("SteamReviewBtnInChangelog") })
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    let unit = getAircraftByName(p?.unitName)
    if (unit && isUnitSpecial(unit))
      havePurchasedSpecUnit.set(true)
  }
  EntitlementStoreItemPurchased = function(p) {
    if (getShopItem(p?.id)?.isMultiConsumable == false) 
      havePurchasedSpecUnit.set(true)
  }
  OnlineShopPurchaseSuccessful = function(p) {
    if (p?.purchData.chapter == ONLINE_SHOP_TYPES.PREMIUM)
      havePurchasedPremium.set(true)
  }
  ProfileUpdated = @(_p) updateSteamReviewBtnVisible()
})

register_command(
  @(feature) implOpenSteamRateReview(configSteamReviewWnd?[feature] ?? configSteamReviewWnd.SteamRateGame),
  "debug.show_steam_rate_wnd")
register_command(tryOpenXboxRateReviewWnd, "debug.show_xbox_rate_wnd")

addPromoAction("steam_popup",
  function(_handler, params, _obj) {
    let popupId = params?[0] ?? ""
    if (popupId in configSteamReviewWnd)
      openSteamRateReviewFromPromoBlock(configSteamReviewWnd[popupId])
  },
  function(params) {
    let popupId = params?[0] ?? ""
    if (popupId not in configSteamReviewWnd)
      return false
    let { wndTimeSaveId, feedbackRateSaveId } = configSteamReviewWnd[popupId]
    let showPromoblockTimeSec = minutesToSeconds(cfg.showPromoblockTimeMin)
    let seenTime = loadLocalAccountSettings(wndTimeSaveId, 0)
    return seenTime > 0
      && (seenTime + showPromoblockTimeSec) >= get_charserver_time_sec()
      && !loadLocalAccountSettings(feedbackRateSaveId, true)
  }
)

return {
  setNeedShowRate
  checkShowRateWnd
  tryOpenSteamRateReview
}