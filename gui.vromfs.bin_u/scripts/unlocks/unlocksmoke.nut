//checked for plus_string
from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let DataBlock = require("DataBlock")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { blkFromPath } = require("%sqStdLibs/helpers/datablockUtils.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")

let aeroSmokesList    = persist("aeroSmokesList", @() Watched([]))
let buyableSmokesList = persist("buyableSmokesList", @() Watched([]))

let function updateAeroSmokeList() {
  let blk = DataBlock()
  blk.setFrom(blkFromPath("config/fx.blk")?.aerobatics_smoke_fxs)
  if (!blk)
    return

  let locations = ["tail", "leftwing", "rightwing"]
  let smokeList = (blk % "smoke_fx").map(function(inst) {
    let res = DataBlock()
    res.setFrom(inst)
    res.locOrd <- -1          // Sort order by location
    foreach (idx, p in locations)
      if ((res?[p] ?? "") != "")
        res.locOrd += idx + 1 //Otherwise order is equal for tail and triple (no location)
    return res
  })

  let rarityTypes = { bronze = 0, silver = 1, gold = 2 }
  smokeList.sort(@(a, b)
      (rarityTypes?[a?.rarity] ?? -1) <=> (rarityTypes?[b?.rarity] ?? -1)
        || a.locOrd <=> b.locOrd)

  aeroSmokesList(smokeList)
}

let function updateBuyableSmokesList() {
  let res = []
  foreach (inst in aeroSmokesList.value) {
    if (!inst?.unlockId)
      continue
    if ((inst.unlockId == "" || getUnlockById(inst.unlockId))
      && ::wp_get_unlock_cost_gold(inst.unlockId) > 0)
        res.append(inst)
  }

  if (!::u.isEqual(res, buyableSmokesList.value))
    buyableSmokesList(res)
}

aeroSmokesList.subscribe(@(_p) updateBuyableSmokesList())
addListenersWithoutEnv({
  LoginComplete = @(_p) updateAeroSmokeList()
  UnlocksCacheInvalidate = @(_p) updateBuyableSmokesList()
}, ::g_listener_priority.CONFIG_VALIDATION)


return {
  aeroSmokesList
  buyableSmokesList
}