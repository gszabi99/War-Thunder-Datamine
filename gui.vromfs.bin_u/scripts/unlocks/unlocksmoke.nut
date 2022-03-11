local { addListenersWithoutEnv } = require("sqStdLibs/helpers/subscriptions.nut")
local { blkFromPath } = require("sqStdLibs/helpers/datablockUtils.nut")

local aeroSmokesList    = persist("aeroSmokesList", @() ::Watched([]))
local buyableSmokesList = persist("buyableSmokesList", @() ::Watched([]))

local function updateAeroSmokeList() {
  local blk = ::DataBlock()
  blk.setFrom(blkFromPath("config/fx.blk")?.aerobatics_smoke_fxs)
  if (!blk)
    return

  local locations = ["tail", "leftwing", "rightwing"]
  local smokeList = (blk % "smoke_fx").map(function(inst) {
    local res = ::DataBlock()
    res.setFrom(inst)
    res.locOrd <- -1          // Sort order by location
    foreach (idx, p in locations)
      if ((res?[p] ?? "") != "")
        res.locOrd += idx + 1 //Otherwise order is equal for tail and triple (no location)
    return res
  })

  local rarityTypes = {bronze = 0, silver = 1, gold = 2}
  smokeList.sort(@(a, b)
      (rarityTypes?[a?.rarity] ?? -1) <=> (rarityTypes?[b?.rarity] ?? -1)
        || a.locOrd <=> b.locOrd)

  aeroSmokesList(smokeList)
}

local function updateBuyableSmokesList() {
  local res = []
  foreach(inst in aeroSmokesList.value)
  {
    if (!inst?.unlockId)
      continue
    if ((inst.unlockId == "" || ::g_unlocks.getUnlockById(inst.unlockId))
      && ::wp_get_unlock_cost_gold(inst.unlockId) > 0)
        res.append(inst)
  }

  if (!::u.isEqual(res, buyableSmokesList.value))
    buyableSmokesList(res)
}

aeroSmokesList.subscribe(@(p) updateBuyableSmokesList())
addListenersWithoutEnv({
  LoginComplete = @(p) updateAeroSmokeList()
  UnlocksCacheInvalidate = @(p) updateBuyableSmokesList()
}, ::g_listener_priority.CONFIG_VALIDATION)


return {
  aeroSmokesList
  buyableSmokesList
}