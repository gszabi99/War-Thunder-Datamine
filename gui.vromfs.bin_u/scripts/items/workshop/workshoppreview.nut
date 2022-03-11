local minWindowWidthScale = 1.33  //1.33@sf

class ::gui_handlers.WorkshopPreview extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType      = handlerType.MODAL
  sceneTplName = "gui/items/workshopPreview"

  wSet = null

  function getSceneTplView()
  {
    local blk = wSet.previewBlk
    local infoBlocks = []
    for ( local i = 0; i < blk.paramCount(); i++ )
    {
      local name = blk.getParamName(i)
      if (name == "image" || name == "space")
        infoBlocks.append({
          [name] = blk.getParamValue(i)
        })
      else if (name == "text")
        infoBlocks.append({
          text = ::loc(blk.getParamValue(i))
        })
      else if (name == "imageScale" && infoBlocks.len())
        infoBlocks[infoBlocks.len() - 1][name] <- blk.getParamValue(i)
    }

    local mainImageScale = blk?.main_image_scale ?? minWindowWidthScale
    return {
      headerText = ::loc(blk?.main_header ?? "items/workshop")
      bgImage = blk?.main_image
      windowWidthScale = ::max(mainImageScale, minWindowWidthScale)
      mainImageScale = mainImageScale
      infoBlocks = infoBlocks
    }
  }

  function afterModalDestroy()
  {
    wSet.markPreviewed()
    ::gui_start_items_list(itemsTab.WORKSHOP, { curSheet = { id = wSet.getShopTabId() } })
  }
}

return {
  open = @(wSet) wSet.hasPreview() && ::handlersManager.loadHandler(::gui_handlers.WorkshopPreview, { wSet = wSet })
}