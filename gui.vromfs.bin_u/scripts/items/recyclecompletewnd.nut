from "console" import register_command
from "%scripts/dagui_library.nut" import *

let { register_gui_handler, get_gui_handler } = require("%scripts/sqDagui/framework/gui_handlers.nut")
let { BaseGuiHandlerWT } = require("%scripts/baseGuiHandlerWT.nut")
let { handlerType } = require("%scripts/sqDagui/framework/handlerType.nut")
let { findItemById } = require("%scripts/items/itemsManagerModule.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")

const ITEM_IMAGE_SIZE = "150@sf/@pf"
const ITEM_IMAGE_MARGIN = "20@sf/@pf"
const FRAME_PADDING = "50@sf/@pf"
const MAX_COLUMNS = 5

local debugItemIndex = 0

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
  let recycledWnd = handlersManager.findHandlerClassInScene(get_gui_handler("recycleCompleteWnd"))
  if (recycledWnd) {
    recycledWnd.addItems(recycledItems)
    return
  }
  loadHandler(get_gui_handler("recycleCompleteWnd"), {recycledItems})
}


let recycleCompleteWnd = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/items/recycleCompleteWnd.blk"
  recycledItems = null
  cachedItemSizeInPix = 0
  cachedPaddingInPix = 0

  function initScreen() {
    this.cachedItemSizeInPix = to_pixels($"{ITEM_IMAGE_SIZE} + 2*{ITEM_IMAGE_MARGIN}")
    this.cachedPaddingInPix = to_pixels(FRAME_PADDING)
    this.drawItems(this.recycledItems)
  }

  function drawItems(items) {
    let columnsCount = min(items.len(), MAX_COLUMNS)
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
register_gui_handler("recycleCompleteWnd", recycleCompleteWnd)

function showDebugItems(count) {
  let recycledItems = {}
  for (local i = 0; i < count; i++) {
    let item = findItemById("booster_shop_pub_wp_10")
    if (item == null)
      continue
    recycledItems[debugItemIndex.tostring()] <- {item,  count = i}
    debugItemIndex++
  }
  let recycledWnd = handlersManager.findHandlerClassInScene(recycleCompleteWnd)
  if (recycledWnd) {
    recycledWnd.addItems(recycledItems)
    return
  }
  loadHandler(recycleCompleteWnd, {recycledItems})
}

register_command(showDebugItems, "debug.recycledWindow")

return {
  recycleCompleteWnd
  openOrUpdateRecycleCompleteWnd
}