//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

::WwOperationArmies <- class {
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
    ::ww_event("MapArmiesByStatusUpdated", { armies = [army] })
  }

  function statusUpdate() {
    this.resetCache()
    this.updateArmiesByStatus()
  }

  function updateArmiesByStatus() {
    let armyNames = ::ww_get_armies_names()
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

    let deletingCachedArmiesNames = ::u.filter(
      this.armiesByNameCache,
      (@(findedCachedArmies) function(cachedArmy) {
        return cachedArmy.name in findedCachedArmies
      })(findedCachedArmies)
    )

    foreach (_armyName, cachedArmy in deletingCachedArmiesNames)
      ::u.removeFrom(this.armiesByNameCache, cachedArmy)

    if (changedArmies.len() > 0 || armiesCountChanged) {
      foreach (_status, cacheData in this.armiesByStatusCache) {
        cacheData.common.sort(::WwArmy.sortArmiesByUnitType)
        cacheData.surrounded.sort(::WwArmy.sortArmiesByUnitType)
      }

      ::ww_event("MapArmiesByStatusUpdated", { armies = changedArmies })
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
