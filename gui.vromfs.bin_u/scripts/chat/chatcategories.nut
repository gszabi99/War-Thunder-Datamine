from "%scripts/dagui_library.nut" import *

let g_listener_priority = require("%scripts/g_listener_priority.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { saveLocalAccountSettings, loadLocalAccountSettings
} = require("%scripts/clientState/localProfile.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { subscribe_handler, broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { GUI } = require("%scripts/utils/configs.nut")
let DataBlock = require("DataBlock")
let { convertBlk } = require("%sqstd/datablock.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")

const SEARCH_CATEGORIES_SAVE_ID = "chat/searchCategories"

let chatDefaultCategoryName = persist("chatDefaultCategoryName", @() {val = ""})
let getChatDefaultCategoryName = @() chatDefaultCategoryName.val
let setChatDefaultCategoryName = @(v) chatDefaultCategoryName.val = v

let chatCategoriesList = persist("chatCategoriesList", @() {})
let chatCategoriesListSorted = persist("chatCategoriesListSorted", @() [])
let searchChatCategories = persist("searchChatCategories", @() [])

let g_chat_categories = {
  list = chatCategoriesList
  listSorted = chatCategoriesListSorted
  searchCategories = searchChatCategories
  getChatDefaultCategoryName
  setChatDefaultCategoryName
}

g_chat_categories.isEnabled <- function isEnabled() {
  return chatCategoriesList.len() > 0 && hasFeature("ChatThreadCategories")
}

g_chat_categories.onEventLoginComplete <- function onEventLoginComplete(_p) {
  this.initThreadCategories()
}

g_chat_categories.initThreadCategories <- function initThreadCategories() {
  chatCategoriesList.clear()
  chatCategoriesListSorted.clear()
  searchChatCategories.clear()
  setChatDefaultCategoryName("")

  let guiBlk = GUI.get()
  let listBlk = guiBlk?.chat_categories
  if (!u.isDataBlock(listBlk))
    return

  let total = listBlk.blockCount()
  for (local i = 0; i < total; i++) {
    let cBlk = listBlk.getBlock(i)
    let name = cBlk.getBlockName()
    let category = convertBlk(cBlk)
    category.id <- name
    chatCategoriesList[name] <- category
    chatCategoriesListSorted.append(category)

    if (cBlk?.isDefault == true || getChatDefaultCategoryName() == "")
      setChatDefaultCategoryName(name)
  }

  this.loadSearchCategories()
}

g_chat_categories.loadSearchCategories <- function loadSearchCategories() {
  let blk = loadLocalAccountSettings(SEARCH_CATEGORIES_SAVE_ID)
  if (u.isDataBlock(blk)) {
    foreach (cat in chatCategoriesListSorted)
      if (blk?[cat.id])
        searchChatCategories.append(cat.id)
  }
  if (!searchChatCategories.len())
    searchChatCategories.replace(chatCategoriesListSorted.map(function(c) { return c.id }))
}

g_chat_categories.saveSearchCategories <- function saveSearchCategories() {
  local blk = null
  if (!this.isSearchAnyCategory()) {
    blk = DataBlock()
    foreach (catName in searchChatCategories)
      blk[catName] <- true
  }
  saveLocalAccountSettings(SEARCH_CATEGORIES_SAVE_ID, blk)
}

g_chat_categories.getSearchCategoriesLList <- function getSearchCategoriesLList() {
  return searchChatCategories
}

g_chat_categories.isSearchAnyCategory <- function isSearchAnyCategory() {
  return searchChatCategories.len() == 0 || searchChatCategories.len() >= chatCategoriesList.len()
}

g_chat_categories.getCategoryNameText <- function getCategoryNameText(categoryName) {
  return loc($"chat/category/{categoryName}")
}

g_chat_categories.fillCategoriesListObj <- function fillCategoriesListObj(listObj, selCategoryName, handler) {
  if (!checkObj(listObj))
    return

  let view = {
    optionTag = "option"
    options = []
  }
  local selIdx = -1
  foreach (idx, category in chatCategoriesListSorted) {
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

g_chat_categories.getSelCategoryNameByListObj <- function getSelCategoryNameByListObj(listObj, defValue) {
  if (!checkObj(listObj))
    return defValue

  let category = getTblValue(listObj.getValue(), chatCategoriesListSorted)
  if (category)
    return category.id
  return defValue
}

g_chat_categories.openChooseCategoriesMenu <- function openChooseCategoriesMenu(align = "top", alignObj = null) {
  if (!this.isEnabled())
    return

  let optionsList = []
  let curCategories = this.getSearchCategoriesLList()
  foreach (cat in chatCategoriesListSorted)
    optionsList.append({
      text = this.getCategoryNameText(cat.id)
      value = cat.id
      selected = isInArray(cat.id, curCategories)
    })

  loadHandler(gui_handlers.MultiSelectMenu, {
    list = optionsList
    onFinalApplyCb = function(values) { g_chat_categories._setSearchCategories(values) }
    align = align
    alignObj = alignObj
  })
}

g_chat_categories._setSearchCategories <- function _setSearchCategories(newValues) {
  searchChatCategories.replace(newValues)
  this.saveSearchCategories()
  broadcastEvent("ChatSearchCategoriesChanged")
}

subscribe_handler(g_chat_categories, g_listener_priority.DEFAULT_HANDLER)
::g_chat_categories <- g_chat_categories
return { g_chat_categories }