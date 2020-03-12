::g_ww_map_armies_status_manager <- {
  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  armiesStateCache = null

  requestUpdated = false
}

g_ww_map_armies_status_manager.requestUpdate <- function requestUpdate()
{
  requestUpdated = true
}

g_ww_map_armies_status_manager.updateArmiesByStatus <- function updateArmiesByStatus()
{
  if (!requestUpdated)
    return

  local curTime = ::dagor.getCurTime()
  if (curTime - lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  _resetCache()

  foreach(armyName in ::ww_get_armies_names())
  {
    local army = ::g_world_war.getArmyByName(armyName)
    if (!army.hasManageAccess())
      continue

    local cacheByStatus = ::getTblValue(army.getActionStatus(), armiesStateCache, null)
    if (cacheByStatus == null)
      continue

    if (army.isSurrounded())
      cacheByStatus.surrounded.append(army)
    else
      cacheByStatus.common.append(army)
  }

  foreach(status, cache in armiesStateCache)
  {
    cache.surrounded.sort(::WwArmy.sortArmiesByUnitType)
    cache.common.sort(::WwArmy.sortArmiesByUnitType)
  }

  lastUpdateTime = curTime
  requestUpdated = false

  ::ww_event("MapArmiesByStatusUpdated")
}

g_ww_map_armies_status_manager.getArmiesByStatus <- function getArmiesByStatus(status)
{
  return ::getTblValue(status, armiesStateCache, {})
}

g_ww_map_armies_status_manager._resetCache <- function _resetCache()
{
  armiesStateCache = {}
  local statusesByCaching = [
      WW_ARMY_ACTION_STATUS.IDLE,
      WW_ARMY_ACTION_STATUS.IN_MOVE,
      WW_ARMY_ACTION_STATUS.ENTRENCHED,
      WW_ARMY_ACTION_STATUS.IN_BATTLE
    ]

  foreach(status in statusesByCaching)
    armiesStateCache[status] <- {
      common = []
      surrounded = []
    }
}

::g_ww_map_armies_status_manager._resetCache()
