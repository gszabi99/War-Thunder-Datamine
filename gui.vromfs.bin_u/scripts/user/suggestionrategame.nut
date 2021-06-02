local { openUrl } = require("scripts/onlineShop/url.nut")
local { isPlatformXboxOne } = require("scripts/clientState/platform.nut")
local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { getShopItem } = require("scripts/onlineShop/entitlementsStore.nut")

local log = require("std/log.nut")().with_prefix("[UserUtils] ")

local needShowRateWnd = persist("needShowRateWnd", @() ::Watched(false)) //need this, because debriefing data destroys after debriefing modal is closed

local winsInARow = persist("winsInARow", @() ::Watched(0))
local haveMadeKills = persist("haveMadeKills", @() ::Watched(false))
local havePurchasedSpecUnit = persist("havePurchasedSpecUnit", @() ::Watched(false))
local havePurchasedPremium = persist("havePurchasedPremium", @() ::Watched(false))

const TOTAL_BATTLES_CHECK = 7
const MIN_PLACE_ON_WIN = 3
const TOTAL_WINS_IN_A_ROW = 3
const MIN_KILLS_NUM = 1

const RATE_WND_SAVE_ID = "seen/rateWnd"

local function setNeedShowRate(debriefingResult, myPlace) {
  //can be on any platform in future,
  //no need to specify platform in func name
  if ((!isPlatformXboxOne && !::steam_is_running()) || debriefingResult == null)
    return

  if (::load_local_account_settings(RATE_WND_SAVE_ID, false)) {
    log("[ShowRate] Already seen")
    return
  }

  if (::my_stats.getPvpPlayed() < TOTAL_BATTLES_CHECK)
    return

  local isWin = debriefingResult?.isSucceed && (debriefingResult?.gm == ::GM_DOMINATION)
  if (isWin && (havePurchasedPremium.value || havePurchasedSpecUnit.value || myPlace <= MIN_PLACE_ON_WIN)) {
    log($"[ShowRate] Passed by win and prem {havePurchasedPremium.value || havePurchasedSpecUnit.value} or win and place {myPlace} condition")
    needShowRateWnd(true)
    return
  }

  if (isWin) {
    winsInARow(winsInARow.value+1)

    local totalKills = 0
    ::debriefing_rows.each(function(b) {
      if (b.id.contains("Kills"))
        totalKills += debriefingResult.exp?[$"num{b.id}"] ?? 0
    })

    haveMadeKills(haveMadeKills.value || totalKills >= MIN_KILLS_NUM)
    log($"[ShowRate] Update kills count {totalKills}; haveMadeKills {haveMadeKills.value}")
  }
  else {
    winsInARow(0)
    haveMadeKills(false)
  }

  if (winsInARow.value >= TOTAL_WINS_IN_A_ROW && haveMadeKills.value) {
    log("[ShowRate] Passed by wins in a row and kills")
    needShowRateWnd(true)
  }
}

local function tryOpenXboxRateReviewWnd() {
  if (isPlatformXboxOne && ::xbox_show_rate_and_review())
    ::save_local_account_settings(RATE_WND_SAVE_ID, true)
}

local function tryOpenSteamRateReview() {
  if (!::steam_is_running())
    return

  ::scene_msg_box(
    "steam_rate_review",
    null,
    ::loc("msgbox/steam/rate_review"),
    [
      ["yes", function() {
          ::save_local_account_settings(RATE_WND_SAVE_ID, true)
          openUrl(::loc("url/steam/community", {appId = ::steam_get_app_id()} ))
        }
      ],
      ["no"]
    ],
    "yes",
    { cancel_fn = @() null }
  )
}

local function checkShowRateWnd() {
  if (!needShowRateWnd.value)
    return

  tryOpenXboxRateReviewWnd()
  tryOpenSteamRateReview()

  // in case of error, show in next launch.
  needShowRateWnd(false)
}

addListenersWithoutEnv({
  UnitBought = function(p) {
    local unit = ::getAircraftByName(p?.unitName)
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

return {
  setNeedShowRate
  checkShowRateWnd
}