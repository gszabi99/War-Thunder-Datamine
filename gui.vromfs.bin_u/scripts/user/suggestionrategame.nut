from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { TIME_HOUR_IN_SECONDS } = require("%sqstd/time.nut")
let { getShopItem } = require("%scripts/onlineShop/entitlementsStore.nut")
let steamRateGameWnd = require("steamRateGameWnd.nut")
let { debriefingRows } = require("%scripts/debriefing/debriefingFull.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let { register_command } = require("console")

let logP = log_with_prefix("[ShowRate] ")

let needShowRateWnd = persist("needShowRateWnd", @() Watched(false)) //need this, because debriefing data destroys after debriefing modal is closed

let winsInARow = persist("winsInARow", @() Watched(0))
let haveMadeKills = persist("haveMadeKills", @() Watched(false))
let havePurchasedSpecUnit = persist("havePurchasedSpecUnit", @() Watched(false))
let havePurchasedPremium = persist("havePurchasedPremium", @() Watched(false))

const RATE_WND_SAVE_ID = "seen/rateWnd"

local isConfigInited = false
let cfg = { // Overridden by gui.blk values
  totalPvpBattlesMin = 7
  totalPlayedHoursMax = 300
  minPlaceOnWin = 3
  totalWinsInARow = 3
  minKillsNum = 1
  hideSteamRateLanguages = ""
  hideSteamRateLanguagesArray = []
  sessionsPlayedAfterRewardReceived = ""
  sessionsPlayedAfterRewardReceivedArray = []
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
  cfg.sessionsPlayedAfterRewardReceivedArray = cfg.sessionsPlayedAfterRewardReceived.split(";")
}

let function isEnoughBattlesPlayedAfterReceivedReward() {
  if (cfg.sessionsPlayedAfterRewardReceivedArray.len() < 2)
    return false

  let rewardId = cfg.sessionsPlayedAfterRewardReceivedArray[0]
  local battlesCount = cfg.sessionsPlayedAfterRewardReceivedArray[1].tointeger()
  let total = ::get_user_logs_count()
  let blk = ::DataBlock()
  local battlesAfterTrophy = 0
  local needCheckBattles = false
  for (local i = total-1; i >= 0; i--)
  {
    ::get_user_log_blk_body(i, blk)

    if (blk?.type == EULT_SESSION_RESULT)
      battlesAfterTrophy++

    if (!needCheckBattles && (blk?.body?.itemDefId == rewardId.tointeger()
        || blk?.body?.trophyItemDefId == rewardId.tointeger()
        || blk?.body?.id == rewardId)) {
      needCheckBattles = true
    }

    if (needCheckBattles)
      return battlesAfterTrophy >= battlesCount

    blk.reset()
  }

  return false
}

let function setNeedShowRate(debriefingResult, myPlace) {
  //can be on any platform in future,
  //no need to specify platform in func name
  if ((!isPlatformXboxOne && !::steam_is_running()) || debriefingResult == null)
    return

  if (::load_local_account_settings(RATE_WND_SAVE_ID, false)) {
    logP("Already seen")
    return
  }

  initConfig()

  if (::my_stats.getPvpPlayed() < cfg.totalPvpBattlesMin) // Newbies
    return
  if (!::my_stats.isStatsLoaded() || (::my_stats.getTotalTimePlayedSec() / TIME_HOUR_IN_SECONDS) > cfg.totalPlayedHoursMax) // Old players
    return

  let isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == GM_DOMINATION)
  if (isWin && (havePurchasedPremium.value || havePurchasedSpecUnit.value || myPlace <= cfg.minPlaceOnWin)) {
    logP($"Passed by win and prem {havePurchasedPremium.value || havePurchasedSpecUnit.value} or win and place {myPlace} condition")
    needShowRateWnd(true)
    return
  }

  if (isWin) {
    winsInARow(winsInARow.value+1)

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

  if (isEnoughBattlesPlayedAfterReceivedReward()) {
    logP("Passed by battles count after received reward")
    needShowRateWnd(true)
  }
}

let function tryOpenXboxRateReviewWnd() {
  if (isPlatformXboxOne && ::xbox_show_rate_and_review())
  {
    ::save_local_account_settings(RATE_WND_SAVE_ID, true)
    ::add_big_query_record("rate", "xbox")
  }
}

let function tryOpenSteamRateReview(forceShow = false) {
  if (!forceShow && (!::steam_is_running() || !hasFeature("SteamRateGame")))
    return

  if (!forceShow && cfg.hideSteamRateLanguagesArray.contains(::g_language.getLanguageName()))
    return

  ::save_local_account_settings(RATE_WND_SAVE_ID, true)
  ::add_big_query_record("rate", "steam")
  steamRateGameWnd.open()
}

let function checkShowRateWnd() {
  if (!needShowRateWnd.value || ::load_local_account_settings(RATE_WND_SAVE_ID, false))
    return

  tryOpenXboxRateReviewWnd()
  tryOpenSteamRateReview()

  // in case of error, show in next launch.
  needShowRateWnd(false)
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    let unit = ::getAircraftByName(p?.unitName)
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

register_command(@() tryOpenSteamRateReview(true), "debug.show_steam_rate_wnd")

return {
  setNeedShowRate
  checkShowRateWnd
  tryOpenSteamRateReview
}