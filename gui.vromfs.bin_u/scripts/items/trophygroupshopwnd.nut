let stdMath = require("std/math.nut")
let { setDoubleTextToButton } = require("scripts/viewUtils/objectTextUpdate.nut")
let itemInfoHandler = require("scripts/items/itemInfoHandler.nut")

::gui_start_open_trophy_group_shop_wnd <- function gui_start_open_trophy_group_shop_wnd(trophy)
{
  if (!trophy)
    return

  ::gui_start_modal_wnd(::gui_handlers.TrophyGroupShopWnd, {trophy = trophy})
}

::gui_handlers.TrophyGroupShopWnd <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/items/trophyGroupShop"

  trophy = null
  trophyInfo = null
  bitMask = null
  infoHandler = null

  focusIdx = -1

  function initScreen()
  {
    updateTrophyInfo()
    updateContent()
  }

  function updateContent()
  {
    fillTrophiesList()
    setDescription()
    updateHeader()
    setupSelection()
  }

  function setDescription()
  {
    infoHandler?.updateHandlerData(trophy)
  }

  function setupSelection()
  {
    for (local i = 0; i < trophy.numTotal; i++)
      if (!isTrophyPurchased(i))
      {
        let listObj = getItemsListObj()
        listObj.setValue(i)
        ::move_mouse_on_child(listObj, i)
        return
      }
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
    let headerObj = scene.findObject("group_trophy_header")
    if (!::checkObj(headerObj))
      return

    let restText = ::getTblValue("openCount", trophyInfo, 0) + ::loc("ui/slash") + trophy.numTotal
    headerObj.setValue(::loc("mainmenu/itemReceived") + ::loc("ui/parentheses/space", {text = restText}))
  }

  function getMaxSizeInItems(reduceSize = false)
  {
    let freeWidth = guiScene.calcString("1@trophiesGroupAvailableWidth", null)
    let freeHeight = guiScene.calcString("1@requiredItemsInColumnInPixels", null)

    let singleItemSizeTable = countSize({w = 1, h = 1}, reduceSize)

    let freeRow = freeWidth / singleItemSizeTable.width
    let freeColumn = freeHeight / singleItemSizeTable.height

    return {row = freeRow, column = freeColumn}
  }

  function updateScreenSize()
  {
    local maxAvailRatio = getMaxSizeInItems()
    let reduceSize = (maxAvailRatio.row * maxAvailRatio.column) < trophy.numTotal
    if (reduceSize)
      maxAvailRatio = getMaxSizeInItems(true)

    local itemsInRow = 0
    local itemsInColumn = ::sqrt(trophy.numTotal).tointeger()
    for (local i = itemsInColumn; i > 0; i--)
    {
      let columns = trophy.numTotal / i
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
    let mult = reduceSize? "0.5" : "1"
    let height = ratio.h * guiScene.calcString(mult + "@itemHeight + 1@itemSpacing", null)
    let width = ratio.w * guiScene.calcString(mult + "@itemWidth + 1@itemSpacing", null)

    return {width = width, height = height, smallItems = reduceSize? "yes" : "no"}
  }

  function fillTrophiesList()
  {
    let view = updateScreenSize()
    view.trophyItems <- ""

    for (local i = 0; i < trophy.numTotal; i++)
    {
      let isOpened = isTrophyPurchased(i)
      view.trophyItems += ::handyman.renderCached(("%gui/items/item"), {
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

    let data = ::handyman.renderCached(sceneTplName, view)
    guiScene.replaceContentFromText(scene.findObject("root-box"), data, data.len(), this)
    infoHandler = itemInfoHandler(scene.findObject("item_info_desc_place"))
  }

  function isTrophyPurchased(value)
  {
    return stdMath.is_bit_set(bitMask, value)
  }

  function onItemAction(obj)
  {
    if (::checkObj(obj) && obj?.holderId)
      doAction(obj.holderId.tointeger())
  }

  onSelectedItemAction = @() doAction(getItemsListObj().getValue())

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

  function onItemsListFocusChange()
  {
    if (isValid())
      updateButtonsBar()
  }

  function getItemsListObj()
  {
    return scene.findObject("items_list")
  }

  function updateButtonsBar()
  {
    let isButtonsBarVisible = !::show_console_buttons || getItemsListObj().isHovered()
    showSceneBtn("item_actions_bar", isButtonsBarVisible)
  }

  function updateButtons(obj = null)
  {
    if (!::checkObj(obj))
      return

    let isPurchased = isTrophyPurchased(obj.getValue())
    let mainActionData = trophy.getMainActionData()
    showSceneBtn("btn_main_action", !isPurchased)
    setDoubleTextToButton(scene,
      "btn_main_action",
      mainActionData?.btnName,
      mainActionData?.btnColoredName || mainActionData?.btnName)
    showSceneBtn("warning_text", isPurchased)
  }
}
