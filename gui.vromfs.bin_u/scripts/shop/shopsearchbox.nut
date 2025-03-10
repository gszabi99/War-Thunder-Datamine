from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")

let shopSearchCore = require("%scripts/shop/shopSearchCore.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { select_editbox, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let shopSearchWnd  = require("%scripts/shop/shopSearchWnd.nut")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { trim } = require("%sqstd/string.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { getUnitCountry } = require("%scripts/unit/unitInfo.nut")
let { getEsUnitType } = require("%scripts/unit/unitParams.nut")

gui_handlers.ShopSearchBox <- class (gui_handlers.BaseGuiHandlerWT) {
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

  function initScreen() {
    this.scene.setUserData(this)
    this.scene.findObject("search_update_timer").setUserData(this)

    foreach (id in [ "search_btn_start", "search_btn_close" ]) {
      let obj = this.scene.findObject(id)
      if (checkObj(obj))
        obj["tooltip"] = "".concat(obj["tooltip"], colorize("hotkeyColor",
        loc("ui/parentheses/space", { text = loc(obj?["hotkeyLoc"] ?? "") })))
    }

    this.searchClear()
  }

  function searchClear() {
    this.searchString = ""
    this.prevSearchString = ""
    this.prevSearchResult = []
    this.prevIsClear = true
    this.isClear = true

    let obj = this.scene.findObject("search_edit_box")
    if (checkObj(obj)) {
      obj.setValue("")
      
      obj.enable(false)
      obj.enable(true)
    }
    this.updateHint(this.isClear, 0, 0)
  }

  function searchCancel() {
    this.searchClear()
    this.cbOwnerSearchCancel()
  }

  function updateHint(isEditboxClear, countGlobal, countLocal) {
    local hintText = isEditboxClear ? loc("shop/search/hint")
      : !countGlobal ? loc("shop/search/global/notFound")
      : countLocal ? loc("shop/search/local/found", { count = countLocal })
      : loc("shop/search/local/notFound")
    
    if (countGlobal > countLocal)
      hintText = "\n".concat(hintText, loc("shop/search/global/found", { count = countGlobal }))
    let obj = this.scene.findObject("search_hint_text")
    if (checkObj(obj))
      obj.setValue(hintText)
  }

  function onSearchEditBoxChangeValue(obj) {
    this.searchString = obj.getValue()
  }

  function doFastSearch(searchStr) {
    this.isClear = searchStr == ""
    this.prevSearchString = searchStr
    local units = shopSearchCore.findUnitsByLocName(searchStr)
    if (this.prevIsClear == this.isClear && u.isEqual(this.prevSearchResult, units))
      return

    this.prevIsClear = this.isClear
    this.prevSearchResult = units
    let countGlobal = units.len()
    let countryId = this.curCountry
    let unitType = this.curEsUnitType
    units = units.filter(@(unit) getUnitCountry(unit) == countryId && unitType == getEsUnitType(unit))
    let countLocal = units.len()

    this.updateHint(this.isClear, countGlobal, countLocal)
    this.cbOwnerSearchHighlight(units, this.isClear)
  }

  function onSearchCancelClick(_obj) {
    this.searchCancel()
  }

  function onSearchEditBoxCancelEdit(_obj) {
    if (this.isActive)
      this.searchCancel()
    else
      this.cbOwnerClose()
  }

  function onSearchEditBoxActivate(obj = null) {
    obj = obj || this.scene.findObject("search_edit_box")
    if (!checkObj(obj))
      return
    let searchStr = trim(obj.getValue())
    if (searchStr != "")
      if (shopSearchWnd.open(searchStr, this.cbOwnerShowUnit, this.getEdiffFunc))
        this.searchClear()
  }

  function onSearchButtonClick(_obj) {
    this.onSearchEditBoxActivate()
  }

  function onActiveStateChanged(v_isActive) {
    if (!this.isValid())
      return
    if (this.isActive == v_isActive)
      return
    this.isActive = v_isActive

    local obj = this.scene.findObject("search_buttons")
    if (checkObj(obj))
      obj.show(this.isActive && !showConsoleButtons.value)

    obj = this.scene.findObject("search_box_result")
    if (checkObj(obj))
      obj.show(this.isActive)

    if (!this.isActive)
      this.searchCancel()
  }

  function onSearchEditBoxFocusChanged(obj) {
    this.guiScene.performDelayed(this, @() checkObj(obj) && this.onActiveStateChanged(obj.isFocused()))
  }

  function onSearchEditBoxMouseChanged(obj) {
    if (!showConsoleButtons.value || !checkObj(obj))
      return

    this.onActiveStateChanged(obj.isMouseOver())
  }

  function onAccesskeyActivateSearch(_obj) {
    select_editbox(this.scene.findObject("search_edit_box"))
  }

  function onEventShopUnitTypeSwitched(p) {
    if (this.curEsUnitType == p.esUnitType)
      return
    this.curEsUnitType = p.esUnitType
    this.searchCancel()
  }

  function onEventCountryChanged(_p) {
    this.curCountry = profileCountrySq.value
    this.searchCancel()
  }

  function onEventShopWndSwitched(_p) {
    this.searchCancel()
  }

  function onTimer(_obj, _dt) {
    if (this.isActive && this.searchString != this.prevSearchString)
      this.doFastSearch(this.searchString)
  }
}

return {
  init = @(params) handlersManager.loadHandler(gui_handlers.ShopSearchBox, params)
}
