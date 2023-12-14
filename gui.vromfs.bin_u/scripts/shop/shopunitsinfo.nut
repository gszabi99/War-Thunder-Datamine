from "%scripts/dagui_library.nut" import *

let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_shop_blk } = require("blkGetters")
let { isUnitDefault, isUnitGift } = require("%scripts/unit/unitInfo.nut")

let shopPromoteUnits = mkWatched(persist, "shopPromoteUnits", {})
local countDefaultUnitsByCountry = null

let function fillPromoteUnitsList(blk, unit) {
  if (blk?.beginPurchaseDate != null && blk?.endPurchaseDate != null) {
    shopPromoteUnits.mutate(@(v) v[unit.name] <- {
      unit = unit
      timeStart = getTimestampFromStringUtc(blk.beginPurchaseDate)
      timeEnd = getTimestampFromStringUtc(blk.endPurchaseDate)
    })
  }
}

let function generateUnitShopInfo() {
  let blk = get_shop_blk()
  let totalCountries = blk.blockCount()

  for (local c = 0; c < totalCountries; c++) {  //country
    let cblk = blk.getBlock(c)
    let totalPages = cblk.blockCount()

    for (local p = 0; p < totalPages; p++) {
      let pblk = cblk.getBlock(p)
      let totalRanges = pblk.blockCount()

      for (local r = 0; r < totalRanges; r++) {
        let rblk = pblk.getBlock(r)
        let totalAirs = rblk.blockCount()
        local prevAir = null

        for (local a = 0; a < totalAirs; a++) {
          let airBlk = rblk.getBlock(a)
          let airName = airBlk.getBlockName()
          local air = getAircraftByName(airName)

          if (airBlk?.reqAir != null)
            prevAir = airBlk.reqAir

          if (air) {
            air.applyShopBlk(airBlk, prevAir)
            prevAir = air.name
            fillPromoteUnitsList(airBlk, air)
          }
          else { //aircraft group
            let groupTotal = airBlk.blockCount()
            local firstIGroup = null
            let groupName = airName
            for (local ga = 0; ga < groupTotal; ga++) {
              let gAirBlk = airBlk.getBlock(ga)
              air = getAircraftByName(gAirBlk.getBlockName())
              if (!air)
                continue
              air.applyShopBlk(gAirBlk, prevAir, groupName)
              prevAir = air.name
              if (!firstIGroup)
                firstIGroup = air
              fillPromoteUnitsList(gAirBlk, air)
            }

            if (firstIGroup
                && !isUnitSpecial(firstIGroup)
                && !isUnitGift(firstIGroup))
              prevAir = firstIGroup.name
            else
              prevAir = null
          }
        }
      }
    }
  }
}

let function initCache() {
  countDefaultUnitsByCountry = {}
  foreach (u in getAllUnits()) {
    if (u.isVisibleInShop() && isUnitDefault(u))
      countDefaultUnitsByCountry[u.shopCountry] <- (countDefaultUnitsByCountry?[u.shopCountry] ?? 0) + 1
  }
}

let function invalidateCache() {
  countDefaultUnitsByCountry = null
}

let function hasDefaultUnitsInCountry(country) {
  if (countDefaultUnitsByCountry == null)
    initCache()

  return (countDefaultUnitsByCountry?[country] ?? 0) > 0
}

let function isCountryHaveUnitType(country, unitType) {
  foreach (unit in getAllUnits())
    if (unit.shopCountry == country && unit.esUnitType == unitType && unit.isVisibleInShop())
      return true
  return false
}

addListenersWithoutEnv({
  InitConfigs = @(_p) invalidateCache()
})

return {
  hasDefaultUnitsInCountry
  isCountryHaveUnitType
  generateUnitShopInfo
  shopPromoteUnits
}
