//-file:plus-string
from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui, ps4_is_circle_selected_as_enter_button
from "%scripts/dagui_library.nut" import *

let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { getGamepadAxisTexture, getButtonNameByIdx } = require("%scripts/controls/gamepadIcons.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getHudUnitType } = require("hudState")
let { useTouchscreen } = require("%scripts/clientState/touchScreen.nut")
let { getComplexAxesId, isComponentsAssignedToSingleInputItem
} = require("%scripts/controls/shortcutsUtils.nut")
let { PI } = require("math")
let { unitTypeByHudUnitType } = require("%scripts/hud/hudUnitType.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { hasXInputDevice } = require("controls")
let { getHudKillStreakShortcutId } = require("%scripts/hud/hudActionBarType.nut")
let { getWheelMenuAxisWatch, getAxisStuck, getMaxDeviatedAxisInfo,
  getAxisData } = require("%scripts/joystickInterface.nut")

const ITEMS_PER_PAGE = 8

function guiStartWheelmenu(params, isUpdate = false) {
  let defaultParams = {
    menu = []
    callbackFunc = null
    owner = null
    mouseEnabled    = false
    axisEnabled     = true
    contentTemplate = null
  }

  ::inherit_table(params, defaultParams)
  local handler = handlersManager.findHandlerClassInScene(gui_handlers.wheelMenuHandler)
  if (handler && isUpdate)
    handler.updateContent(params)
  else if (handler)
    handler.reinitScreen(params)
  else
    handler = handlersManager.loadHandler(gui_handlers.wheelMenuHandler, params)

  return handler
}

function closeCurWheelmenu() {
  local handler = handlersManager.findHandlerClassInScene(gui_handlers.wheelMenuHandler)
  if (handler && handler.isActive)
    handler.showScene(false)
  handler = handlersManager.findHandlerClassInScene(gui_handlers.chooseVehicleMenuHandler)
  if (handler && handler.isActive)
    handler.showScene(false)
}

// TEST: guiStartWheelmenu({ menu=[0,1,2,3,4,5,6,7].map(@(v) {name=$"{v}"}), callbackFunc=@(i) dlog(i) ?? closeCurWheelmenu() })

//-----------------------------------------------------------------------------

/* *
 * WheelMenu usage
 *
 * just call guiStartWheelmenu function
 *
 * guiStartWheelmenu parameters:
 * @owner - instance of handler, which creates the wheel menu
 * @params - table with some configs for instantiate wheel menu.
 *  Has optional and required parameters:
 *  @menu
 *   required parameter. Array of menu items,
 *   each element of array is a view for your template.
 *  @contentTemplate
 *   optional parameter. path to view template of @menu item.
 * */


dagui_propid_add_name_id("index") // for navigation with mouse in wheelmenu

gui_handlers.wheelMenuHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = "%gui/wheelMenu/wheelmenu.blk"
  wndControlsAllowMask = CtrlsInGui.CTRL_ALLOW_NONE
  wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
                                   | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS

  invalidIndex = -1
  applyIndex = -1
  joystickSides = ["E", "NE", "N", "NW", "W", "SW", "S", "SE"]
  joystickMinDeviation = 0.25
  btnSetIdx = -1
  btnSetsConfig = [
    ["W", "E"],
    ["W", "SW", "E", "SE", "S"],
    ["NW", "W", "SW", "NE", "E", "SE", "S", "N"],
  ]
  watchAxis = []
  stuckAxis = []

  menu = null
  isActive = true
  joystickSelection = null
  isKbdShortcutDown = false
  callbackFunc = null
  owner = null
  mouseEnabled = false
  axisEnabled = true
  shouldShadeBackground = true
  contentTemplate = null
  pageIdx = 0
  pagesTotal = 1
  itemsTotal = 0

  function initScreen() {
    if (!this.menu || !checkObj(this.scene))
      return this.close()

    if (!ps4_is_circle_selected_as_enter_button())
      this.wndControlsAllowMaskWhenActive = this.wndControlsAllowMaskWhenActive | CtrlsInGui.CTRL_ALLOW_TACTICAL_MAP
    closeCurWheelmenu()

    this.guiScene = this.scene.getScene()
    this.showScene(true)
    this.fill(true)
    if (this.axisEnabled) {
      this.watchAxis = getWheelMenuAxisWatch(unitTypeByHudUnitType?[getHudUnitType()])
      this.stuckAxis = getAxisStuck(this.watchAxis)
      this.joystickSelection = null
      this.isKbdShortcutDown = false

      this.scene.findObject("wheelmenu_axis_input_timer").setUserData(this)
      this.onWheelmenuAxisInputTimer()
    }
    this.updateSelectShortcutImage()
    let wheelmenu = this.scene.findObject("wheelmenu")
    wheelmenu["total-input-transparent"] = this.mouseEnabled ? "no" : "yes"
    showObjById("fast_shortcuts_block", false, this.scene)
    showObjById("wheelmenu_bg_shade", this.shouldShadeBackground, this.scene)

    g_hud_event_manager.subscribe("LocalPlayerDead", @(_) this.quit(), this)

    this.wndControlsAllowMask = this.wndControlsAllowMaskWhenActive
  }

  function destroyItems(){
    if (this.menu) {
      foreach (item in this.menu)
        if (item?.onDestroy)
          item.onDestroy(item, this)
    }
  }


  function reinitScreen(params = {}) {
    this.destroyItems()
    this.setParams(params)
    this.initScreen()
  }

  function updateContent(params = {}) {
    this.destroyItems()
    this.setParams(params)
    if ((this.menu?.len() ?? 0) == 0 || !checkObj(this.scene))
      return this.close()

    this.fill()
  }

  function fill(isInitial = false) {
    this.itemsTotal = 0
    foreach (idx, v in this.menu)
      if (v != null)
        this.itemsTotal = idx + 1
    this.pagesTotal = max(1, (this.itemsTotal + ITEMS_PER_PAGE - 1) / ITEMS_PER_PAGE)
    this.pageIdx = isInitial ? 0 : min(this.pageIdx, this.pagesTotal - 1)

    this.fillMenuItems()
    this.updatePageInfo()
    this.updateTitlePos()

    if (!isInitial)
      this.highlightItemBySide(this.joystickSelection, true)
  }

  function fillMenuItems() {
    let startIdx = this.pageIdx * ITEMS_PER_PAGE

    let itemsCount = max(this.itemsTotal - startIdx, ITEMS_PER_PAGE)
    this.btnSetIdx = this.btnSetsConfig.len() - 1
    for (local i = 0; i < this.btnSetsConfig.len(); i++)
      if (this.btnSetsConfig[i].len() >= itemsCount) {
          this.btnSetIdx = i
          break
        }
    let btnSet = this.btnSetsConfig[this.btnSetIdx]

    foreach (suffix in this.joystickSides) {
      let btnIdx = btnSet.indexof(suffix)
      let index = btnIdx != null ? (startIdx + btnIdx) : this.invalidIndex
      let item = this.menu?[index]
      let isShow = (item?.name ?? "") != ""
      let enabled = isShow && (item?.wheelmenuEnabled ?? true)
      let bObj = showObjById($"wheelmenuItem{suffix}", isShow, this.scene)

      if (checkObj(bObj)) {
        let buttonType = item?.buttonType ?? ""
        if (item != null) {
          item.itemId <- $"wheelmenuItem{suffix}"
          if (item?.onCreate)
            item.onCreate(item, this);
        }
        if (buttonType != "")
          bObj.type = buttonType

        if (isShow)
          this.updateContentForItem(bObj.findObject("content"), item)

        bObj.index = index
        bObj.enable(enabled)
        bObj.selected = "no"
      }
    }
  }

  function updateContentForItem(contentObj, item) {
    if (this.contentTemplate != null) { //!!!FIX ME need remove replace content for killStreakWheelMenu
      let blk = handyman.renderCached(this.contentTemplate, item)
      this.guiScene.replaceContentFromText(contentObj, blk, blk.len(), this)
      return
    }

    let { shortcutText = "", name = "", additionalText = "", chatMode = "" } = item
    contentObj.findObject("shortcutText").setValue(shortcutText)
    showObjById("shortcutTextSeparator", shortcutText!= "", contentObj)
    let nameObj = contentObj.findObject("name")
    nameObj.chatMode = chatMode
    nameObj.setValue(name)
    contentObj.findObject("additionalText").setValue(additionalText)
  }

  function updatePageInfo() {
    let shouldShowPages = this.pagesTotal > 1
    let objPageInfo = this.scene.findObject("wheel_menu_page")
    objPageInfo.setValue(shouldShowPages
      ? loc("mainmenu/pageNumOfPages", { num = this.pageIdx + 1, total = this.pagesTotal })
      : "")

    local needLbBtn = true
    if (shouldShowPages && hasXInputDevice()) {
      let shortcutId = getHudKillStreakShortcutId()
      let shType = ::g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
      let scInput = shType.getFirstInput(shortcutId)
      needLbBtn = scInput?.elements.findvalue(@(btn) (getButtonNameByIdx(btn?.buttonId ?? -1) == "l_shoulder")) == null
    }
    showObjById("btnSwitchPage_LB", needLbBtn && shouldShowPages, this.scene)
    showObjById("btnSwitchPage_LT", !needLbBtn && shouldShowPages, this.scene)
  }

  function updateTitlePos() {
    let obj = this.scene.findObject("wheel_menu_title")
    let startIdx = this.pageIdx * ITEMS_PER_PAGE
    let hasTopItem = this.menu?[startIdx + 7] != null
    obj.top = hasTopItem ? obj?.topWithTopMenuItem : obj?.topWithoutTopMenuItem
  }

  function updateSelectShortcutImage() {
    let obj = this.scene.findObject("wheelmenu_select_shortcut")
    local isShow = showConsoleButtons.value && this.axisEnabled
    if (isShow) {
      let shortcuts = this.watchAxis?[0]
      let axesId = getComplexAxesId(shortcuts)
      isShow = isComponentsAssignedToSingleInputItem(axesId)
      if (isShow)
        obj["background-image"] = getGamepadAxisTexture(axesId)
    }
    obj.show(isShow)
  }

  function onWheelmenuItemClick(obj) {
    if (!obj || (!this.mouseEnabled && !useTouchscreen && !is_cursor_visible_in_gui()))
      return

    let index = obj.index.tointeger()
    this.sendAvailableAnswerDelayed(index)
  }

  function onWheelmenuAxisInputTimer(_obj = null, _dt = null) {
    if (!this.axisEnabled || this.isKbdShortcutDown)
      return

    let axisData = getAxisData(this.watchAxis, this.stuckAxis)
    let joystickData = getMaxDeviatedAxisInfo(axisData, this.joystickMinDeviation)
    if (joystickData == null || joystickData.normLength == 0)
      return

    let side = ((joystickData.angle / PI + 2.125) * 4).tointeger() % 8
    this.highlightItemBySide(this.joystickSides?[side])
  }

  function highlightItemBySide(selection, isForced = false) {
    if (selection == this.joystickSelection && !isForced)
      return

    local bObj = this.joystickSelection && this.scene.findObject("wheelmenuItem" + this.joystickSelection)
    if (bObj)
      bObj.selected = "no"

    bObj = selection && this.scene.findObject("wheelmenuItem" + selection)
    if (bObj)
      bObj.selected = "yes"

    this.joystickSelection = selection
  }

  function highlightItemByBtnIdx(btnIdx) {
    let selection = this.btnSetsConfig[this.btnSetIdx]?[btnIdx]
    this.highlightItemBySide(selection)
  }

  function activateSelectedItem() {
    if (! this.joystickSelection)
      return

    let bObj = this.scene.findObject("wheelmenuItem" + this.joystickSelection)
    let index = bObj && bObj.index.tointeger()
    this.sendAvailableAnswerDelayed(index)
  }

  function onWheelmenuAccesskeyApply(_obj) {
    this.activateSelectedItem()
  }

  function onWheelmenuAccesskeyCancel(_obj) {
    this.sendAnswerAndClose(this.invalidIndex)
  }

  function onWheelmenuSwitchPage(_obj) {
    this.pageIdx = (this.pageIdx + 1) % this.pagesTotal
    this.fill()
  }

  function onVoiceMessageSwitchChannel(_obj) {}

  function onShortcutSelectCallback(btnIdx, isDown) {
    let index = (this.pageIdx * ITEMS_PER_PAGE) + btnIdx
    if (!this.isItemAvailable(index))
      return false
    this.isKbdShortcutDown = isDown
    this.highlightItemByBtnIdx(isDown ? btnIdx : -1)
    if (!isDown)
      this.sendAvailableAnswerDelayed(index)
    return true // processed
  }

  function onActivateItemCallback() {
    this.activateSelectedItem()
  }

  function isItemAvailable(index) {
    return (this.menu?[index].name ?? "") != "" && (this.menu?[index].wheelmenuEnabled ?? true)
  }

  function sendAvailableAnswerDelayed(index) {
    if (this.isItemAvailable(index))
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.sendAnswerAndClose(index)
      })
  }

  function sendAnswerAndClose(index) {
    if (index != null)
      this.applyIndex = index
    this.close()
  }

  function showScene(show) {
    this.scene.show(show)
    this.scene.enable(show)
    this.isActive = show
    this.switchControlsAllowMask(this.isActive ? this.wndControlsAllowMaskWhenActive : CtrlsInGui.CTRL_ALLOW_FULL)
  }

  function close() {
    this.doApply()
  }

  function afterModalDestroy() {
    this.doApply()
  }

  function doApply() {
    if (!this.callbackFunc)
      return

    if (this.owner)
      this.callbackFunc.call(this.owner, this.applyIndex)
    else
      this.callbackFunc(this.applyIndex)
  }

  quit = @() this.sendAnswerAndClose(this.invalidIndex)
  onEventHudTypeSwitched = @(_) this.quit()
}

return {
  guiStartWheelmenu
  closeCurWheelmenu
}
