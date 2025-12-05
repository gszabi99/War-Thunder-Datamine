from "%scripts/dagui_library.nut" import *
let DataBlock = require("DataBlock")

let randomUnitsForceWeaponCache = persist("randomUnitsForceWeaponCache", @() {})

function cacheRandomUnitsForceWeapon() {
  let gameplayBlk = DataBlock()

  gameplayBlk.tryLoad("config/gameplay.blk")
  let randomSpawnUnits = gameplayBlk?["RandomSpawnUnits"]
  if (randomSpawnUnits == null)
    return

  let eventsCount = randomSpawnUnits.blockCount()
  for (local e = 0; e < eventsCount; e++) {
    let event = randomSpawnUnits.getBlock(e)
    let eventName = event.getBlockName()

    if (eventName not in randomUnitsForceWeaponCache)
      randomUnitsForceWeaponCache[eventName] <- {}

    let countryCount = event.blockCount()
    for (local c = 0; c < countryCount; c++) {
      let countryData = event.getBlock(c)
      let unitTypeCount = countryData.blockCount()
      for (local t = 0; t < unitTypeCount; t++) {
        let unitTypeData = countryData.getBlock(t)
        let unitsCount = unitTypeData.blockCount()
        for (local u = 0; u < unitsCount; u++) {
          let unitData = unitTypeData.getBlock(u)
          let unitName = unitData.getBlockName()
          if (unitData?.forceWeapon != null && unitName not in randomUnitsForceWeaponCache[eventName])
            randomUnitsForceWeaponCache[eventName][unitName] <- unitData.forceWeapon
        }
      }
    }
  }
}

function getRandomUnitsForceWeapon(eventName, unitName) {
  if (randomUnitsForceWeaponCache.len() == 0)
    cacheRandomUnitsForceWeapon()

  return randomUnitsForceWeaponCache?[eventName][unitName]
}

return {
  getRandomUnitsForceWeapon
}