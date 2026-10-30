import "%scripts/g_listener_priority.nut" as g_listener_priority
import "%sqStdLibs/helpers/u.nut" as u
import "DataBlock" as DataBlock
from "%scripts/unlocks/unlocksCache.nut" import getUnlockById
from "%scripts/items/itemsTypeClasses.nut" import isAddeditemTypeSmoke, createItem
from "%scripts/items/itemsConsts.nut" import itemType
from "%sqStdLibs/helpers/subscriptions.nut" import addListenersWithoutEnv
from "%appGlobals/login/loginState.nut" import hasFullLoginState
from "%sqstd/datablock.nut" import blkFromPath
from "%scripts/dagui_natives.nut" import wp_get_unlock_cost_gold
from "%scripts/dagui_library.nut" import *

let aeroSmokesList    = Watched([])
let buyableSmokesList = Watched([])

let shopSmokeItems = Computed(@() !isAddeditemTypeSmoke.get() ? []
  : buyableSmokesList.get().map(@(blk) createItem(itemType.SMOKE, blk)))


function updateBuyableSmokesList(list = null) {
  if (!hasFullLoginState.get())
    return
  let res = []
  let smokesList = list ?? aeroSmokesList.get()
  foreach (inst in smokesList) {
    if (!inst?.unlockId)
      continue
    if ((inst.unlockId == "" || getUnlockById(inst.unlockId))
      && wp_get_unlock_cost_gold(inst.unlockId) > 0)
        res.append(inst)
  }

  if (!u.isEqual(res, buyableSmokesList.get()))
    buyableSmokesList.set(res)
}

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

  updateBuyableSmokesList(smokeList)
  aeroSmokesList.set(smokeList)
}

addListenersWithoutEnv({
  LoginComplete = @(_p) updateAeroSmokeList()
  UnlocksCacheInvalidate = @(_p) updateBuyableSmokesList()
}, g_listener_priority.CONFIG_VALIDATION)

if (hasFullLoginState.get()) 
  updateAeroSmokeList()


return freeze({
  aeroSmokesList
  buyableSmokesList
  shopSmokeItems
})
