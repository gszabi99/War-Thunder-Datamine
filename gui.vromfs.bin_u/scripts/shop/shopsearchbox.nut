local shopSearchCore = require("scripts/shop/shopSearchCore.nut")
local shopSearchWnd  = require("scripts/shop/shopSearchWnd.nut")

class ::gui_handlers.ShopSearchBox extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = "gui/shop/shopSearchBox.blk"

  curCountry = ""
  curEsUnitType = ::ES_UNIT_TYPE_INVALID
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
    scene.setUserData(this)
    scene.findObject("search_update_timer").setUserData(this)

    foreach (id in [ "search_btn_start", "search_btn_close" ])
    {
      local obj = scene.findObject(id)
      if (::check_obj(obj))
        obj["tooltip"] += ::colorize("hotkeyColor",
        ::loc("ui/parentheses/space", { text = ::loc(obj?["hotkeyLoc"] ?? "") }))
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

    local obj = scene.findObject("search_edit_box")
    if (::check_obj(obj))
      obj.setValue("")
    updateHint(isClear, 0, 0)
  }

  function searchCancel()
  {
    searchClear()
    cbOwnerSearchCancel()
  }

  function updateHint(isEditboxClear, countGlobal, countLocal)
  {
    local hintText = isEditboxClear ? ::loc("shop/search/hint")
      : !countGlobal ? ::loc("shop/search/global/notFound")
      : countLocal ? ::loc("shop/search/local/found", { count = countLocal })
      : ::loc("shop/search/local/notFound")
    //With IME window with all variants wil be open automatically
    if (countGlobal > countLocal)
      hintText += "\n" + ::loc("shop/search/global/found", { count = countGlobal })
    local obj = scene.findObject("search_hint_text")
    if (::check_obj(obj))
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
    local countGlobal = units.len()
    local countryId = curCountry
    local unitType = curEsUnitType
    units = units.filter(@(unit) ::getUnitCountry(unit) == countryId && unitType == ::get_es_unit_type(unit))
    local countLocal = units.len()

    updateHint(isClear, countGlobal, countLocal)
    cbOwnerSearchHighlight(units, isClear)
  }

  function onSearchCancelClick(obj)
  {
    searchCancel()
  }

  function onSearchEditBoxCancelEdit(obj)
  {
    if (obj.getValue() != "")
      searchCancel()
    else
      cbOwnerClose()
  }

  function onSearchEditBoxActivate(obj = null)
  {
    obj = obj || scene.findObject("search_edit_box")
    if (!::check_obj(obj))
      return
    local searchStr = ::g_string.trim(obj.getValue())
    if (searchStr != "")
      if (shopSearchWnd.open(searchStr, cbOwnerShowUnit, getEdiffFunc))
        searchClear()
  }

  function onSearchButtonClick(obj)
  {
    onSearchEditBoxActivate()
  }

  function onActiveStateChanged(_isActive)
  {
    if (!isValid())
      return
    if (isActive == _isActive)
      return
    isActive = _isActive

    local obj = scene.findObject("search_buttons")
    if (::check_obj(obj))
      obj.show(isActive && !::show_console_buttons)

    obj = scene.findObject("search_box_result")
    if (::check_obj(obj))
      obj.show(isActive)

    if (!isActive)
      searchCancel()
  }

  function onSearchEditBoxFocusChanged(obj)
  {
    guiScene.performDelayed(this, @() ::check_obj(obj) && onActiveStateChanged(obj.isFocused()))
  }

  function onSearchEditBoxMouseChanged(obj) {
    if (!::show_console_buttons || !::check_obj(obj))
      return

    onActiveStateChanged(obj.isMouseOver())
  }

  function onAccesskeyActivateSearch(obj)
  {
    ::select_editbox(scene.findObject("search_edit_box"))
  }

  function onEventShopUnitTypeSwitched(p)
  {
    curEsUnitType = p.esUnitType
    searchCancel()
  }

  function onEventCountryChanged(p)
  {
    curCountry = ::get_profile_country_sq()
    searchCancel()
  }

  function onTimer(obj, dt)
  {
    if (isActive && searchString != prevSearchString)
      doFastSearch(searchString)
  }
}

return {
  init = @(params) ::handlersManager.loadHandler(::gui_handlers.ShopSearchBox, params)
}
