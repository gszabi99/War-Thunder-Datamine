from "%scripts/dagui_natives.nut" import is_online_available, disable_network, shop_get_premium_account_ent_name, has_entitlement
from "%scripts/dagui_library.nut" import *

let { loadOnce } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
loadOnce("%appGlobals/ranks_common_shared.nut")
let { get_time_msec } = require("dagor.time")
let { PT_STEP_STATUS } = require("%scripts/utils/pseudoThread.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_warpoints_blk, get_ranks_blk } = require("blkGetters")

const MAX_COUNTRY_RANK = 8

let ranksPersist = persist("ranksPersist", @() { max_player_rank = 100 })
let expPerRank = persist("expPerRank", @() [])
let prestigeByRank = persist("prestigeByRank", @() [])
let discounts = persist("discounts", @() {}) //count from const in warpointsBlk by (name + "Mul")
let eventMuls = persist("eventMuls", @() {
  xpFirstWinInDayMul = 1.0
  wpFirstWinInDayMul = 1.0
})

function loadPlayerExpTable() {
  let ranks_blk = get_ranks_blk()
  let efr = ranks_blk?.exp_for_playerRank

  expPerRank.clear()

  if (efr)
    for (local i = 0; i < efr.paramCount(); i++)
      expPerRank.append(efr.getParamValue(i))

  ranksPersist.max_player_rank = expPerRank.len()
}

function initPrestigeByRank() {
  let blk = get_ranks_blk()
  let prestigeByRankBlk = blk?.prestige_by_rank

  prestigeByRank.clear()
  if (!prestigeByRankBlk)
    return

  for (local i = 0; i < prestigeByRankBlk.paramCount(); i++)
    prestigeByRank.append(prestigeByRankBlk.getParamValue(i))
}

function getRankByExp(exp) {
  local rank = 0
  let rankTbl = expPerRank
  for (local i = 0; i < rankTbl.len(); i++)
    if (exp >= rankTbl[i])
      rank++

  return rank
}

function getPrestigeByRank(rank) {
  for (local i = prestigeByRank.len() - 1; i >= 0; i--)
    if (rank >= prestigeByRank[i])
      return i
  return 0
}

let minValuesToShowRewardPremium = mkWatched(persist, "minValuesToShowRewardPremium", { wp = 0, exp = 0 })

//!!FIX ME: should to remove from this function all what not about unit.
function updateAircraftWarpoints(maxCallTimeMsec = 0) {
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
  foreach (name, _value in discounts) {
    let k = $"{name}DiscountMul"
    if (ws?[k] != null)
      discounts[name] = (100.0 * (1.0 - ws[k]) + 0.5).tointeger()
  }
  //update bonuses info
  foreach (name, _value in eventMuls)
    if (ws?[name] != null)
      eventMuls[name] = ws[name]

  minValuesToShowRewardPremium({
    wp  = ws?.wp_to_show_premium_reward ?? 0
    exp = ws?.exp_to_show_premium_reward ?? 0
  })

  if (errorsTextArray.len() > 0)
    logerr("\n".join(errorsTextArray))
  return PT_STEP_STATUS.NEXT_STEP
}

return {
  minValuesToShowRewardPremium
  updateAircraftWarpoints
  ranksPersist
  expPerRank
  MAX_COUNTRY_RANK
  loadPlayerExpTable
  initPrestigeByRank
  getRankByExp
  getPrestigeByRank
}
