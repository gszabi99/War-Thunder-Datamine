//-file:plus-string
from "%scripts/dagui_natives.nut" import is_online_available, disable_network, shop_get_premium_account_ent_name, has_entitlement
from "%scripts/dagui_library.nut" import *

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { format } = require("string")
let { loadOnce, registerPersistentData } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
loadOnce("%appGlobals/ranks_common_shared.nut")
let { get_time_msec } = require("dagor.time")
let { shopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_wpcost_blk, get_warpoints_blk, get_ranks_blk } = require("blkGetters")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getProfileInfo, getPlayerRankByCountry, getPlayerExpByCountry
} = require("%scripts/user/userInfoStats.nut")

::max_country_rank <- 8

let ranksPersist = persist("ranksPersist", @() { max_player_rank = 100 })
let exp_per_rank = persist("exp_per_rank", @() [])
let prestige_by_rank = persist("prestige_by_rank", @() [])

::discounts <- { //count from const in warpointsBlk by (name + "Mul")
}
::event_muls <- {
  xpFirstWinInDayMul = 1.0
  wpFirstWinInDayMul = 1.0
}

registerPersistentData("RanksGlobals", getroottable(),
  [ "discounts", "event_muls" ])

::load_player_exp_table <- function load_player_exp_table() {
  let ranks_blk = get_ranks_blk()
  let efr = ranks_blk?.exp_for_playerRank

  exp_per_rank.clear()

  if (efr)
    for (local i = 0; i < efr.paramCount(); i++)
      exp_per_rank.append(efr.getParamValue(i))

  ranksPersist.max_player_rank = exp_per_rank.len()
}

::init_prestige_by_rank <- function init_prestige_by_rank() {
  let blk = get_ranks_blk()
  let prestigeByRank = blk?.prestige_by_rank

  prestige_by_rank.clear()
  if (!prestigeByRank)
    return

  for (local i = 0; i < prestigeByRank.paramCount(); i++)
    prestige_by_rank.append(prestigeByRank.getParamValue(i))
}

::get_cur_exp_table <- function get_cur_exp_table(country = "", profileData = null, rank = null, exp = null) {
  local res = null //{ exp, rankExp }
  if (rank == null)
    rank = getPlayerRankByCountry(country, profileData)
  let maxRank = (country == "") ? ranksPersist.max_player_rank : ::max_country_rank

  if (rank < maxRank) {
    let expTbl = exp_per_rank
    if (rank >= expTbl.len())
      return res

    let prev = (rank > 0) ? expTbl[rank - 1] : 0
    let next = expTbl[rank]
    local cur = (exp == null)
                ? getPlayerExpByCountry(country, profileData)
                : exp
    res = {
      rank    = rank
      exp     = cur - prev // -potentially-nulled-ops
      rankExp = next - prev
    }
  }
  return res
}

::get_rank_by_exp <- function get_rank_by_exp(exp) {
  local rank = 0
  let rankTbl = exp_per_rank
  for (local i = 0; i < rankTbl.len(); i++)
    if (exp >= rankTbl[i])
      rank++

  return rank
}

::get_prestige_by_rank <- function get_prestige_by_rank(rank) {
  for (local i = prestige_by_rank.len() - 1; i >= 0; i--)
    if (rank >= prestige_by_rank[i])
      return i
  return 0
}

