from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_shop_blk } = require("blkGetters")
let { isUnitDefault } = require("%scripts/unit/unitStatus.nut")

let shopPromoteUnits = mkWatched(persist, "shopPromoteUnits", {})
local countDefaultUnitsByCountry = null

function fillPromoteUnitsList(blk, unit) {
  if (blk?.beginPurchaseDate != null && blk?.endPurchaseDate != null) {
    shopPromoteUnits.mutate(@(v) v[unit.name] <- {
      unit = unit
      timeStart = getTimestampFromStringUtc(blk.beginPurchaseDate)
      timeEnd = getTimestampFromStringUtc(blk.endPurchaseDate)
      showMarker = true
    })
  }

  if (blk?.endResearchDate != null) {
    shopPromoteUnits.mutate(@(v) v[unit.name] <- {
      unit = unit
      timeStart = 0
      timeEnd = getTimestampFromStringUtc(blk.endResearchDate)
      showMarker = false
    })
  }
}

function generateUnitShopInfo() {
  let blk = get_shop_blk()
  let totalCountries = blk.blockCount()

  for (local c = 0; c < totalCountries; c++) {  
    let cblk = blk.getBlock(c)
    let totalPages = cblk.blockCount()

    for (local p = 0; p < totalPages; p++) {
      let pblk = cblk.getBlock(p)
      let totalRanges = pblk.blockCount()

      for (local r = 0; r < totalRanges; r++) {
        let rblk = pblk.getBlock(r)
        let totalAirs = rblk.blockCount()

        for (local a = 0; a < totalAirs; a++) {
          let airBlk = rblk.getBlock(a)
          let airName = airBlk.getBlockName()
          local air = getAircraftByName(airName)

          if (air) {
            air.applyShopBlk(airBlk)
            fillPromoteUnitsList(airBlk, air)
          }
          else { 
            let groupTotal = airBlk.blockCount()
            let groupName = airName
            for (local ga = 0; ga < groupTotal; ga++) {
              let gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                continue
              air.applyShopBlk(gAirBlk, groupName)
              fillPromoteUnitsList(gAirBlk, air)
            }
          }
        }
      }
    }
  }
}

function initCache() {
  countDefaultUnitsByCountry = {}
  foreach (u in getAllUnits()) {
    if (u.isVisibleInShop() && isUnitDefault(u))
      countDefaultUnitsByCountry[u.shopCountry] <- (countDefaultUnitsByCountry?[u.shopCountry] ?? 0) + 1
  }
}

function invalidateCache() {
  countDefaultUnitsByCountry = null
}

function hasDefaultUnitsInCountry(country) {
  if (countDefaultUnitsByCountry == null)
    initCache()

  return (countDefaultUnitsByCountry?[country] ?? 0) > 0
}

addListenersWithoutEnv({
  InitConfigs = @(_p) invalidateCache()
})

return {
  hasDefaultUnitsInCountry
  generateUnitShopInfo
  shopPromoteUnits
}
