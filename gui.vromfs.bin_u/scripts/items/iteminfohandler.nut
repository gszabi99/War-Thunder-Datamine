local class ItemInfoHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/items/itemDesc.blk"

  currentItemId = null
  currentCategoryId = null

  function updateHandlerData(item, shopDesc = false, preferMarkup = false, params = null)
  {
    scene.scrollToView(true)
    ::ItemsManager.fillItemDescr(item, scene, this, shopDesc, preferMarkup, params)

    if (item == null)
    {
      currentItemId = null
      currentCategoryId = null
      return
    }

    if (item.id == currentItemId && currentCategoryId != null)
    {
      openCategory(currentCategoryId)
      return
    }
    currentItemId = item.id
    currentCategoryId = null
  }

  function setHandlerVisible(value)
  {
    scene.show(value)
    scene.enable(value)
  }

  function openCategory(categoryId)
  {
    local containerObj = scene.findObject("item_info_collapsable_prizes")
    if (!::check_obj(containerObj))
      return
    local total = containerObj.childrenCount()
    local visible = false
    guiScene.setUpdatesEnabled(false, false)
    for(local i = 0; i < total; i++)
    {
      local childObj = containerObj.getChild(i)
      if (childObj.isCategory == "no")
      {
        childObj.enable(visible)
        childObj.show(visible)
        continue
      }
      if (childObj.categoryId == categoryId)
      {
        childObj.collapsed = childObj.collapsed == "no" ? "yes" : "no"
        visible = childObj.collapsed == "no"
        continue
      }
      childObj.collapsed = "yes"
      visible = false
    }
    guiScene.setUpdatesEnabled(true, true)
  }

  function onPrizeCategoryClick(obj)
  {
    currentCategoryId = obj.categoryId
    openCategory(currentCategoryId)
    if (::show_console_buttons)
      ::move_mouse_on_obj(obj)
  }

}

::gui_handlers.ItemInfoHandler <- ItemInfoHandler

return function(scene) {
  if (!::check_obj(scene))
    return null
  return ::handlersManager.loadHandler(ItemInfoHandler, { scene = scene })
}