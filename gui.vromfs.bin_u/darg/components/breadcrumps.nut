/*
   This is navigation state creation for tree navigator
   is also naturally mixed with ui pattern state called breadCrumps, cause current path in tree is a breadcrump
   it can be used for navigation in menus in a static or dynamic tree like structures (like directory & file structures)
   for dynamic trees submenu should be a function, and curMenu can be replaced with subMenuCtor

   It should be renamed to treeNavigator cause it what it is.
     addBreadCrump -> addTreeNode\addNavigationNode
     removeBreadCrump -> removeNavigationNode \ removeTreeNode
     mkBreadCrumpsMenu -> TreeNavgator
     lastVisitedMenu -> lastVisitedNode
     resolveBreadCrumpsByPath -> resolveNavigationByPath
     menuItems - > nodeSubnodes
     curMenu -> curNode
     curMenuSubmenuVal -> curNodeSubnodesVal
     curMenuItems -> curNodeItems
     itemCtor -> nodeCtor
     itemParams -> nodeParams
     submenu -> subnodes
     previewMenu -> previewNode
     menuWnd -> nodeView
     lastVisitedMenuId -> lastVisitedNodeId
     prevMenu-> prevNode

   todo
     ? check that all items have unique id. Not really required, but can be useful for static trees and easier navigation sometimes
*/

local mkBreadCrumpItem = ::kwarg(function(id, itemCtor=null, onEnter=null, onLeave=null, menuWnd=null, submenu=null, previewMenu = null, itemParams={}){
  ::assert(::type(id)=="string", @() $"id should be a string, got {::type(id)}")
  ::assert(onEnter==null || ::type(onEnter)=="function", "onEnter should be a function")
  ::assert(onLeave==null || ::type(onLeave)=="function", "onLeave should be a function")
  ::assert(itemCtor ==null || (::type(itemCtor)=="function" && itemCtor.getfuncinfos().paramaters.len==2), "itemCtor should be a function and accept kwarg argument (menu, statFlags, group) ")
  //fixme type check for menuWnd, previewmenu and submenu. all of them can be something dynamic, like an function or observable or generator
  return itemParams.__merge({
    id
    onLeave
    onEnter
    submenu
    itemCtor
    previewMenu
    menuWnd
  })
})

local function mkBreadCrumpsMenu(breadcrumpsPathIds=null, lastVisitedMenuId=null){
  breadcrumpsPathIds = breadcrumpsPathIds ?? Watched([])
  ::assert(breadcrumpsPathIds instanceof Watched || "update" in breadcrumpsPathIds || "value" in breadcrumpsPathIds, $"path should be observable or alike")
  local initPathIds = breadcrumpsPathIds?.value

  ::assert(::type(initPathIds) == "array", @() $"path can be presented only with list of string, get {::type(initPathIds)}")
  initPathIds.each(@(v, idx) ::assert(::type(v)=="string" || (v==null && idx==0), @() $"path can be presented only with list of string, [{idx}] was {::type(v)}"))

  lastVisitedMenuId = lastVisitedMenuId ?? Watched()
  local menuItems = Watched()
  local breadcrumpsPath = Watched([])


  local function addBreadCrump(menuItem, visited=false){
    breadcrumpsPath(@(p) p.append(menuItem))
    breadcrumpsPathIds.update(@(p) p.append(menuItem.id))
    if (visited)
      return
    menuItem?.onEnter()
  }
  local lastVisitedMenu = Watched()

  local function removeBreadCrump(delta){
    for (local i=0; i<delta; i++) {
      local idx = breadcrumpsPath.value.len()-1
      if (idx < 1)
        return
      lastVisitedMenuId(breadcrumpsPathIds.value?[idx])
      lastVisitedMenu(breadcrumpsPath.value?[idx])
      breadcrumpsPath.value[idx]?.onLeave()
      breadcrumpsPath(@(v) v.remove(idx))
      breadcrumpsPathIds(@(v) v.remove(idx))
    }
  }

  const submenuKey = "submenu"
  local function resolveBreadCrumpsByPath(menuItemsVal){
    local bcIds = breadcrumpsPathIds.value
    local resolvedMenus = []
    local curMenuVal = menuItemsVal
    foreach (idx, bcId in bcIds){
      foreach (m in curMenuVal){
        if (m.id == bcId) {
          resolvedMenus.append(m)
          if (!(submenuKey in m))
            break
          if (::type(m[submenuKey])=="function")
            curMenuVal = m[submenuKey]()
          if (["array", "generator"].contains(::type(m[submenuKey])))
            curMenuVal = m[submenuKey]
        }
      }
    }
    if (resolvedMenus.len()==0) {
      breadcrumpsPathIds.update([])
      addBreadCrump(menuItemsVal?[0])
    }
    else {
      local correctResolvedIdx = -1
      foreach (idx, oldBcId in bcIds){
        if (resolvedMenus?[idx].id != oldBcId)
          break
        correctResolvedIdx = idx
      }
      breadcrumpsPathIds.update([])
      resolvedMenus.slice(0, correctResolvedIdx+1).each(@(v) addBreadCrump(v, true))
      resolvedMenus.slice(correctResolvedIdx+1).each(@(v) addBreadCrump(v))
    }
  }

  local function rootBreadCrump(){
    removeBreadCrump(breadcrumpsPath.value.len())
  }

  breadcrumpsPath.whiteListMutatorClosure(addBreadCrump)
  breadcrumpsPath.whiteListMutatorClosure(removeBreadCrump)


  local curMenu = Computed(@() breadcrumpsPath.value.len() > 0 ? breadcrumpsPath.value?[breadcrumpsPath.value.len()-1] : null)
  local prevMenu = Computed(@() breadcrumpsPath.value.len() > 1 ? breadcrumpsPath.value?[breadcrumpsPath.value.len()-2] : null)

  local curMenuItems = Computed(function() {
    local curMenuSubmenuVal = curMenu.value?.submenu
    if (::type(curMenuSubmenuVal) == "function")
      curMenuSubmenuVal = curMenuSubmenuVal()
    return curMenuSubmenuVal ?? []
  })
  local curMenuWnd = Computed(@() curMenu.value?.menuWnd ?? curMenu.value?.menuWndCtor())

  local curBreadCrump = Computed(@() curMenu.value?.id)

  local function returnBack() {
    removeBreadCrump(1)
  }


  menuItems.subscribe(resolveBreadCrumpsByPath)

  return{
    menuItems
    breadcrumpsPath
    removeBreadCrump
    curMenu
    curMenuItems
    curMenuWnd
    returnBack
    addBreadCrump
    prevMenu
    curBreadCrump
    rootBreadCrump
    mkBreadCrumpItem
    resolveBreadCrumpsByPath
    lastVisitedMenuId
    lastVisitedMenu
  }
}

return mkBreadCrumpsMenu