//-file:plus-string
from "%scripts/dagui_library.nut" import *
let u = require("%sqStdLibs/helpers/u.nut")

//checked for explicitness
#no-root-fallback
#explicit-this

let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let DataBlock = require("DataBlock")

let { registerPersistentDataFromRoot, PERSISTENT_DATA_PARAMS } = require("%sqStdLibs/scriptReloader/scriptReloader.nut")
const SEARCH_CATEGORIES_SAVE_ID = "chat/searchCategories"

::g_chat_categories <- {
  [PERSISTENT_DATA_PARAMS] = ["list", "listSorted", "defaultCategoryName", "searchCategories"]

  list = {}
  listSorted = []
  defaultCategoryName = ""
  searchCategories = []
}

::g_chat_categories.isEnabled <- function isEnabled() {
  return this.list.len() > 0 && hasFeature("ChatThreadCategories")
}

::g_chat_categories.onEventLoginComplete <- function onEventLoginComplete(_p) {
  this.initThreadCategories()
}

::g_chat_categories.initThreadCategories <- function initThreadCategories() {
  this.list.clear()
  this.listSorted.clear()
  this.searchCategories.clear()
  this.defaultCategoryName = ""

  let guiBlk = GUI.get()
  let listBlk = guiBlk?.chat_categories
  if (!u.isDataBlock(listBlk))
    return

  let total = listBlk.blockCount()
  for (local i = 0; i < total; i++) {
    let cBlk = listBlk.getBlock(i)
    let name = cBlk.getBlockName()
    let category = ::buildTableFromBlk(cBlk)
    category.id <- name
    this.list[name] <- category
    this.listSorted.append(category)

    if (cBlk?.isDefault == true || this.defaultCategoryName == "")
      this.defaultCategoryName = name
  }

  this.loadSearchCategories()
}

::g_chat_categories.loadSearchCategories <- function loadSearchCategories() {
  let blk = ::load_local_account_settings(SEARCH_CATEGORIES_SAVE_ID)
  if (u.isDataBlock(blk)) {
    foreach (cat in this.listSorted)
      if (blk?[cat.id])
        this.searchCategories.append(cat.id)
  }
  if (!this.searchCategories.len())
    this.searchCategories = u.map(this.listSorted, function(c) { return c.id })
}

::g_chat_categories.saveSearchCategories <- function saveSearchCategories() {
  local blk = null
  if (!this.isSearchAnyCategory()) {
    blk = DataBlock()
    foreach (catName in this.searchCategories)
      blk[catName] <- true
  }
  ::save_local_account_settings(SEARCH_CATEGORIES_SAVE_ID, blk)
}

::g_chat_categories.getSearchCategoriesLList <- function getSearchCategoriesLList() {
  return this.searchCategories
}

::g_chat_categories.isSearchAnyCategory <- function isSearchAnyCategory() {
  return this.searchCategories.len() == 0 || this.searchCategories.len() >= this.list.len()
}

::g_chat_categories.getCategoryNameText <- function getCategoryNameText(categoryName) {
  return loc("chat/category/" + categoryName)
}

::g_chat_categories.fillCategoriesListObj <- function fillCategoriesListObj(listObj, selCategoryName, handler) {
  if (!checkObj(listObj))
    return

  let view = {
    optionTag = "option"
    options = []
  }
  local selIdx = -1
  foreach (idx, category in this.listSorted) {
    let name = category.id
    if (name == selCategoryName)
      selIdx = idx

    view.options.append({
      text = this.getCategoryNameText(name)
      enabled = true
    })
  }

  let data = handyman.renderCached(("%gui/options/spinnerOptions.tpl"), view)
  listObj.getScene().replaceContentFromText(listObj, data, data.len(), handler)

  if (selIdx >= 0)
    listObj.setValue(selIdx)
}

::g_chat_categories.getSelCategoryNameByListObj <- function getSelCategoryNameByListObj(listObj, defValue) {
  if (!checkObj(listObj))
    return defValue

  let category = getTblValue(listObj.getValue(), this.listSorted)
  if (category)
    return category.id
  return defValue
}

::g_chat_categories.openChooseCategoriesMenu <- function openChooseCategoriesMenu(align = "top", alignObj = null) {
  if (!this.isEnabled())
    return

  let optionsList = []
  let curCategories = this.getSearchCategoriesLList()
  foreach (cat in this.listSorted)
    optionsList.append({
      text = this.getCategoryNameText(cat.id)
      value = cat.id
      selected = isInArray(cat.id, curCategories)
    })

  ::gui_start_multi_select_menu({
    list = optionsList
    onFinalApplyCb = function(values) { ::g_chat_categories._setSearchCategories(values) }
    align = align
    alignObj = alignObj
  })
}

::g_chat_categories._setSearchCategories <- function _setSearchCategories(newValues) {
  this.searchCategories = newValues
  this.saveSearchCategories()
  broadcastEvent("ChatSearchCategoriesChanged")
}

registerPersistentDataFromRoot("g_chat_categories")
subscribe_handler(::g_chat_categories, ::g_listener_priority.DEFAULT_HANDLER)