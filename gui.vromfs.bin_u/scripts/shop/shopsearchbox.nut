from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let shopSearchWnd  = require("%scripts/shop/shopSearchWnd.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")

::gui_handlers.ShopSearchBox <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/shop/shopSearchBox.blk"

  curCountry = ""
  curEsUnitType = ES_UNIT_TYPE_INVALID
  cbOwnerSearchHighlight = null
  cbOwnerSearchCancel = null
  cbOwnerShowUnit = null
  cbOwnerClose = null
  getEdiffFunc = null

  searchString  = ""
  prevSearchString = ""
  prevSearchResult = []
  prevIsClear = true

  isActive = false
  isClear = true

  function initScreen()
  {
    this.scene.setUserData(this)
    this.scene.findObject("search_update_timer").setUserData(this)

    foreach (id in [ "search_btn_start", "search_btn_close" ])
    {
      let obj = this.scene.findObject(id)
      if (checkObj(obj))
        obj["tooltip"] += colorize("hotkeyColor",
        loc("ui/parentheses/space", { text = loc(obj?["hotkeyLoc"] ?? "") }))
    }

    searchClear()
  }

  function searchClear()
  {
    searchString = ""
    prevSearchString = ""
    prevSearchResult = []
    prevIsClear = true
    isClear = true

    let obj = this.scene.findObject("search_edit_box")
    if (checkObj(obj)) {
      obj.setValue("")
      // Toggling enable status to make it lose focus.
      obj.enable(false)
      obj.enable(true)
    }
    updateHint(isClear, 0, 0)
  }

  function searchCancel()
  {
    searchClear()
    cbOwnerSearchCancel()
  }

  function updateHint(isEditboxClear, countGlobal, countLocal)
  {
    local hintText = isEditboxClear ? loc("shop/search/hint")
      : !countGlobal ? loc("shop/search/global/notFound")
      : countLocal ? loc("shop/search/local/found", { count = countLocal })
      : loc("shop/search/local/notFound")
    //With IME window with all variants wil be open automatically
    if (countGlobal > countLocal)
      hintText += "\n" + loc("shop/search/global/found", { count = countGlobal })
    let obj = this.scene.findObject("search_hint_text")
    if (checkObj(obj))
      obj.setValue(hintText)
  }

  function onSearchEditBoxChangeValue(obj)
  {
    searchString = obj.getValue()
  }

  function doFastSearch(searchStr)
  {
    isClear = searchStr == ""
    prevSearchString = searchStr
    local units = shopSearchCore.findUnitsByLocName(searchStr)
    if (prevIsClear == isClear && ::u.isEqual(prevSearchResult, units))
      return

    prevIsClear = isClear
    prevSearchResult = units
    let countGlobal = units.len()
    let countryId = curCountry
    let unitType = curEsUnitType
    units = units.filter(@(unit) ::getUnitCountry(unit) == countryId && unitType == ::get_es_unit_type(unit))
    let countLocal = units.len()

    updateHint(isClear, countGlobal, countLocal)
    cbOwnerSearchHighlight(units, isClear)
  }

  function onSearchCancelClick(_obj)
  {
    searchCancel()
  }

  function onSearchEditBoxCancelEdit(_obj)
  {
    if (isActive)
      searchCancel()
    else
      cbOwnerClose()
  }

  function onSearchEditBoxActivate(obj = null)
  {
    obj = obj || this.scene.findObject("search_edit_box")
    if (!checkObj(obj))
      return
    let searchStr = ::g_string.trim(obj.getValue())
    if (searchStr != "")
      if (shopSearchWnd.open(searchStr, cbOwnerShowUnit, getEdiffFunc))
        searchClear()
  }

  function onSearchButtonClick(_obj)
  {
    onSearchEditBoxActivate()
  }

  function onActiveStateChanged(v_isActive)
  {
    if (!this.isValid())
      return
    if (isActive == v_isActive)
      return
    isActive = v_isActive

    local obj = this.scene.findObject("search_buttons")
    if (checkObj(obj))
      obj.show(isActive && !::show_console_buttons)

    obj = this.scene.findObject("search_box_result")
    if (checkObj(obj))
      obj.show(isActive)

    if (!isActive)
      searchCancel()
  }

  function onSearchEditBoxFocusChanged(obj)
  {
    this.guiScene.performDelayed(this, @() checkObj(obj) && onActiveStateChanged(obj.isFocused()))
  }

  function onSearchEditBoxMouseChanged(obj) {
    if (!::show_console_buttons || !checkObj(obj))
      return

    onActiveStateChanged(obj.isMouseOver())
  }

  function onAccesskeyActivateSearch(_obj)
  {
    ::select_editbox(this.scene.findObject("search_edit_box"))
  }

  function onEventShopUnitTypeSwitched(p)
  {
    if (curEsUnitType == p.esUnitType)
      return
    curEsUnitType = p.esUnitType
    searchCancel()
  }

  function onEventCountryChanged(_p)
  {
    curCountry = profileCountrySq.value
    searchCancel()
  }

  function onEventShopWndSwitched(_p)
  {
    searchCancel()
  }

  function onTimer(_obj, _dt)
  {
    if (isActive && searchString != prevSearchString)
      doFastSearch(searchString)
  }
}

return {
  init = @(params) ::handlersManager.loadHandler(::gui_handlers.ShopSearchBox, params)
}
