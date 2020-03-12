::g_personal_unlocks <- {
  [PERSISTENT_DATA_PARAMS] = ["unlocksArray"]

  unlocksArray = []
  newIconWidgetById = {}
  isArrayValid = false

  showAllUnlocksValue = false
}

g_personal_unlocks.reset <- function reset()
{
  unlocksArray.clear()
  newIconWidgetById.clear()
}

g_personal_unlocks.update <- function update()
{
  if (!::g_login.isLoggedIn())
    return

  reset()

  foreach(unlockBlk in ::g_unlocks.getAllUnlocksWithBlkOrder())
    if (unlockBlk?.showAsBattleTask && (showAllUnlocksValue || ::is_unlock_visible(unlockBlk)))
    {
      unlocksArray.append(unlockBlk)
      newIconWidgetById[unlockBlk.id] <- null
    }
  isArrayValid = true
}

g_personal_unlocks.getUnlocksArray <- function getUnlocksArray()
{
  if(!isArrayValid)
    update()

  return unlocksArray
}

g_personal_unlocks.onEventBattleTasksShowAll <- function onEventBattleTasksShowAll(params)
{
  showAllUnlocksValue = ::getTblValue("showAllTasksValue", params, false)
  update()
}

g_personal_unlocks.onEventSignOut <- function onEventSignOut(p)
{
  reset()
}

g_personal_unlocks.onEventLoginComplete <- function onEventLoginComplete(p)
{
  invalidateArray()
}

g_personal_unlocks.isAvailableForUser <- function isAvailableForUser()
{
  return ::has_feature("PersonalUnlocks") && !::u.isEmpty(getUnlocksArray())
}

g_personal_unlocks.invalidateArray <- function invalidateArray()
{
  isArrayValid = false
}

g_personal_unlocks.onEventUnlocksCacheInvalidate <- function onEventUnlocksCacheInvalidate(p)
{
  invalidateArray()
}

::g_script_reloader.registerPersistentDataFromRoot("g_personal_unlocks")
::subscribe_handler(::g_personal_unlocks, ::g_listener_priority.CONFIG_VALIDATION)
