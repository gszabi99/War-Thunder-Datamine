from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")

const ITEM_IMAGE_SIZE = "150@sf/@pf"
const ITEM_IMAGE_MARGIN = "20@sf/@pf"
const FRAME_PADDING = "50@sf/@pf"
const MAX_COLUMNS = 5

function openOrUpdateRecycleCompleteWnd(params) {
  let itemsIds = params.itemsIds
  let recycledItems = {}
  foreach (itemId, count in itemsIds) {
    let item = findItemById(itemId)
    if (item == null)
      continue
    recycledItems[itemId] <- {item, count}
  }
  if (recycledItems.len() == 0)
    return
  let recycledWnd = handlersManager.findHandlerClassInScene(gui_handlers.recycleCompleteWnd)
  if (recycledWnd) {
    recycledWnd.addItems(recycledItems)
    return
  }
  loadHandler(gui_handlers.recycleCompleteWnd, {recycledItems})
}


gui_handlers.recycleCompleteWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/recycleCompleteWnd.blk"
  recycledItems = null

  cachedRhInPix = 0
  cachedItemSizeInPix = 0
  cachedPaddingInPix = 0

  function initScreen() {
    this.cachedRhInPix = to_pixels("1@rh")
    this.cachedItemSizeInPix = to_pixels($"{ITEM_IMAGE_SIZE} + 2*{ITEM_IMAGE_MARGIN}")
    this.cachedPaddingInPix = to_pixels(FRAME_PADDING)
    this.drawItems(this.recycledItems)
  }

  function drawItems(items) {
    let columnsCount = min(items.len(), MAX_COLUMNS)
    let maxHeight = 0.7 * this.cachedRhInPix
    let rowsCount = (items.len() / columnsCount).tointeger()
    let maxRowsCount = (maxHeight / this.cachedItemSizeInPix).tointeger()
    if (rowsCount > maxRowsCount) {
      let scrollContainer = this.scene.findObject("scroll_container")
      scrollContainer["overflow-y"] = "auto"
    }
    let frameObj = this.scene.findObject("recycle_frame")
    frameObj.width = columnsCount * this.cachedItemSizeInPix + this.cachedPaddingInPix * 2;

    local viewData = {items = []}
    foreach (itemData in items) {
      let data = {
        itemSize = ITEM_IMAGE_SIZE
        itemIcon = itemData.item.getIcon()
        iconMargin = ITEM_IMAGE_MARGIN
        tooltipId = getTooltipType("ITEM").getTooltipId(itemData.item.id)
        text = "".concat(itemData.item.getName(false), $" x{itemData.count}")
      }
      viewData.items.append(data)
    }

    let markup = handyman.renderCached("%gui/items/recycleCompleteItem.tpl", viewData)
    let imageObjPlace = this.scene.findObject("reward_image_place")
    this.guiScene.replaceContentFromText(imageObjPlace, markup, markup.len(), this)
  }

  function addItems(items) {
    if (this.recycledItems == null) {
      this.recycledItems = items
    } else {
      foreach (itemId, itemData in items) {
        if (this.recycledItems?[itemId] == null)
          this.recycledItems[itemId] <- itemData
        else
          this.recycledItems[itemId].count += itemData.count
      }
    }
    this.drawItems(this.recycledItems)
  }
}

return {
  openOrUpdateRecycleCompleteWnd
}
