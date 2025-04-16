from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { generatePaginator } = require("%scripts/viewUtils/paginator.nut")
let { openPopupFilter } = require("%scripts/popups/popupFilterWidget.nut")






function openSelectionWindow(config, applyFunc, owner = null) {
  handlersManager.loadHandler(gui_handlers.SelectionWindow, {
                                  config = config
                                  owner = owner
                                  applyFunc = applyFunc
                                })
}

gui_handlers.SelectionWindow <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneTplName = "%gui/chooseImage/selectionWindow.tpl"

  config = null
  itemsData = null
  owner = null
  applyFunc = null
  choosenItem = null
  isItemWasSelected = false

  currentPage  = -1
  itemsPerPage = 1
  selectedIndex = -1
  contentObj = null
  searchString = null
  searchItems = null

  function getSceneTplView() {
    let config = this.config
    return {
      wndTitle = config?.title ?? ""
      hasSearchBox = config?.searchFn != null
      hasFilters = config?.filterFn != null
      hasDeleteBtn = config?.hasDeleteBtn
    }
  }

  function initScreen() {
    if (!this.config)
      return this.goBack()
    this.searchString = ""
    this.selectedIndex = this.config?.selectedIndex ?? 0
    this.initItemsPerPage()
    this.currentPage = max(0, (this.selectedIndex / this.itemsPerPage).tointeger())
    this.contentObj = this.scene.findObject("images_list")
    this.fillItemsList()
    this.fillPage()
    move_mouse_on_child(this.contentObj, 0)

    showObjById("btn_select", showConsoleButtons.get(), this.scene)
    if (this.config?.getFiltersView)
      this.initPopupFilter()
  }

  function fillItemsList() {
    if (this.config?.filterFn == null) {
      this.itemsData = this.config.items
    } else {
      this.itemsData = []
      foreach (item in this.config.items)
        if (this.config.filterFn(item))
          this.itemsData.append(item)
    }

    if (this.searchString && this.searchString != "")
      this.searchItems = this.config.searchFn(this.itemsData, this.searchString)
  }

  function initItemsPerPage() {
    this.guiScene.applyPendingChanges(false)
    let listObj = this.scene.findObject("images_list")
    let config = this.config
    let { itemsCountX, itemsCountY, sizeX, sizeY, spaceX, spaceY } = config
    let listObjWidth = itemsCountX * to_pixels(sizeX) + (itemsCountX + 1) * to_pixels(spaceX)
    let listObjHeight = itemsCountY * to_pixels(sizeY) + (itemsCountY + 1) * to_pixels(spaceY)
    listObj.size = $"{listObjWidth}, {listObjHeight}"
    this.itemsPerPage = itemsCountX * itemsCountY
  }

  function fillPage() {
    let itemsForChoose = []
    let items = this.searchItems ?? this.itemsData
    let start = this.currentPage * this.itemsPerPage
    let end = min((this.currentPage + 1) * this.itemsPerPage, items.len()) - 1
    let selIdx = (this.selectedIndex >= start && this.selectedIndex <= end) ? (this.selectedIndex - start) : -1

    for (local i = start; i <= end; i++) {
      let item = items[i]
      let itemView = {
        id = $"item_{i-start}"
        image = item?.image
        enabled = item?.enabled ?? false
        tooltipId = this.config?.getTooltip(item)
        tooltipText = item?.tooltipText
      }
      itemsForChoose.append(itemView)
    }

    let { spaceX, spaceY, sizeX, sizeY } = this.config
    let blk = handyman.renderCached("%gui/selectionWindowItem.tpl",
      {itemsForChoose, spaceX, spaceY, sizeX, sizeY})
    this.guiScene.replaceContentFromText(this.contentObj, blk, blk.len(), this)
    this.updatePaginator()

    this.contentObj.setValue(selIdx)
  }

  function updatePaginator() {
    let paginatorObj = this.scene.findObject("paginator_place")
    generatePaginator(paginatorObj, this, this.currentPage, (this.itemsData.len() - 1) / this.itemsPerPage)
  }

  function goToPage(obj) {
    this.currentPage = obj.to_page.tointeger()
    this.fillPage()
  }

  function onAction() {
    let selIdx = this.getSelIconIdx()
    if (selIdx < 0)
      return

    let item = this.itemsData?[selIdx]
    if (!item)
      return
    this.chooseItem(selIdx)
  }

  function chooseItem(idx) {
    let items = this.searchItems ?? this.itemsData
    this.choosenItem = items?[idx]
    this.isItemWasSelected = true
    this.goBack()
  }

  function onImageChoose(_obj) {
    let selIdx = this.getSelIconIdx()
    this.selectedIndex = selIdx
    if (!(this.itemsData?[selIdx].enabled ?? false))
      return

    this.chooseItem(selIdx)
  }

  function getSelIconIdx() {
    if (!this.contentObj?.isValid())
      return -1
    let idx = this.contentObj.getValue()
    return idx < 0 ? idx : idx + this.currentPage * this.itemsPerPage
  }

  function afterModalDestroy() {
    if (!this.applyFunc || !this.isItemWasSelected)
      return

    if (this.owner)
      this.applyFunc.call(this.choosenItem)
    else
      this.applyFunc(this.choosenItem)
  }

  function onDeleteBtn() {
    this.chooseItem(-1)
  }

  function onChangeFilterItem(objId, typeName, value) {
    this.config.onChangeFilterItem(objId, typeName, value)
    this.fillItemsList()
    this.fillPage()
  }

  function getFiltersView() {
    return this.config.getFiltersView()
  }

  function initPopupFilter() {
    let nestObj = this.scene.findObject("filter_nest")
    openPopupFilter({
      scene = nestObj
      onChangeFn = this.onChangeFilterItem.bindenv(this)
      filterTypesFn = this.getFiltersView.bindenv(this)
    })
  }

  function onSearchEditBoxChangeValue(obj) {
    this.searchString = obj.getValue()
    if (this.searchString == "")
      this.searchItems = null
    else
      this.searchItems = this.config.searchFn(this.itemsData, this.searchString)
    this.fillPage()
  }

  function onSearchCancelClick(_obj) {
    this.searchCancel()
  }

  function onSearchEditBoxCancelEdit(_obj) {
    if (this.searchString == "" || this.searchString == null) {
      this.goBack()
      return
    }
    this.searchCancel()
  }

  function searchCancel() {
    if (this.searchItems != null) {
      this.searchItems = null
      this.fillPage()
    }
    this.searchString = ""
    let obj = this.scene.findObject("search_edit_box")
    if (obj.isValid()) {
      obj.setValue("")
      
      obj.enable(false)
      obj.enable(true)
    }
  }
}

return {
  openSelectionWindow
}
