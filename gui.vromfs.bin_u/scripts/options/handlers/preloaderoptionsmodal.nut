from "%scripts/dagui_natives.nut" import is_mouse_last_time_used, get_cur_gui_scene
from "%scripts/dagui_library.nut" import *

let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getLoadingBgName, getFilterBgList, isBgUnlocked, getUnlockIdByLoadingBg,
  getLoadingBgTooltip } = require("%scripts/loading/loadingBgData.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { isLoadingScreenBanned,
  toggleLoadingScreenBan } = require("%scripts/options/preloaderOptions.nut")
let { havePremium } = require("%scripts/user/premium.nut")
let { getTooltipType } = require("%scripts/utils/genericTooltipTypes.nut")
let { isUnlockFav, toggleUnlockFav } = require("%scripts/unlocks/favoriteUnlocks.nut")
let { utf8ToLower, trim } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { defer } = require("dagor.workcycle")

local class PreloaderOptionsModal (gui_handlers.BaseGuiHandlerWT) {
  sceneBlkName = "%gui/options/preloaderOptions.blk"

  isHovered = false
  hoveredId = null
  selectedId = null

  function initScreen() {
    let listboxFilterHolder = this.scene.findObject("listbox_filter_holder")
    this.guiScene.replaceContent(listboxFilterHolder, "%gui/chapter_include_filter.blk", this)

    this.fillLoadingScreenList()
    showObjById("items_list_msg", false, this.scene).setValue(loc("shop/search/global/notFound"))

    this.updateListItems()
    this.updateButtons()
  }

  function fillLoadingScreenList() {
    let view = { items = [] }
    foreach (screenId in getFilterBgList()) {
      let isUnlocked = isBgUnlocked(screenId)
      view.items.append({
        itemTag = isUnlocked ? "mission_item_unlocked" : "mission_item_locked"
        imgTag = isUnlocked ? "banImg" : null
        id = screenId
        itemText = getLoadingBgName(screenId)
        tooltip = isUnlocked ? getLoadingBgTooltip(screenId) : null
        tooltipObjId = !isUnlocked ? getTooltipType("UNLOCK_SHORT").getTooltipId(getUnlockIdByLoadingBg(screenId)) : null
        isNeedOnHover = showConsoleButtons.value
      })
    }

    view.items.sort(@(a, b) a.itemText <=> b.itemText)
    let selectedIdx = view.items.findindex((@(a) a.id == this.selectedId).bindenv(this)) ?? 0
    let data = handyman.renderCached("%gui/missions/missionBoxItemsList.tpl", view)
    let itemsListObj = this.scene.findObject("items_list")
    this.guiScene.replaceContentFromText(itemsListObj, data, data.len(), this)
    itemsListObj.setValue(selectedIdx)

    move_mouse_on_child_by_value(itemsListObj)
  }

  function updateListItems() {
    let itemsListObj = this.scene.findObject("items_list")
    let numItems = itemsListObj.childrenCount()
    for (local i = 0; i < numItems; i++) {
      let itemObj = itemsListObj.getChild(i)
      itemObj.banned = havePremium.value && isLoadingScreenBanned(itemObj.id) ? "yes" : "no"
    }
  }

  function updateBg() {
    animBgLoad(this.selectedId, this.scene.findObject("animated_bg_picture"))
  }

  function updateSelectedListItem() {
    this.scene.findObject(this.selectedId).banned = isLoadingScreenBanned(this.selectedId) ? "yes" : "no"
  }

  function updateButtons() {
    let isMouseMode = !showConsoleButtons.value || is_mouse_last_time_used()
    let isUnlocked = isBgUnlocked(this.selectedId)
    let isBtnVisible = (isMouseMode && this.scene.findObject(this.selectedId).isVisible()) || this.hoveredId == this.selectedId
    let isBanBtnVisible = isUnlocked && isBtnVisible
    let isFavBtnVisible = !isUnlocked && isBtnVisible

    showObjById("btn_select", !isMouseMode && this.hoveredId != this.selectedId && this.isHovered, this.scene)

    let banBtnObj = showObjById("btn_ban", isBanBtnVisible, this.scene)
    if (isBanBtnVisible)
      banBtnObj.setValue(havePremium.value && isLoadingScreenBanned(this.selectedId)
        ? loc("maps/preferences/removeBan")
        : loc("maps/preferences/ban"))

    let favBtnObj = showObjById("btn_fav", isFavBtnVisible, this.scene)
    if (isFavBtnVisible) {
      let unlockId = getUnlockIdByLoadingBg(this.selectedId)
      favBtnObj.setValue(isUnlockFav(unlockId)
        ? loc("preloaderSettings/untrackProgress")
        : loc("preloaderSettings/trackProgress"))
    }
  }

  canBan = @() getFilterBgList()
    .filter(@(id) isBgUnlocked(id) && !isLoadingScreenBanned(id)).len() > 1

  function toggleBan() {
    if (!this.isValid())
      return

    if (!havePremium.value)
      return this.msgBox("need_money", loc("mainmenu/onlyWithPremium"), [
        ["purchase", (@() this.onOnlineShopPremium()).bindenv(this)],
        ["cancel"]], "purchase")

    if (!isLoadingScreenBanned(this.selectedId) && !this.canBan())
      return this.msgBox("max_banned_count", loc("preloaderSettings/maxBannedCount"), [
        ["ok"]], "ok")

    toggleLoadingScreenBan(this.selectedId)

    this.updateButtons()
    this.updateSelectedListItem()
  }

  function onToggleFav() {
    let unlockId = getUnlockIdByLoadingBg(this.selectedId)
    toggleUnlockFav(unlockId)
    this.updateButtons()
  }

  function onItemDblClick() {
    if (!showConsoleButtons.value)
      this.toggleBan()
  }

  function onItemHover(obj) {
    if (!showConsoleButtons.value)
      return

    if (!obj.isHovered() && obj.id != this.hoveredId)
      return

    this.isHovered = obj.isHovered()
    this.hoveredId = this.isHovered ? obj.id : null

    this.updateButtons()
  }

  function onItemSelect(_obj) {
    let itemsListObj = this.scene.findObject("items_list")
    this.selectedId = itemsListObj.getChild(itemsListObj.getValue()).id

    this.updateBg()
    this.updateButtons()
    this.guiScene.discardUnusedPicture()
  }

  function onFilterEditBoxCancel() {
    let editBoxObj = this.scene.findObject("filter_edit_box")
    if (editBoxObj.getValue() != "")
      editBoxObj.setValue("")
    else
      this.guiScene.performDelayed(this, @() this.isValid() && this.goBack())
  }

  function onFilterEditBoxChangeValue(obj) {
    let value = obj.getValue()
    let searchStr = utf8ToLower(trim(value))
    local isFound = false
    let itemsListObj = this.scene.findObject("items_list")
    let numItems = itemsListObj.childrenCount()

    this.guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < numItems; i++) {
      let itemObj = itemsListObj.getChild(i)
      let titleStr = itemObj.findObject($"txt_{itemObj.id}").getValue()
      let isVisible = searchStr == "" || utf8ToLower(titleStr).contains(searchStr)
      itemObj.show(isVisible)
      itemObj.enable(isVisible)
      isFound = isFound || isVisible
    }

    showObjById("filter_edit_cancel_btn", value.len() != 0, this.scene)
    showObjById("items_list_msg", !isFound, this.scene)
    this.guiScene.setUpdatesEnabled(true, true)

    this.updateButtons()
  }

  function onEventProfileUpdated(_p) {
    this.updateListItems()
    this.updateButtons()
  }

  onFilterEditBoxActivate = @() null
  onChapterSelect = @() null

  function onDestroy() {
    defer(@() get_cur_gui_scene().discardUnusedPicture())
  }
}

gui_handlers.PreloaderOptionsModal <- PreloaderOptionsModal

return @(selectedId = null) handlersManager.loadHandler(PreloaderOptionsModal, { selectedId })