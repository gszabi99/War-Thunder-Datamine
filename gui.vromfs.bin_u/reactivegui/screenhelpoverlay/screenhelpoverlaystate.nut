from "%rGui/globals/ui_library.nut" import *
let { getActionBarItemRectByType, actionBarRect } = require("%rGui/hud/actionBarState.nut")



let screenHelpItems = Watched(null)
let screenHelpSafeArea = Watched(null)

function resolveActionBarItem(item) {
  let barRect = actionBarRect.get()
  if (barRect == null)
    return null
  let actionItemRect = getActionBarItemRectByType(item.actionType)
  if (actionItemRect == null)
    return null

  
  let extraObstacles = [
    { x = actionItemRect.x, y = barRect.y, w = 1, h = barRect.h }
    { x = actionItemRect.x + actionItemRect.w, y = barRect.y, w = 1, h = barRect.h }
  ]

  return item.__merge({ targetRect = actionItemRect, extraObstacles })
}

function resolveItem(item) {
  if (item?.actionType != null)
    return resolveActionBarItem(item)

  let aabb = gui_scene.getCompAABBbyKey(item.targetKey)
  if (aabb == null)
    return null
  let targetRect = { x = aabb.l, y = aabb.t, w = aabb.r - aabb.l, h = aabb.b - aabb.t }
  return item.__merge({ targetRect })
}

let safeAreaToRect = @(sa) {
  x = sa.borders[1]
  y = sa.borders[0]
  w = sa.size[0]
  h = sa.size[1]
}













function openScreenHelp(items, safeArea) {
  let resolved = []
  foreach (it in items) {
    let r = resolveItem(it)
    if (r != null)
      resolved.append(r)
  }

  if (resolved.len() == 0)
    return
  screenHelpSafeArea.set(safeAreaToRect(safeArea))
  screenHelpItems.set(resolved)
}

function closeScreenHelp() {
  screenHelpItems.set(null)
  screenHelpSafeArea.set(null)
}

return {
  screenHelpItems
  screenHelpSafeArea
  openScreenHelp
  closeScreenHelp
}