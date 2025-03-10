from "%scripts/dagui_natives.nut" import disable_network, shop_get_premium_account_ent_name, has_entitlement
from "%scripts/dagui_library.nut" import *

let { isUnlockOpened } = require("%scripts/unlocks/unlocksModule.nut")
let { format } = require("string")
let { getFullUnlockDescByName } = require("%scripts/unlocks/unlocksViewModule.nut")
let { get_cur_base_gui_handler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getProfileInfo } = require("%scripts/user/userInfoStats.nut")
let { getCrewsList } = require("%scripts/slotbar/crewsList.nut")
let { get_wpcost_blk } = require("blkGetters")


function getAircraftRank(curAir) {
  return get_wpcost_blk()?[curAir]?.rank ?? 0
}

function haveCountryRankAir(country, rank) {
  let crews = getCrewsList()
  foreach (c in crews)
    if (c.country == country)
      foreach (crew in c.crews)
        if (("aircraft" in crew) && getAircraftRank(crew.aircraft) >= rank)
          return true
  return false
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
        let msg = "".concat(loc("charServer/needUnlock"), "\n\n", getFullUnlockDescByName(tbl.unlock, 1))
        showInfoMsgBox(msg, "in_demo_only_singlemission_unlock")
      }
      return false
    }

  
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
                this.onOnlineShopPremium()
              }) }],
            ["no", function() {} ]
          ], "yes")
        }
        else
          scene_msg_box("premium_not_available", null, loc("charServer/notAvailableYet"),
            [["cancel"]], "cancel")
      }

      askFunc("loc" in tbl ? tbl.loc : tbl.entitlement, tbl.entitlement)
    }
    return false
  }
  return true
}

return {
  isRanksAllowed
}