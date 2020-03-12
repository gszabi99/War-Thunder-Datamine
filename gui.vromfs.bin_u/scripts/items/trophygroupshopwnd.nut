local stdMath = require("std/math.nut")

::gui_start_open_trophy_group_shop_wnd <- function gui_start_open_trophy_group_shop_wnd(trophy)
{
  if (!trophy)
    return

  ::gui_start_modal_wnd(::gui_handlers.TrophyGroupShopWnd, {trophy = trophy})
}

class ::gui_handlers.TrophyGroupShopWnd extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/modalSceneWithGamercard.blk"
  sceneTplName = "gui/items/trophyGroupShop"

  trophy = null
  trophyInfo = null
  bitMask = null

  focusIdx = -1

  function initScreen()
  {
    updateTrophyInfo()
    updateContent()
    initFocusArray()
  }

  function updateContent()
  {
    fillTrophiesList()
    setDescription()
    updateHeader()
    setNextItemInFocus()
  }

  function setDescription()
  {
    local obj = scene.findObject("item_info_desc_place")
    if (!::checkObj(obj))
      return

    guiScene.replaceContent(obj, "gui/items/itemDesc.blk", this)
    ::ItemsManager.fillItemDescr(trophy, obj, this)
  }

  function updateTrophyInfo()
  {
    trophyInfo = ::get_trophy_info(trophy.id)
    loadBitMask()
  }

  function loadBitMask()
  {
    bitMask = ::getTblValue("openMask", trophyInfo)
    if (bitMask)
      return

    bitMask = 0
  }

  function updateHeader()
  {
    local headerObj = scene.findObject("group_trophy_header")
    if (!::checkObj(headerObj))
      return

    local restText = ::getTblValue("openCount", trophyInfo, 0) + ::loc("ui/slash") + trophy.numTotal
    headerObj.setValue(::loc("mainmenu/itemReceived") + ::loc("ui/parentheses/space", {text = restText}))
  }

  function getMaxSizeInItems(reduceSize = false)
  {
    local freeWidth = guiScene.calcString("1@trophiesGroupAvailableWidth", null)
    local freeHeight = guiScene.calcString("1@requiredItemsInColumnInPixels", null)

    local singleItemSizeTable = countSize({w = 1, h = 1}, reduceSize)

    local freeRow = freeWidth / singleItemSizeTable.width
    local freeColumn = freeHeight / singleItemSizeTable.height

    return {row = freeRow, column = freeColumn}
  }

  function updateScreenSize()
  {
    local maxAvailRatio = getMaxSizeInItems()
    local reduceSize = (maxAvailRatio.row * maxAvailRatio.column) < trophy.numTotal
    if (reduceSize)
      maxAvailRatio = getMaxSizeInItems(true)

    local itemsInRow = 0
    local itemsInColumn = ::sqrt(trophy.numTotal).tointeger()
    for (local i = itemsInColumn; i > 0; i--)
    {
      local columns = trophy.numTotal / i
      if (columns > maxAvailRatio.column)
        break

      if (columns * i != trophy.numTotal)
        continue

      itemsInRow = columns
      break
    }

    if (itemsInRow == 0)
    {
      itemsInRow =  ::floor(::sqrt((maxAvailRatio.row.tofloat() / maxAvailRatio.column) * trophy.numTotal + 0.5)) || 1
      itemsInColumn = ::ceil(trophy.numTotal / itemsInRow)
    }

    return countSize({w = itemsInRow, h = itemsInColumn}, reduceSize)
  }

  function countSize(ratio, reduceSize = false)
  {
    local mult = reduceSize? "0.5" : "1"
    local height = ratio.h * guiScene.calcString(mult + "@itemHeight + 1@itemSpacing", null)
    local width = ratio.w * guiScene.calcString(mult + "@itemWidth + 1@itemSpacing", null)

    return {width = width, height = height, smallItems = reduceSize? "yes" : "no"}
  }

  function fillTrophiesList()
  {
    local view = updateScreenSize()
    view.trophyItems <- ""

    for (local i = 0; i < trophy.numTotal; i++)
    {
      local isOpened = isTrophyPurchased(i)
      view.trophyItems += ::handyman.renderCached(("gui/items/item"), {
        items = trophy.getViewData({
          showPrice = false,
          contentIcon = false,
          openedPicture = isOpened,
          showTooltip = !isOpened,
          showAction = !isOpened,
          itemHighlight = !isOpened,
          isItemLocked = isOpened,
          itemIndex = i.tostring()
        })})
    }

    local data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene.findObject("root-box"), data, data.len(), this)
  }

  function getBestFocusValue()
  {
    local obj = getMainFocusObj()
    local total = obj.childrenCount()
    local startIdx = ::max(focusIdx, 0)
    for (local i = startIdx; i < startIdx + total; i++)
    {
      local index = i % total
      if (!isTrophyPurchased(index))
        return index
    }

    return 0
  }

  function setNextItemInFocus()
  {
    local obj = getMainFocusObj()
    if (!::checkObj(obj))
      return

    local bestVal = getBestFocusValue()
    obj.setValue(bestVal)
  }

  function isTrophyPurchased(value)
  {
    return stdMath.is_bit_set(bitMask, value)
  }

  function getMainFocusObj()
  {
    return scene.findObject("items_list")
  }

  function onItemAction(obj)
  {
    if (::checkObj(obj) && obj?.holderId)
      doAction(obj.holderId.tointeger())
  }

  function onSelectedItemAction()
  {
    local value = getMainFocusObj().getValue()
    doAction(value)
  }

  function doAction(index)
  {
    trophy.doMainAction(::Callback((@(index) function(params) {afterSuccessBoughtItemAction(index)})(index), this),
                        this,
                        {index = index})
  }

  function afterSuccessBoughtItemAction(value)
  {
    updateTrophyInfo()

    focusIdx = value
    updateContent()
  }

  function updateButtons(obj = null)
  {
    if (!::checkObj(obj))
      return

    local isPurchased = isTrophyPurchased(obj.getValue())
    local mainActionData = trophy.getMainActionData()
    showSceneBtn("btn_main_action", !isPurchased)
    ::setDoubleTextToButton(scene,
                            "btn_main_action",
                            mainActionData?.btnName,
                            mainActionData?.btnColoredName || mainActionData?.btnName)
    showSceneBtn("warning_text", isPurchased)
  }
}
