from "%scripts/dagui_library.nut" import *
//checked for explicitness
#no-root-fallback
#explicit-this

let { get_time_msec } = require("dagor.time")

::g_ww_map_armies_status_manager <- {
  UPDATE_REFRESH_DELAY = 1000

  lastUpdateTime = 0
  armiesStateCache = null

  requestUpdated = false
}

::g_ww_map_armies_status_manager.requestUpdate <- function requestUpdate()
{
  this.requestUpdated = true
}

::g_ww_map_armies_status_manager.updateArmiesByStatus <- function updateArmiesByStatus()
{
  if (!this.requestUpdated)
    return

  let curTime = get_time_msec()
  if (curTime - this.lastUpdateTime < UPDATE_REFRESH_DELAY)
    return

  this._resetCache()

  foreach(armyName in ::ww_get_armies_names())
  {
    let army = ::g_world_war.getArmyByName(armyName)
    if (!army.hasManageAccess())
      continue

    let cacheByStatus = getTblValue(army.getActionStatus(), this.armiesStateCache, null)
    if (cacheByStatus == null)
      continue

    if (army.isSurrounded())
      cacheByStatus.surrounded.append(army)
    else
      cacheByStatus.common.append(army)
  }

  foreach(_status, cache in this.armiesStateCache)
  {
    cache.surrounded.sort(::WwArmy.sortArmiesByUnitType)
    cache.common.sort(::WwArmy.sortArmiesByUnitType)
  }

  this.lastUpdateTime = curTime
  this.requestUpdated = false

  ::ww_event("MapArmiesByStatusUpdated")
}

::g_ww_map_armies_status_manager.getArmiesByStatus <- function getArmiesByStatus(status)
{
  return getTblValue(status, this.armiesStateCache, {})
}

::g_ww_map_armies_status_manager._resetCache <- function _resetCache()
{
  this.armiesStateCache = {}
  let statusesByCaching = [
      WW_ARMY_ACTION_STATUS.IDLE,
      WW_ARMY_ACTION_STATUS.IN_MOVE,
      WW_ARMY_ACTION_STATUS.ENTRENCHED,
      WW_ARMY_ACTION_STATUS.IN_BATTLE
    ]

  foreach(status in statusesByCaching)
    this.armiesStateCache[status] <- {
      common = []
      surrounded = []
    }
}

::g_ww_map_armies_status_manager._resetCache()
