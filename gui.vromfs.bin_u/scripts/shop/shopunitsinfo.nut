from "%scripts/dagui_library.nut" import *

let { addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getTimestampFromStringUtc } = require("%scripts/time.nut")
let getAllUnits = require("%scripts/unit/allUnits.nut")
let { get_shop_blk } = require("blkGetters")
let { isUnitDefault } = require("%scripts/unit/unitStatus.nut")
let { getUnitPurchasePeriod } = require("chard")
let { isEqual } = require("%sqStdLibs/helpers/u.nut")

let shopPromoteUnits = mkWatched(persist, "shopPromoteUnits", {})
local countDefaultUnitsByCountry = null

function addUnitToPromote(unit, promoteUnits) {
  let { beginPurchaseTime, endPurchaseTime } = getUnitPurchasePeriod(unit.name)
  if (beginPurchaseTime > 0 && endPurchaseTime > 0) {
    promoteUnits[unit.name] <- {
      unit
      timeStart = beginPurchaseTime
      timeEnd = endPurchaseTime
      showMarker = true
    }
  }

  if (unit.endResearchDate != null) {
    promoteUnits[unit.name] <- {
      unit
      timeStart = 0
      timeEnd = getTimestampFromStringUtc(unit.endResearchDate)
      showMarker = false
    }
  }
}

function updateShopPromoteUnits(promoteUnits) {
  if (!isEqual(shopPromoteUnits.get(), promoteUnits))
    shopPromoteUnits.set(promoteUnits)
}

function refillPromoteUnitsList() {
  let promoteUnits = {}
  foreach (unit in getAllUnits())
    if (unit.isInShop)
      addUnitToPromote(unit, promoteUnits)

  updateShopPromoteUnits(promoteUnits)
}

function addSlaveData(arr, masterName, slaves) {
  if (slaves == null)
    return

  if (arr?[masterName] == null)
    arr[masterName] <- []

  foreach (slaveName in slaves)
    arr[masterName].append(slaveName)
}

function generateUnitShopInfo() {
  let blk = get_shop_blk()
  let totalCountries = blk.blockCount()
  let masterSlavesData = {}
  let promoteUnits = {}

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
            addUnitToPromote(air, promoteUnits)
            addSlaveData(masterSlavesData, air.name, air.slaveUnits)
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
              addUnitToPromote(air, promoteUnits)
              addSlaveData(masterSlavesData, air.name, air.slaveUnits)
            }
          }
        }
      }
    }
  }
  updateShopPromoteUnits(promoteUnits)

  foreach (masterName, slavesNames in masterSlavesData) {
    foreach (slaveName in slavesNames) {
      let slave = getAircraftByName(slaveName)
      if (!slave)
        continue
      slave.masterUnit = masterName
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
  PriceUpdated = @(_) refillPromoteUnitsList()
})

return {
  hasDefaultUnitsInCountry
  generateUnitShopInfo
  shopPromoteUnits
}
