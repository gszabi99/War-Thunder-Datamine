from "%scripts/dagui_natives.nut" import wp_get_unlock_cost_gold
from "%scripts/dagui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let DataBlock = require("DataBlock")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { blkFromPath } = require("%sqstd/datablock.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")

let aeroSmokesList    = mkWatched(persist, "aeroSmokesList", [])
let buyableSmokesList = mkWatched(persist, "buyableSmokesList", [])

function updateAeroSmokeList() {
  let blk = DataBlock()
  blk.setFrom(blkFromPath("config/fx.blk")?.aerobatics_smoke_fxs)
  if (!blk)
    return

  let locations = ["tail", "leftwing", "rightwing"]
  let smokeList = (blk % "smoke_fx").map(function(inst) {
    let res = DataBlock()
    res.setFrom(inst)
    res.locOrd <- -1          
    foreach (idx, p in locations)
      if ((res?[p] ?? "") != "")
        res.locOrd += idx + 1 
    return res
  })

  let rarityTypes = { bronze = 0, silver = 1, gold = 2 }
  smokeList.sort(@(a, b)
      (rarityTypes?[a?.rarity] ?? -1) <=> (rarityTypes?[b?.rarity] ?? -1)
        || a.locOrd <=> b.locOrd)

  aeroSmokesList.set(smokeList)
}

function updateBuyableSmokesList() {
  if (!isLoggedIn.get())
    return
  let res = []
  foreach (inst in aeroSmokesList.get()) {
    if (!inst?.unlockId)
      continue
    if ((inst.unlockId == "" || getUnlockById(inst.unlockId))
      && wp_get_unlock_cost_gold(inst.unlockId) > 0)
        res.append(inst)
  }

  if (!u.isEqual(res, buyableSmokesList.get()))
    buyableSmokesList(res)
}

aeroSmokesList.subscribe(@(_p) updateBuyableSmokesList())
addListenersWithoutEnv({
  LoginComplete = @(_p) updateAeroSmokeList()
  UnlocksCacheInvalidate = @(_p) updateBuyableSmokesList()
}, g_listener_priority.CONFIG_VALIDATION)


return {
  aeroSmokesList
  buyableSmokesList
}