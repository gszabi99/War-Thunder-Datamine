let { getCurLoadingBgData,
        getLoadingBgName,
        getLoadingBgTooltip } = require("%scripts/loading/loadingBgData.nut")
let { animBgLoad } = require("%scripts/loading/animBg.nut")
let { isLoadingScreenBanned,
        toggleLoadingScreenBan } = require("%scripts/options/preloaderOptions.nut")

local class PreloaderOptionsModal extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/options/preloaderOptions.blk"

  isHovered = false
  hoveredId = null
  selectedId = null

  function initScreen()
  {
    let listboxFilterHolder = scene.findObject("listbox_filter_holder")
    guiScene.replaceContent(listboxFilterHolder, "%gui/chapter_include_filter.blk", this)

    fillLoadingScreenList()
    showSceneBtn("items_list_msg", false).setValue(::loc("shop/search/global/notFound"))

    updateListItems()
    updateButtons()
  }

  function fillLoadingScreenList()
  {
    let view = { items = [] }
    foreach (screenId, w in getCurLoadingBgData().list)
      view.items.append({
        imgTag = "banImg"
        id = screenId
        itemText = getLoadingBgName(screenId)
        tooltip = getLoadingBgTooltip(screenId)
        isNeedOnHover = ::show_console_buttons
      })

    view.items.sort(@(a, b) a.itemText <=> b.itemText)
    let selectedIdx = view.items.findindex((@(a) a.id == selectedId).bindenv(this)) ?? 0
    let data = ::handyman.renderCached("%gui/missions/missionBoxItemsList", view)
    let itemsListObj = scene.findObject("items_list")
    guiScene.replaceContentFromText(itemsListObj, data, data.len(), this)
    itemsListObj.setValue(selectedIdx)

    ::move_mouse_on_child_by_value(itemsListObj)
  }

  function updateListItems()
  {
    let hasPremium = ::havePremium()
    let itemsListObj = scene.findObject("items_list")
    let numItems = itemsListObj.childrenCount()
    for (local i = 0; i < numItems; i++) {
      let itemObj = itemsListObj.getChild(i)
      itemObj.banned = hasPremium && isLoadingScreenBanned(itemObj.id) ? "yes" : "no"
    }
  }

  function updateBg()
  {
    animBgLoad(selectedId, scene.findObject("animated_bg_picture"))
  }

  function updateSelectedListItem()
  {
    scene.findObject(selectedId).banned = isLoadingScreenBanned(selectedId) ? "yes" : "no"
  }

  function updateButtons()
  {
    let isMouseMode = !::show_console_buttons || ::is_mouse_last_time_used()
    let isBanBtnVisible = (isMouseMode && scene.findObject(selectedId).isVisible())
      || hoveredId == selectedId

    showSceneBtn("btn_select", !isMouseMode && hoveredId != selectedId && isHovered)
    showSceneBtn("btn_ban", isBanBtnVisible)
      .setValue(isBanBtnVisible && ::havePremium() && isLoadingScreenBanned(selectedId)
        ? ::loc("maps/preferences/removeBan")
        : ::loc("maps/preferences/ban"))
  }

  canBan = @() getCurLoadingBgData().list.filter(@(v, id) !isLoadingScreenBanned(id)).len() > 1

  function toggleBan()
  {
    if (!isValid())
      return

    if (!::havePremium())
      return msgBox("need_money", ::loc("mainmenu/onlyWithPremium"), [
        ["purchase", (@() onOnlineShopPremium()).bindenv(this)],
        ["cancel"]], "purchase")

    if (!isLoadingScreenBanned(selectedId) && !canBan())
      return msgBox("max_banned_count", ::loc("preloaderSettings/maxBannedCount"), [
        ["ok"]], "ok")

    toggleLoadingScreenBan(selectedId)

    updateButtons()
    updateSelectedListItem()
  }

  function onItemDblClick()
  {
    if (!::show_console_buttons)
      toggleBan()
  }

  function onItemHover(obj)
  {
    if (!::show_console_buttons)
      return

    if (!obj.isHovered() && obj.id != hoveredId)
      return

    isHovered = obj.isHovered()
    hoveredId = isHovered ? obj.id : null

    updateButtons()
  }

  function onItemSelect(obj)
  {
    let itemsListObj = scene.findObject("items_list")
    selectedId = itemsListObj.getChild(itemsListObj.getValue()).id

    updateBg()
    updateButtons()
  }

  function onFilterEditBoxCancel()
  {
    let editBoxObj = scene.findObject("filter_edit_box")
    if (editBoxObj.getValue() != "")
      editBoxObj.setValue("")
    else
      guiScene.performDelayed(this, @() isValid() && goBack())
  }

  function onFilterEditBoxChangeValue(obj)
  {
    let value = obj.getValue()
    let searchStr = ::g_string.utf8ToLower(::g_string.trim(value))
    local isFound = false
    let itemsListObj = scene.findObject("items_list")
    let numItems = itemsListObj.childrenCount()

    guiScene.setUpdatesEnabled(false, false)
    for (local i = 0; i < numItems; i++) {
      let itemObj = itemsListObj.getChild(i)
      let titleStr = itemObj.findObject($"txt_{itemObj.id}").getValue()
      let isVisible = searchStr == "" || ::g_string.utf8ToLower(titleStr).contains(searchStr)
      itemObj.show(isVisible)
      itemObj.enable(isVisible)
      isFound = isFound || isVisible
    }

    showSceneBtn("filter_edit_cancel_btn", value.len() != 0)
    showSceneBtn("items_list_msg", !isFound)
    guiScene.setUpdatesEnabled(true, true)

    updateButtons()
  }

  function onEventProfileUpdated(p)
  {
    updateListItems()
    updateButtons()
  }

  onFilterEditBoxActivate = @() null
  onChapterSelect = @() null
}

::gui_handlers.PreloaderOptionsModal <- PreloaderOptionsModal

return @(selectedId = null) ::handlersManager.loadHandler(PreloaderOptionsModal, {selectedId})