let airTypes = [ES_UNIT_TYPE_AIRCRAFT, ES_UNIT_TYPE_HELICOPTER]
::get_weapon_image <- function get_weapon_image(unitType, weaponBlk, costBlk) {
  if (unitType == ES_UNIT_TYPE_TANK) {
    return costBlk?.image_tank
           ?? weaponBlk?.image_tank
           ?? costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
  else if (airTypes.contains(unitType)) {
    return costBlk?.image_aircraft
           ?? weaponBlk?.image_aircraft
           ?? costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
  else { // unitType == ES_UNIT_TYPE_INVALID
    return costBlk?.image
           ?? weaponBlk?.image
           ?? ""
  }
}

function get_aircraft_rank(curAir) {
  return get_wpcost_blk()?[curAir]?.rank ?? 0
}

let minValuesToShowRewardPremium = mkWatched(persist, "minValuesToShowRewardPremium", { wp = 0, exp = 0 })

function haveCountryRankAir(country, rank) {
  let crews = ::g_crews_list.get()
  foreach (c in crews)
    if (c.country == country)
      foreach (crew in c.crews)
        if (("aircraft" in crew) && get_aircraft_rank(crew.aircraft) >= rank)
          return true
  return false
}

//!!FIX ME: should to remove from this function all what not about unit.
function update_aircraft_warpoints(maxCallTimeMsec = 0) {
  let startTime = get_time_msec()
  let errorsTextArray = []
  foreach (unit in getAllUnits()) {
    if (unit.isInited)
      continue

    let errors = unit.initOnce()
    if (errors)
      errorsTextArray.extend(errors)

    if (maxCallTimeMsec && get_time_msec() - startTime >= maxCallTimeMsec) {
      if (errorsTextArray.len() > 0)
        logerr("\n".join(errorsTextArray))
      return PT_STEP_STATUS.SUSPEND
    }
  }

  //update discounts info
  let ws = get_warpoints_blk()
  foreach (name, _value in ::discounts)
    if (ws?[name + "DiscountMul"] != null)
      ::discounts[name] = (100.0 * (1.0 - ws[name + "DiscountMul"]) + 0.5).tointeger()

  //update bonuses info
  foreach (name, _value in ::event_muls)
    if (ws?[name] != null)
      ::event_muls[name] = ws[name]

  minValuesToShowRewardPremium({
    wp  = ws?.wp_to_show_premium_reward ?? 0
    exp = ws?.exp_to_show_premium_reward ?? 0
  })

  if (errorsTextArray.len() > 0)
    logerr("\n".join(errorsTextArray))
  return PT_STEP_STATUS.NEXT_STEP
}

function isRanksAllowed(tbl) {
  if (disable_network())
    return true

  let silent = tbl?.silent ?? false

  if ("silentFeature" in tbl)
    if (!hasFeature(tbl.silentFeature)) {
      if (!silent)
        showInfoMsgBox(loc("msgbox/notAvailbleInDemo"), "in_demo_only_feature")
      return false
    }

  if ("minLevel" in tbl)
    if (getProfileInfo().rank < tbl.minLevel) {
      if (!silent)
        showInfoMsgBox(format(loc("charServer/needRankFmt"), tbl.minLevel), "in_demo_only_minlevel")
      return false
    }

  if (("minRank" in tbl) && ("rankCountry" in tbl)) {
    let country = $"country_{tbl.rankCountry}"
    if (!haveCountryRankAir(country, tbl.minRank)) {
      if (!silent) {
        showInfoMsgBox(
          loc("charServer/needAirRankFmt", {
              tier = tbl.minRank,
              country = loc(country)
          }),
          "in_demo_only_minrank")
      }
      return false
    }
  }

  if ("unlock" in tbl)
    if (!isUnlockOpened(tbl.unlock, UNLOCKABLE_SINGLEMISSION) && !::is_debug_mode_enabled) {
      if (!silent) {
        let msg = loc("charServer/needUnlock") + "\n\n" + getFullUnlockDescByName(tbl.unlock, 1)
        showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }

  //check entitlement - this is always last
  if ("entitlement" in tbl) {
    if (has_entitlement(tbl.entitlement))
      return true
    else if (!silent && (tbl.entitlement == shop_get_premium_account_ent_name())) {
      let guiScene = get_gui_scene()
      local handler = this
      if (!handler || handler == getroottable())
        handler = get_cur_base_gui_handler()
      let askFunc = function(locText, _entitlement) {
        if (hasFeature("EnablePremiumPurchase")) {
          let text = loc($"charServer/noEntitlement/{locText}")
          handler.msgBox("no_entitlement", text,
          [
            ["yes", function() { guiScene.performDelayed(handler, function() {
                this.onOnlineShopPremium();
              }) }],
            ["no", function() {} ]
          ], "yes")
        }
        else
          scene_msg_box("premium_not_available", null, loc("charServer/notAvailableYet"),
            [["cancel"]], "cancel")
      }

      askFunc("loc" in tbl ? tbl.loc : tbl.entitlement, tbl.entitlement);
    }
    return false;
  }
  return true;
}


let playerRankByCountries = {}
function updatePlayerRankByCountries() {
  foreach (c in shopCountriesList)
    playerRankByCountries[c] <- getPlayerRankByCountry(c)
}

function updatePlayerRankByCountry(country, rank) {
  playerRankByCountries[country] <- rank
}

return {
  minValuesToShowRewardPremium
  updatePlayerRankByCountries
  updatePlayerRankByCountry
  playerRankByCountries
  isRanksAllowed
  update_aircraft_warpoints
}
