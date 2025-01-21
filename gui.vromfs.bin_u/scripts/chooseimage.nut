from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { adjustWindowSizeByConfig, countSizeInItems } = require("%sqDagui/daguiUtil.nut")
let { ceil } = require("math")
let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let seenList = require("%scripts/seen/seenList.nut")
let stdMath = require("%sqstd/math.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { toggleUnlockFav, initUnlockFavObj, toggleUnlockFavButton } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { placePriceTextToButton, warningIfGold } = require("%scripts/viewUtils/objectTextUpdate.nut")
let { getUnlockTitle } = require("%scripts/unlocks/unlocksViewModule.nut")
let { getUnlockConditions } = require("%scripts/unlocks/unlocksConditions.nut")
let { getUnlockById } = require("%scripts/unlocks/unlocksCache.nut")
let { getUnlockCost } = require("%scripts/unlocks/unlocksModule.nut")
let { buyUnlock } = require("%scripts/unlocks/unlocksAction.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let purchaseConfirmation = require("%scripts/purchase/purchaseConfirmationHandler.nut")
let { findItemById } = require("%scripts/items/itemsManager.nut")
let { generatePaginator, paginator_set_unseen } = require("%scripts/viewUtils/paginator.nut")
let { getProfileAvatarFrames } = require("%scripts/user/profileAppearance.nut")
let { USEROPT_PILOT } = require("%scripts/options/optionsExtNames.nut")
let { getUserInfo } = require("%scripts/user/usersInfoManager.nut")
let { userIdStr } = require("%scripts/user/profileStates.nut")

/*
  config = {
    options = [{ image = img1 }, { image = img2, height = 50 }]
    tooltipObjFunc = function(obj, value)  - function to generate custom tooltip for item.
                                             must return bool if filled correct
    value = 0
  }
*/
::gui_choose_image <- function gui_choose_image(applyFunc, owner, scene = null) {
  let params = { owner, applyFunc }
  if (scene != null)
    params.scene <- scene

  handlersManager.loadHandler(gui_handlers.ChooseImage, params)
}

function getAvatarsData() {
  let pilotsOpt = ::get_option(USEROPT_PILOT)
  return pilotsOpt.items.filter(@(option) option?.show ?? true)
}

function getStoredAvatarIndex() {
  let pilotsOpt = ::get_option(USEROPT_PILOT)
  let unlockId = pilotsOpt.items[pilotsOpt.value].unlockId
  let index = pilotsOpt.items
    .filter(@(option) option?.show ?? true)
    .findindex(@(v) v.unlockId == unlockId) ?? 0
  return index
}

function getStoredFrameIndex() {
  let userInfo = getUserInfo(userIdStr.get())
  if (userInfo == null || userInfo.frame == "")
    return 0

  return getProfileAvatarFrames().findindex(@(v) v.id == userInfo?.frame) ?? 0
}

let menuItems = [
  {
    id = "pilotIcon"
    loc = "profile/choose_profile_icon"
    listId = "avatars_list"
    listDataFn = getAvatarsData
    initIndexFn = getStoredAvatarIndex
  },
  {
    id = "frame"
    loc = "profile/choose_frame"
    listId = "frames_list"
    listDataFn = getProfileAvatarFrames
    initIndexFn = getStoredFrameIndex
  }
]

gui_handlers.ChooseImage <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/chooseImage/chooseImage.blk"
  owner = null
  applyFunc = null

  itemsPerPage = 1
  isPageFill = false
  imageButtonSize = "1@avatarButtonSize + 2@blockInterval"
  imageButtonInterval = 0
  minAmountButtons = 8

  currentListId = ""
  currentListValues = null

  function initScreen() {
    this.init()
    showObjById("btn_select", showConsoleButtons.value, this.scene)
  }

  function init() {
    this.initCurrentListValues()
    this.initItemsPerPage()
    this.fillPages()
    this.fillMenu()
    move_mouse_on_child(this.getContentObj(), 0)
  }

  function initCurrentListValues() {
    this.currentListId = menuItems[0].id
    let handler = this
    this.currentListValues = menuItems.reduce(function(res, v) {
      res[v.id] <- {
        contentObj = handler.scene.findObject(v.listId)
        currentPage = -1
        listData = v.listDataFn()
        currentIndex = v.initIndexFn()
      }
      return res
    }, {})
  }

  function fillPages() {
    let handler = this
    menuItems.each(function(item) {
      handler.fillPage(item.id)
    })
  }

  function initItemsPerPage() {
    this.guiScene.applyPendingChanges(false)
    let listObj = this.getContentObj()
    let cfg = countSizeInItems(listObj, this.imageButtonSize, this.imageButtonSize, this.imageButtonInterval, this.imageButtonInterval)

    //update size for single page
    if (cfg.itemsCountX * cfg.itemsCountY > this.getItemsCount()) {
      let total = max(this.getItemsCount(), this.minAmountButtons)
      local columns = min(stdMath.calc_golden_ratio_columns(total), cfg.itemsCountX)
      local rows = ceil(total.tofloat() / columns).tointeger()
      if (rows > cfg.itemsCountY) {
        rows = cfg.itemsCountY
        columns = ceil(total.tofloat() / rows).tointeger()
      }
      cfg.itemsCountX = columns
      cfg.itemsCountY = rows
    }
    adjustWindowSizeByConfig(this.scene.findObject("wnd_frame"), listObj, cfg)

    this.itemsPerPage = cfg.itemsCountX * cfg.itemsCountY
  }

  function getContentBlk(imageType, start, end) {
    let listData = this.getListItems(imageType)

    if (imageType == "pilotIcon") {
      let avatars = []
      for (local i = start; i <= end; i++) {
        let item = listData[i]
        let avatar = {
          id          = i
          avatarImage = item?.image
          enabled     = item?.enabled
          haveCustomTooltip = false
          tooltipId   = item?.tooltipId
          unseenIcon = item?.seenListId && bhvUnseen.makeConfigStr(item?.seenListId, item?.seenEntity)
          hasGjnIcon = item?.marketplaceItemdefId != null && !item?.enabled
        }
        avatars.append(avatar)
      }
      return handyman.renderCached("%gui/profile/avatars.tpl", { avatars })
    }
    else {
      let avatarFrames = []
      for (local i = start; i <= end; i++) {
        let item = listData[i]
        let frame = {
          id = i
          frameImage = item.image
          tooltip = item.tooltip
        }
        avatarFrames.append(frame)
      }
      return handyman.renderCached("%gui/profile/avatarFrames.tpl", { avatarFrames })
    }
  }

  function fillPage(listId = null) {
    let selectedIndex = this.getSelectedIndex(listId)
    if (this.getCurrentPage(listId) == -1)
      this.setCurrentPage(max(0, (selectedIndex / this.itemsPerPage).tointeger()), listId)
    let listData = this.getListItems(listId)

    let start = this.getCurrentPage(listId) * this.itemsPerPage
    let end = min((this.getCurrentPage(listId) + 1) * this.itemsPerPage, listData.len()) - 1
    let selIdx = (selectedIndex >= start && selectedIndex <= end) ? (selectedIndex - start) : -1

    this.isPageFill = true
    let blk = this.getContentBlk(listId ?? this.currentListId, start, end)
    let contentObj = this.getContentObj(listId)
    this.guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
    contentObj.setValue(selIdx)
    this.isPageFill = false
  }

  function updatePaginator() {
    let paginatorObj = this.scene.findObject("paginator_place")
    let itemsCount = this.getItemsCount()
    generatePaginator(paginatorObj, this, this.getCurrentPage(), (itemsCount - 1) / this.itemsPerPage)
    let prevUnseen = this.getCurrentPage() ? this.getSeenConfig(0, this.getCurrentPage() * this.itemsPerPage - 1) : null
    let nextFirstIdx = (this.getCurrentPage() + 1) * this.itemsPerPage
    let nextUnseen = nextFirstIdx >= itemsCount ? null
      : this.getSeenConfig(nextFirstIdx, itemsCount - 1)
    paginator_set_unseen(paginatorObj,
      prevUnseen && bhvUnseen.makeConfigStr(prevUnseen.listId, prevUnseen.entities),
      nextUnseen && bhvUnseen.makeConfigStr(nextUnseen.listId, nextUnseen.entities))
  }

  function goToPage(obj) {
    this.markCurPageSeen()
    this.setCurrentPage(obj.to_page.tointeger())
    this.fillPage()
    this.updatePaginator()
    this.updateButtons()
  }

  function chooseImage(idx) {
    this.applyFunc.call(this.owner, this.currentListId, this.getListItems()[idx])
  }

  function onImageChoose(_obj) {
    let selIdx = this.getSelIconIdx()
    this.setSelectedIndex(selIdx)
    if (!(this.getListItems()?[selIdx].enabled ?? false))
      return

    this.chooseImage(selIdx)
  }

  function onImageSelect() {
    if (this.isPageFill)
      return

    this.updateButtons()

    let item = this.getListItems()?[this.getSelIconIdx()]

    if (item?.seenListId)
      seenList.get(item.seenListId).markSeen(item?.seenEntity)
  }

  function onDblClick() {
    let selIdx = this.getSelIconIdx()
    let option = this.getListItems()?[selIdx]

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
        let item = findItemById(option.marketplaceItemdefId)
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

  function onToggleFav(obj) {
    toggleUnlockFavButton(obj)
  }

  function onBuy() {
    let idx = this.getSelIconIdx()
    let unlockId = this.getListItems()?[idx].unlockId
    if (!unlockId)
      return

    let cost = getUnlockCost(unlockId)
    let unlockBlk = getUnlockById(unlockId)
    let unlockCfg = ::build_conditions_config(unlockBlk)
    let title = warningIfGold(loc("onlineShop/needMoneyQuestion", {
      purchase = colorize("unlockHeaderColor", getUnlockTitle(unlockCfg)),
      cost = cost.getTextAccordingToBalance()
    }), cost)
    let onSuccess = Callback(@() this.chooseImage(idx), this)
    let onOk = @() buyUnlock(unlockId, onSuccess)
    purchaseConfirmation("question_buy_unlock", title, onOk)
  }

  function goToMarketplace(item) {
    if (item?.hasLink())
      item.openLink()
  }

  function onAction() {
    let selIdx = this.getSelIconIdx()

    if (selIdx < 0)
      return

    let option = this.getListItems()?[selIdx]

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
      let item = findItemById(option.marketplaceItemdefId)
      if (item)
        this.goToMarketplace(item)
    }
  }

  function getSelIconIdx() {
    if (!checkObj(this.getContentObj()))
      return -1
    let idx = this.getContentObj().getValue()
    return idx < 0 ? idx : idx + this.getCurrentPage() * this.itemsPerPage
  }

  function updateButtons() {
    let option = this.getListItems()?[this.getSelIconIdx()]
    if (option == null) {
      showObjById("btn_buy", false, this.scene)
      showObjById("btn_select", false, this.scene)
      showObjById("btn_fav",  false, this.scene)
      return
    }

    let cost = getUnlockCost(option.unlockId)
    let canBuy = !option.enabled && !cost.isZero()
    showObjById("btn_buy", canBuy, this.scene)

    let isVisible = (option?.enabled ?? false) || option?.marketplaceItemdefId != null
    let btn = showObjById("btn_select", isVisible && !canBuy, this.scene)

    let isFavBtnVisible = !isVisible && !canBuy
    let favBtnObj = showObjById("btn_fav", isFavBtnVisible, this.scene)

    if (canBuy) {
      placePriceTextToButton(this.scene, "btn_buy", loc("mainmenu/btnOrder"), cost)
      return
    }

    if (isFavBtnVisible) {
      initUnlockFavObj(option.unlockId, favBtnObj)
      return
    }

    if (!isVisible)
      return

    if (option?.enabled) {
      btn.setValue(loc("mainmenu/btnSelect"))
      btn.show(showConsoleButtons.value)
      return
    }

    let item = ::ItemsManager.getInventoryItemById(option.marketplaceItemdefId)

    if (item != null)
      btn.setValue(loc("item/consume/coupon"))
    else
      btn.setValue(loc("msgbox/btn_find_on_marketplace"))
  }

  function goBack() {
    this.markCurPageSeen()
    this.scene.findObject("wnd_frame").show(false)
  }

  function getSeenConfig(start, end) {
    let res = {
      listId = null
      entities = []
    }
    for (local i = end; i >= start; i--) {
      let item = this.getListItems()[i]
      if (!item?.seenListId || !item?.seenEntity)
        continue

      res.listId = item.seenListId
      res.entities.append(item.seenEntity)
    }
    return res.listId ? res : null
  }

  function markCurPageSeen() {
    let seenConfig = this.getSeenConfig(this.getCurrentPage() * this.itemsPerPage,
      min((this.getCurrentPage() + 1) * this.itemsPerPage, this.getItemsCount()) - 1)
    if (seenConfig)
      seenList.get(seenConfig.listId).markSeen(seenConfig.entities)
  }

  function fillMenu() {
    let tabs = menuItems.map(@(v, idx) {
      id = v.id
      tabName = loc(v.loc)
      navImagesText = ::get_navigation_images_text(idx, menuItems.len())
    })

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", { tabs })

    let listObj = this.scene.findObject("image_types")
    this.guiScene.replaceContentFromText(listObj, data, data.len(), this)
    listObj.setValue(0)
  }

  function switchImagesList(index) {
    this.currentListId = menuItems[index].id
    let listsNest = this.scene.findObject("listsNest")
    menuItems.each(function(v, idx) {
      let list = listsNest.findObject(v.listId)
      list.show(idx == index)
    })

    this.updatePaginator()
    this.updateButtons()
  }

  function onImageTypeSelect(obj) {
    let index = obj.getValue()
    if (index < 0 || index > menuItems.len() - 1)
      return
    this.switchImagesList(index)
  }

  getContentObj = @(imageType = null) this.currentListValues[imageType ?? this.currentListId].contentObj
  getListItems = @(imageType = null) this.currentListValues[imageType ?? this.currentListId].listData
  getItemsCount = @(imageType = null) this.getListItems(imageType).len()

  getCurrentPage = @(imageType = null) this.currentListValues[imageType ?? this.currentListId].currentPage
  setCurrentPage = @(value, imageType = null) this.currentListValues[imageType ?? this.currentListId].currentPage = value

  getSelectedIndex = @(imageType = null) this.currentListValues[imageType ?? this.currentListId].currentIndex
  setSelectedIndex = @(value, imageType = null) this.currentListValues[imageType ?? this.currentListId].currentIndex = value
}
