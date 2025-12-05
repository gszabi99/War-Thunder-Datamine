from "%scripts/dagui_natives.nut" import get_global_stats_blk, gather_and_build_aircrafts_list,
  debug_unlock_all, add_warpoints
from "%scripts/dagui_library.nut" import *
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let Unit = require("%scripts/unit/unit.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { updateShopCountriesList } = require("%scripts/shop/shopCountriesList.nut")
let { generateUnitShopInfo } = require("%scripts/shop/shopUnitsInfo.nut")
let { floor } = require("math")
let { get_shop_blk } = require("blkGetters")
let { register_command } = require("console")
let { usageRatingAmount } = require("%scripts/airInfo.nut")
let { isDebugModeEnabled } = require("%scripts/debugTools/dbgChecks.nut")

let allUnits = getAllUnits()

foreach (name, unit in allUnits)
  allUnits[name] = Unit({}).setFromUnit(unit)
if (showedUnit.get() != null)
  showedUnit.set(allUnits?[showedUnit.get().name])

function initAllUnits() { 
  allUnits.clear()
  let all_units_array = gather_and_build_aircrafts_list()
  foreach (unitTbl in all_units_array) {
    local unit = Unit(unitTbl)
    allUnits[unit.name] <- unit
  }
}

local usageAmountCounted = false
function countUsageAmountOnce() {
  if (usageAmountCounted)
    return

  let statsblk = get_global_stats_blk()
  if (!statsblk?.aircrafts)
    return

  let shopStatsAirs = []
  let shopBlk = get_shop_blk()

  for (local tree = 0; tree < shopBlk.blockCount(); tree++) {
    let tblk = shopBlk.getBlock(tree)
    for (local page = 0; page < tblk.blockCount(); page++) {
      let pblk = tblk.getBlock(page)
      for (local range = 0; range < pblk.blockCount(); range++) {
        let rblk = pblk.getBlock(range)
        for (local a = 0; a < rblk.blockCount(); a++) {
          let airBlk = rblk.getBlock(a)
          let stats = statsblk.aircrafts?[airBlk.getBlockName()]
          if (stats?.flyouts_factor)
            shopStatsAirs.append(stats.flyouts_factor)
        }
      }
    }
  }

  let usageRatingAmountLen = usageRatingAmount.len()
  if (shopStatsAirs.len() <= usageRatingAmountLen)
    return

  shopStatsAirs.sort(function(a, b) {
    if (a > b)
      return 1
    else if (a < b)
      return -1
    return 0;
  })

  for (local i = 0; i < usageRatingAmountLen; i++) {
    let idx = floor((i + 1).tofloat() * shopStatsAirs.len() / (usageRatingAmountLen + 1) + 0.5)
    usageRatingAmount[i] = (idx == shopStatsAirs.len() - 1) ? shopStatsAirs[idx] : 0.5 * (shopStatsAirs[idx] + shopStatsAirs[idx + 1])
  }
  usageAmountCounted = true
}

function updateAllUnits() {
  updateShopCountriesList()
  countUsageAmountOnce()
  generateUnitShopInfo()

  log("updateAllUnits called, got", allUnits.len(), "items");
}

function gui_do_debug_unlock() {
  debug_unlock_all?()
  isDebugModeEnabled.status = true
  updateAllUnits()
  add_warpoints(500000, false)
  broadcastEvent("DebugUnlockEnabled")
}

register_command(gui_do_debug_unlock, "debug.gui_do_debug_unlock")

return {
  initAllUnits
  updateAllUnits
  gui_do_debug_unlock
}