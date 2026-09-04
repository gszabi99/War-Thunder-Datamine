from "%scripts/dagui_library.nut" import *
from "%scripts/items/itemsConsts.nut" import itemsTab

let { register_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_start_items_list } = require("%scripts/items/startItemsShop.nut")

const minWindowWidthScale = 1.33  

let WorkshopPreview = class (BaseGuiHandlerWT) {
  wndType      = handlerType.MODAL
  sceneTplName = "%gui/items/workshopPreview.tpl"

  wSet = null

  function getSceneTplView() {
    let blk = this.wSet.previewBlk
    let infoBlocks = []
    for (local i = 0; i < blk.paramCount(); i++) {
      let name = blk.getParamName(i)
      if (name == "image" || name == "space")
        infoBlocks.append({
          [name] = blk.getParamValue(i)
        })
      else if (name == "text")
        infoBlocks.append({
          text = loc(blk.getParamValue(i))
        })
      else if (name == "imageScale" && infoBlocks.len())
        infoBlocks[infoBlocks.len() - 1][name] <- blk.getParamValue(i)
    }

    let mainImageScale = blk?.main_image_scale ?? minWindowWidthScale
    return {
      headerText = loc(blk?.main_header ?? "items/workshop")
      bgImage = blk?.main_image
      windowWidthScale = max(mainImageScale, minWindowWidthScale)
      mainImageScale = mainImageScale
      infoBlocks = infoBlocks
    }
  }

  function afterModalDestroy() {
    this.wSet.markPreviewed()
    gui_start_items_list(itemsTab.WORKSHOP, { curSheet = { id = this.wSet.getShopTabId() } })
  }
}
register_gui_handler("WorkshopPreview", WorkshopPreview)

return {
  WorkshopPreview
  open = @(wSet) wSet.hasPreview() && handlersManager.loadHandler(WorkshopPreview, { wSet = wSet })
}