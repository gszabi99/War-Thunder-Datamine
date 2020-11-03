local seenInventory = require("scripts/seen/seenList.nut").get(SEEN.INVENTORY)

::g_recent_items <- {
  MAX_RECENT_ITEMS = 4
  wasCreated = false
}

g_recent_items.getRecentItems <- function getRecentItems()
{
  local items = ::ItemsManager.getInventoryList(itemType.INVENTORY_ALL, function (item) {
    return item.includeInRecentItems
  })
  items.sort(::ItemsManager.getItemsSortComparator(seenInventory))
  local resultItems = []
  foreach (item in items)
  {
    if (item.isHiddenItem())
      continue
    resultItems.append(item)
    if (resultItems.len() == MAX_RECENT_ITEMS)
      break
  }

  return resultItems
}

g_recent_items.createHandler <- function createHandler(owner, containerObj, defShow)
{
  if (!::checkObj(containerObj))
    return null

  wasCreated = true
  return ::handlersManager.loadHandler(::gui_handlers.RecentItemsHandler, { scene = containerObj, defShow = defShow })
}

g_recent_items.getNumOtherItems <- function getNumOtherItems()
{
  local inactiveItems = ::ItemsManager.getInventoryList(itemType.INVENTORY_ALL,
    @(item) !!item.getMainActionData())
  return inactiveItems.len()
}

g_recent_items.reset <- function reset()
{
  wasCreated = false
}
