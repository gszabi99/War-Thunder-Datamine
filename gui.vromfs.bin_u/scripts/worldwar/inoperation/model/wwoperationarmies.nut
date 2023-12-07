from "%scripts/dagui_library.nut" import *
from "%scripts/worldWar/worldWarConst.nut" import *

let wwEvent = require("%scripts/worldWar/wwEvent.nut")
let { wwGetArmiesNames } = require("worldwar")
let { WwArmy } = require("%scripts/worldWar/inOperation/model/wwArmy.nut")


let WwOperationArmies = class {
  armiesByNameCache = null
  armiesByStatusCache = null

  constructor() {
    this.armiesByNameCache = {}
    this.armiesByStatusCache = {}
  }

  function getArmiesByStatus(status) {
    return getTblValue(status, this.armiesByStatusCache, {})
  }

  function updateArmyStatus(armyName) {
    let army = ::g_world_war.getArmyByName(armyName)
    let cachedArmy = getTblValue(armyName, this.armiesByNameCache, null)
    let hasChanged = !cachedArmy || !cachedArmy.isStatusEqual(army)

    if (!hasChanged)
      return

    if (cachedArmy)
      this.removeArmyFromCache(cachedArmy)

    this.addArmyToCache(army, true)
    wwEvent("MapArmiesByStatusUpdated", { armies = [army] })
  }

  function statusUpdate() {
    this.resetCache()
    this.updateArmiesByStatus()
  }

  function updateArmiesByStatus() {
    let armyNames = wwGetArmiesNames()
    let armiesCountChanged = armyNames.len() != this.armiesByNameCache.len()

    let changedArmies = []
    let findedCachedArmies = {}
    foreach (armyName in armyNames) {
      let army = ::g_world_war.getArmyByName(armyName)
      if (!army.hasManageAccess())
        continue

      let cachedArmy = getTblValue(armyName, this.armiesByNameCache)
      if (cachedArmy)
        findedCachedArmies[armyName] <- cachedArmy

      if (!cachedArmy || !cachedArmy.isStatusEqual(army))
        changedArmies.append(army)

      this.addArmyToCache(army)
    }

    let deletingCachedArmiesNames = this.armiesByNameCache
      .filter(@(cachedArmy) cachedArmy.name in findedCachedArmies)

    foreach (armyName, _cachedArmy in deletingCachedArmiesNames)
      this.armiesByNameCache.$rawdelete(armyName)

    if (changedArmies.len() > 0 || armiesCountChanged) {
      foreach (_status, cacheData in this.armiesByStatusCache) {
        cacheData.common.sort(WwArmy.sortArmiesByUnitType)
        cacheData.surrounded.sort(WwArmy.sortArmiesByUnitType)
      }

      wwEvent("MapArmiesByStatusUpdated", { armies = changedArmies })
    }
  }

  function addArmyToCache(army, needSort = false) {
    let cacheByStatus = getTblValue(army.getActionStatus(), this.armiesByStatusCache)
    if (!cacheByStatus)
      return

    let cacheList = army.isSurrounded() ? cacheByStatus.surrounded : cacheByStatus.common
    if (needSort) {
      foreach (idx, cachedArmy in cacheList)
        if (army.getUnitType() - cachedArmy.getUnitType() <= 0) {
          cacheList.insert(idx, army)
          break
        }
    }
    else
      cacheList.append(army)

    this.armiesByNameCache[army.name] <- army
  }

  function removeArmyFromCache(cachedArmy) {
    let cacheByStatus = getTblValue(cachedArmy.getActionStatus(), this.armiesByStatusCache, null)
    if (cacheByStatus != null) {
      let cachedArr = cachedArmy.isSurrounded() ? cacheByStatus.surrounded : cacheByStatus.common
      foreach (idx, army in cachedArr)
        if (army == cachedArmy)
          return cachedArr.remove(idx)
    }
  }

  function resetCache() {
    this.armiesByStatusCache = {}
    let statusesForCaching = [
        WW_ARMY_ACTION_STATUS.IDLE,
        WW_ARMY_ACTION_STATUS.IN_MOVE,
        WW_ARMY_ACTION_STATUS.ENTRENCHED,
        WW_ARMY_ACTION_STATUS.IN_BATTLE
      ]

    foreach (status in statusesForCaching)
      this.armiesByStatusCache[status] <- {
        common = []
        surrounded = []
      }
  }
}
return { WwOperationArmies }