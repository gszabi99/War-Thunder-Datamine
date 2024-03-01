//-file:plus-string
from "%scripts/dagui_natives.nut" import get_trophy_info
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child } = require("%scripts/baseGuiHandlerManagerWT.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { ceil, floor, sqrt } = require("math")

let { setDoubleTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let itemInfoHandler = require("%scripts/items/itemInfoHandler.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

gui_handlers.TrophyGroupShopWnd <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/modalSceneWithGamercard.blk"
  sceneTplName = "%gui/items/trophyGroupShop.tpl"

  trophy = null
  trophyInfo = null
  bitMask = null
  infoHandler = null

  focusIdx = -1

  function initScreen() {
    this.updateTrophyInfo()
    this.updateContent()
  }

  function updateContent() {
    this.fillTrophiesList()
    this.setDescription()
    this.updateHeader()
    this.setupSelection()
  }

  function setDescription() {
    this.infoHandler?.updateHandlerData(this.trophy)
  }

  function setupSelection() {
    for (local i = 0; i < this.trophy.numTotal; i++)
      if (!this.isTrophyPurchased(i)) {
        let listObj = this.getItemsListObj()
        listObj.setValue(i)
        move_mouse_on_child(listObj, i)
        return
      }
  }

  function updateTrophyInfo() {
    this.trophyInfo = get_trophy_info(this.trophy.id)
    this.loadBitMask()
  }

  function loadBitMask() {
    this.bitMask = getTblValue("openMask", this.trophyInfo)
    if (this.bitMask)
      return

    this.bitMask = 0
  }

  function updateHeader() {
    let headerObj = this.scene.findObject("group_trophy_header")
    if (!checkObj(headerObj))
      return

    let restText = getTblValue("openCount", this.trophyInfo, 0) + loc("ui/slash") + this.trophy.numTotal
    headerObj.setValue(loc("mainmenu/itemReceived") + loc("ui/parentheses/space", { text = restText }))
  }

  function getMaxSizeInItems(reduceSize = false) {
    let freeWidth = this.guiScene.calcString("1@trophiesGroupAvailableWidth", null)
    let freeHeight = this.guiScene.calcString("1@requiredItemsInColumnInPixels", null)

    let singleItemSizeTable = this.countSize({ w = 1, h = 1 }, reduceSize)

    let freeRow = freeWidth / singleItemSizeTable.width
    let freeColumn = freeHeight / singleItemSizeTable.height

    return { row = freeRow, column = freeColumn }
  }

  function updateScreenSize() {
    local maxAvailRatio = this.getMaxSizeInItems()
    let reduceSize = (maxAvailRatio.row * maxAvailRatio.column) < this.trophy.numTotal
    if (reduceSize)
      maxAvailRatio = this.getMaxSizeInItems(true)

    local itemsInRow = 0
    local itemsInColumn = sqrt(this.trophy.numTotal).tointeger()
    for (local i = itemsInColumn; i > 0; i--) {
      let columns = this.trophy.numTotal / i
      if (columns > maxAvailRatio.column)
        break

      if (columns * i != this.trophy.numTotal)
        continue

      itemsInRow = columns
      break
    }

    if (itemsInRow == 0) {
      itemsInRow =  floor(sqrt((maxAvailRatio.row.tofloat() / maxAvailRatio.column) * this.trophy.numTotal + 0.5)) || 1
      itemsInColumn = ceil(this.trophy.numTotal / itemsInRow)
    }

    return this.countSize({ w = itemsInRow, h = itemsInColumn }, reduceSize)
  }

  function countSize(ratio, reduceSize = false) {
    let mult = reduceSize ? "0.5" : "1"
    let height = ratio.h * this.guiScene.calcString(mult + "@itemHeight + 1@itemSpacing", null)
    let width = ratio.w * this.guiScene.calcString(mult + "@itemWidth + 1@itemSpacing", null)

    return { width = width, height = height, smallItems = reduceSize ? "yes" : "no" }
  }

  function fillTrophiesList() {
    let view = this.updateScreenSize()
    view.trophyItems <- ""

    for (local i = 0; i < this.trophy.numTotal; i++) {
      let isOpened = this.isTrophyPurchased(i)
      view.trophyItems += handyman.renderCached(("%gui/items/item.tpl"), {
        items = this.trophy.getViewData({
          showPrice = false,
          contentIcon = false,
          openedPicture = isOpened,
          showTooltip = !isOpened,
          showAction = !isOpened,
          itemHighlight = !isOpened,
          isItemLocked = isOpened,
          itemIndex = i.tostring()
        }) })
    }

    let data = handyman.renderCached(this.sceneTplName, view)
    this.guiScene.replaceContentFromText(this.scene.findObject("root-box"), data, data.len(), this)
    this.infoHandler = itemInfoHandler(this.scene.findObject("item_info_desc_place"))
  }

  function isTrophyPurchased(value) {
    return stdMath.is_bit_set(this.bitMask, value)
  }

  function onItemAction(obj) {
    if (checkObj(obj) && obj?.holderId)
      this.doAction(obj.holderId.tointeger())
  }

  onSelectedItemAction = @() this.doAction(this.getItemsListObj().getValue())

  function doAction(index) {
    this.trophy.doMainAction(Callback( function(_params) { this.afterSuccessBoughtItemAction(index) }, this),
                        this,
                        { index = index })
  }

  function afterSuccessBoughtItemAction(value) {
    this.updateTrophyInfo()

    this.focusIdx = value
    this.updateContent()
  }

  function onItemsListFocusChange() {
    if (this.isValid())
      this.updateButtonsBar()
  }

  function getItemsListObj() {
    return this.scene.findObject("items_list")
  }

  function updateButtonsBar() {
    let isButtonsBarVisible = !showConsoleButtons.value || this.getItemsListObj().isHovered()
    showObjById("item_actions_bar", isButtonsBarVisible, this.scene)
  }

  function updateButtons(obj = null) {
    if (!checkObj(obj))
      return

    let isPurchased = this.isTrophyPurchased(obj.getValue())
    let mainActionData = this.trophy.getMainActionData()
    showObjById("btn_main_action", !isPurchased, this.scene)
    setDoubleTextToButton(this.scene,
      "btn_main_action",
      mainActionData?.btnName,
      mainActionData?.btnColoredName || mainActionData?.btnName)
    showObjById("warning_text", isPurchased, this.scene)
  }
}
