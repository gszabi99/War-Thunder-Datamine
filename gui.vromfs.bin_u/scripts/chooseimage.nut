//checked for plus_string
from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let { ceil } = require("math")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { isUnlockFav, toggleUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { placePriceTextToButton } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getUnlockTitle } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockConditions } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")

/*
  config = {
    options = [{ image = img1 }, { image = img2, height = 50 }]
    tooltipObjFunc = function(obj, value)  - function to generate custom tooltip for item.
                                             must return bool if filled correct
    value = 0
  }
*/
::gui_choose_image <- function gui_choose_image(config, applyFunc, owner) {
  ::handlersManager.loadHandler(::gui_handlers.ChooseImage, {
                                  config = config
                                  owner = owner
                                  applyFunc = applyFunc
                                })
}

::gui_handlers.ChooseImage <- class extends ::gui_handlers.BaseGuiHandlerWT {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/chooseImage/chooseImage.blk"

  config = null
  options = null
  owner = null
  applyFunc = null
  choosenValue = null

  currentPage  = -1
  itemsPerPage = 1
  valueInited = false
  isPageFill = false
  imageButtonSize = "1@avatarButtonSize"
  imageButtonInterval = 0
  minAmountButtons = 8

  value = -1
  contentObj = null

  function initScreen() {
    if (!this.config || !("options" in this.config))
      return this.goBack()

    this.options = []
    let configValue = ("value" in this.config) ? this.config.value : -1
    foreach (idx, option in this.config.options) {
      let isVisible = getTblValue("show", option, true)
      if (!isVisible)
        continue

      if (this.value < 0 || idx == configValue)
        this.value = this.options.len()
      this.options.append(option)
    }

    this.initItemsPerPage()

    this.currentPage = max(0, (this.value / this.itemsPerPage).tointeger())

    this.contentObj = this.scene.findObject("images_list")
    this.fillPage()
    ::move_mouse_on_child(this.contentObj, 0)

    this.showSceneBtn("btn_select", ::show_console_buttons)
  }

  function initItemsPerPage() {
    this.guiScene.applyPendingChanges(false)
    let listObj = this.scene.findObject("images_list")
    let cfg = ::g_dagui_utils.countSizeInItems(listObj, this.imageButtonSize, this.imageButtonSize, this.imageButtonInterval, this.imageButtonInterval)

    //update size for single page
    if (cfg.itemsCountX * cfg.itemsCountY > this.options.len()) {
      let total = max(this.options.len(), this.minAmountButtons)
      local columns = min(stdMath.calc_golden_ratio_columns(total), cfg.itemsCountX)
      local rows = ceil(total.tofloat() / columns).tointeger()
      if (rows > cfg.itemsCountY) {
        rows = cfg.itemsCountY
        columns = ceil(total.tofloat() / rows).tointeger()
      }
      cfg.itemsCountX = columns
      cfg.itemsCountY = rows
    }

    ::g_dagui_utils.adjustWindowSizeByConfig(this.scene.findObject("wnd_frame"), listObj, cfg)
    this.itemsPerPage = cfg.itemsCountX * cfg.itemsCountY
  }

  function fillPage() {
    let view = {
      avatars = []
    }

    let haveCustomTooltip = this.getTooltipObjFunc() != null
    let start = this.currentPage * this.itemsPerPage
    let end = min((this.currentPage + 1) * this.itemsPerPage, this.options.len()) - 1
    let selIdx = this.valueInited ? min(this.contentObj.getValue(), end - start)
      : clamp(this.value - start, 0, end - start)
    for (local i = start; i <= end; i++) {
      let item = this.options[i]
      let avatar = {
        id          = i
        avatarImage = item?.image
        enabled     = item?.enabled
        haveCustomTooltip = haveCustomTooltip
        tooltipId   = haveCustomTooltip ? null : getTblValue("tooltipId", item)
        unseenIcon = item?.seenListId && bhvUnseen.makeConfigStr(item?.seenListId, item?.seenEntity)
        hasGjnIcon = item?.marketplaceItemdefId != null && !item?.enabled
      }
      view.avatars.append(avatar)
    }

    this.isPageFill = true
    let blk = ::handyman.renderCached("%gui/avatars.tpl", view)
    this.guiScene.replaceContentFromText(this.contentObj, blk, blk.len(), this)
    this.updatePaginator()

    this.contentObj.setValue(selIdx)
    this.valueInited = true
    this.isPageFill = false

    this.updateButtons()
  }

  function updatePaginator() {
    let paginatorObj = this.scene.findObject("paginator_place")
    ::generatePaginator(paginatorObj, this, this.currentPage, (this.options.len() - 1) / this.itemsPerPage)

    let prevUnseen = this.currentPage ? this.getSeenConfig(0, this.currentPage * this.itemsPerPage - 1) : null
    let nextFirstIdx = (this.currentPage + 1) * this.itemsPerPage
    let nextUnseen = nextFirstIdx >= this.options.len() ? null
      : this.getSeenConfig(nextFirstIdx, this.options.len() - 1)
    ::paginator_set_unseen(paginatorObj,
      prevUnseen && bhvUnseen.makeConfigStr(prevUnseen.listId, prevUnseen.entities),
      nextUnseen && bhvUnseen.makeConfigStr(nextUnseen.listId, nextUnseen.entities))
  }

  function goToPage(obj) {
    this.markCurPageSeen()
    this.currentPage = obj.to_page.tointeger()
    this.fillPage()
  }

  function chooseImage(idx) {
    this.choosenValue = idx
    this.goBack()
  }

  function onImageChoose(_obj) {
    let selIdx = this.getSelIconIdx()

    if (!(this.options?[selIdx].enabled ?? false))
      return

    this.chooseImage(selIdx)
  }

  function onImageSelect() {
    if (this.isPageFill)
      return

    this.updateButtons()

    let item = this.options?[this.getSelIconIdx()]

    if (item?.seenListId)
      seenList.get(item.seenListId).markSeen(item?.seenEntity)
  }

  function onDblClick() {
    let selIdx = this.getSelIconIdx()
    let option = this.options?[selIdx]

    if (!option)
      return

    if (option.enabled) {
      this.chooseImage(selIdx)
      return
    }

    let cost = getUnlockCost(option.unlockId)
    let canBuy = !cost.isZero()
    if (canBuy) {
      this.onBuy()
      return
    }

    if (option?.marketplaceItemdefId) {
      let inventoryItem = ::ItemsManager.getInventoryItemById(option.marketplaceItemdefId)
      if (inventoryItem != null)
        inventoryItem.consume(Callback(function(result) {
          if (result?.success ?? false)
            this.chooseImage(selIdx)
        }, this), null)
      else {
        let item = ::ItemsManager.findItemById(option.marketplaceItemdefId)
        if (item)
          this.goToMarketplace(item)
      }
      return
    }

    if (getUnlockConditions(getUnlockById(option.unlockId)?.mode).len() > 0) {
      toggleUnlockFav(option.unlockId)
      this.updateButtons()
    }
  }

  function onToggleFav() {
    let idx = this.getSelIconIdx()
    if (idx == -1)
      return

    let option = this.options[idx]
    toggleUnlockFav(option.unlockId)
    this.updateButtons()
  }

  function onBuy() {
    let idx = this.getSelIconIdx()
    let unlockId = this.options?[idx].unlockId
    if (!unlockId)
      return

    let cost = getUnlockCost(unlockId)
    let unlockBlk = getUnlockById(unlockId)
    let unlockCfg = ::build_conditions_config(unlockBlk)
    let title = ::warningIfGold(loc("onlineShop/needMoneyQuestion", {
      purchase = colorize("unlockHeaderColor", getUnlockTitle(unlockCfg)),
      cost = cost.getTextAccordingToBalance()
    }), cost)
    let onSuccess = Callback(@() this.chooseImage(idx), this)
    let onOk = @() ::g_unlocks.buyUnlock(unlockId, onSuccess)
    this.msgBox("question_buy_unlock", title, [["ok", onOk], ["cancel"]], "cancel")
  }

  function goToMarketplace(item) {
    if (item?.hasLink())
      item.openLink()
  }

  function onAction() {
    let selIdx = this.getSelIconIdx()

    if (selIdx < 0)
      return

    let option = this.options?[selIdx]

    if ((option?.enabled ?? false) || option?.marketplaceItemdefId == null) {
      this.chooseImage(selIdx)
      return
    }

    let inventoryItem = ::ItemsManager.getInventoryItemById(option.marketplaceItemdefId)

    if (inventoryItem != null) {
      inventoryItem.consume(Callback(function(result) {
        if (result?.success ?? false)
          this.chooseImage(selIdx)
      }, this), null)
    }
    else {
      let item = ::ItemsManager.findItemById(option.marketplaceItemdefId)

      if (item)
        this.goToMarketplace(item)
    }
  }

  function getSelIconIdx() {
    if (!checkObj(this.contentObj))
      return -1
    return this.contentObj.getValue() + this.currentPage * this.itemsPerPage
  }

  function updateButtons() {
    let option = getTblValue(this.getSelIconIdx(), this.options)
    let cost = getUnlockCost(option.unlockId)
    let canBuy = !option.enabled && !cost.isZero()
    this.showSceneBtn("btn_buy", canBuy)

    let isVisible = (option?.enabled ?? false) || option?.marketplaceItemdefId != null
    let btn = this.showSceneBtn("btn_select", isVisible && !canBuy)

    let isFavBtnVisible = !isVisible && !canBuy
    let favBtnObj = this.showSceneBtn("btn_fav", isFavBtnVisible)

    if (canBuy) {
      placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnOrder"), cost)
      return
    }

    if (isFavBtnVisible) {
      favBtnObj.setValue(isUnlockFav(option.unlockId)
        ? loc("preloaderSettings/untrackProgress")
        : loc("preloaderSettings/trackProgress"))
      return
    }

    if (option?.enabled) {
      btn.setValue(loc("mainmenu/btnSelect"))
      return
    }

    let item = ::ItemsManager.getInventoryItemById(option.marketplaceItemdefId)

    if (item != null)
      btn.setValue(loc("item/consume/coupon"))
    else
      btn.setValue(loc("msgbox/btn_find_on_marketplace"))
  }

  function afterModalDestroy() {
    if (!this.applyFunc || this.choosenValue == null)
      return

    if (this.owner)
      this.applyFunc.call(this.owner, this.options[this.choosenValue])
    else
      this.applyFunc(this.options[this.choosenValue])
  }

  function getTooltipObjFunc() {
    return getTblValue("tooltipObjFunc", this.config)
  }

  function onImageTooltipOpen(obj) {
    let id = ::getTooltipObjId(obj)
    let func = this.getTooltipObjFunc()
    if (!id || !func)
      return

    let res = func(obj, id.tointeger())
    if (!res)
      obj["class"] = "empty"
  }

  function goBack() {
    this.markCurPageSeen()
    base.goBack()
  }

  function getSeenConfig(start, end) {
    let res = {
      listId = null
      entities = []
    }
    for (local i = end; i >= start; i--) {
      let item = this.options[i]
      if (!item?.seenListId || !item?.seenEntity)
        continue

      res.listId = item.seenListId
      res.entities.append(item.seenEntity)
    }
    return res.listId ? res : null
  }

  function markCurPageSeen() {
    let seenConfig = this.getSeenConfig(this.currentPage * this.itemsPerPage,
      min((this.currentPage + 1) * this.itemsPerPage, this.options.len()) - 1)
    if (seenConfig)
      seenList.get(seenConfig.listId).markSeen(seenConfig.entities)
  }
}
