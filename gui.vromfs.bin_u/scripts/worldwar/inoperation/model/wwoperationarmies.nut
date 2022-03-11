class ::WwOperationArmies
{
  armiesByNameCache = null
  armiesByStatusCache = null

  constructor()
  {
    armiesByNameCache = {}
    armiesByStatusCache = {}
  }

  function getArmiesByStatus(status)
  {
    return ::getTblValue(status, armiesByStatusCache, {})
  }

  function updateArmyStatus(armyName)
  {
    local army = ::g_world_war.getArmyByName(armyName)
    local cachedArmy = ::getTblValue(armyName, armiesByNameCache, null)
    local hasChanged = !cachedArmy || !cachedArmy.isStatusEqual(army)

    if (!hasChanged)
      return

    if (cachedArmy)
      removeArmyFromCache(cachedArmy)

    addArmyToCache(army, true)
    ::ww_event("MapArmiesByStatusUpdated", { armies = [army] })
  }

  function statusUpdate()
  {
    resetCache()
    updateArmiesByStatus()
  }

  function updateArmiesByStatus()
  {
    local armyNames = ::ww_get_armies_names()
    local armiesCountChanged = armyNames.len() != armiesByNameCache.len()

    local changedArmies = []
    local findedCachedArmies = {}
    foreach(armyName in armyNames)
    {
      local army = ::g_world_war.getArmyByName(armyName)
      if (!army.hasManageAccess())
        continue

      local cachedArmy = ::getTblValue(armyName, armiesByNameCache)
      if (cachedArmy)
        findedCachedArmies[armyName] <- cachedArmy

      if (!cachedArmy || !cachedArmy.isStatusEqual(army))
        changedArmies.append(army)

      addArmyToCache(army)
    }

    local deletingCachedArmiesNames = ::u.filter(
      armiesByNameCache,
      (@(findedCachedArmies) function(cachedArmy) {
        return cachedArmy.name in findedCachedArmies
      })(findedCachedArmies)
    )

    foreach(armyName, cachedArmy in deletingCachedArmiesNames)
      ::u.removeFrom(armiesByNameCache, cachedArmy)

    if (changedArmies.len() > 0 || armiesCountChanged)
    {
      foreach(status, cacheData in armiesByStatusCache)
      {
        cacheData.common.sort(::WwArmy.sortArmiesByUnitType)
        cacheData.surrounded.sort(::WwArmy.sortArmiesByUnitType)
      }

      ::ww_event("MapArmiesByStatusUpdated", { armies = changedArmies })
    }
  }

  function addArmyToCache(army, needSort = false)
  {
    local cacheByStatus = ::getTblValue(army.getActionStatus(), armiesByStatusCache)
    if (!cacheByStatus)
      return

    local cacheList = army.isSurrounded() ? cacheByStatus.surrounded : cacheByStatus.common
    if (needSort)
    {
      foreach(idx, cachedArmy in cacheList)
        if (army.getUnitType() - cachedArmy.getUnitType() <= 0)
        {
          cacheList.insert(idx, army)
          break
        }
    }
    else
      cacheList.append(army)

    armiesByNameCache[army.name] <- army
  }

  function removeArmyFromCache(cachedArmy)
  {
    local cacheByStatus = ::getTblValue(cachedArmy.getActionStatus(), armiesByStatusCache, null)
    if (cacheByStatus != null)
    {
      local cachedArr = cachedArmy.isSurrounded() ? cacheByStatus.surrounded : cacheByStatus.common
      foreach(idx, army in cachedArr)
        if (army == cachedArmy)
          return cachedArr.remove(idx)
    }
  }

  function resetCache()
  {
    armiesByStatusCache = {}
    local statusesForCaching = [
        WW_ARMY_ACTION_STATUS.IDLE,
        WW_ARMY_ACTION_STATUS.IN_MOVE,
        WW_ARMY_ACTION_STATUS.ENTRENCHED,
        WW_ARMY_ACTION_STATUS.IN_BATTLE
      ]

    foreach(status in statusesForCaching)
      armiesByStatusCache[status] <- {
        common = []
        surrounded = []
      }
  }
}
