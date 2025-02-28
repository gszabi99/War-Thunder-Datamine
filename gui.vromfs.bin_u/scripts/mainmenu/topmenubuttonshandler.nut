from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let u = require("%sqStdLibs/helpers/u.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")

let bhvUnseen = require("%scripts/seen/bhvUnseen.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getButtonConfigById } = require("%scripts/mainmenu/topMenuButtons.nut")
let { getTopMenuSectionsOrder } = require("%scripts/mainmenu/topMenuSections.nut")
let { isLoggedIn } = require("%appGlobals/login/loginState.nut")
let { checkIsInQueue } = require("%scripts/queue/queueManager.nut")

gui_handlers.TopMenuButtonsHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "%gui/mainmenu/topmenu_menuPanel.tpl"

  parentHandlerWeak = null
  sectionsStructure = null
  objForWidth = null

  GCDropdownsList = null

  maxSectionsCount = 0
  sectionsOrder = null

  ON_ESC_SECTION_OPEN = "menu"

  static function create(nestObj, parentHandler, sectionsStructure, objForWidth = null) {
    if (!isLoggedIn.get())
      return null

    if (!checkObj(nestObj))
      return null

    let handler = handlersManager.loadHandler(gui_handlers.TopMenuButtonsHandler, {
                                           scene = nestObj
                                           parentHandlerWeak = parentHandler,
                                           sectionsStructure = sectionsStructure,
                                           objForWidth = objForWidth
                                        })
    return handler ? handler.weakref() : null
  }

  function getSceneTplView() {
    this.GCDropdownsList = []
    return {
      section = this.getSectionsView()
    }
  }

  function initScreen() {
    if (this.parentHandlerWeak)
      this.parentHandlerWeak = this.parentHandlerWeak.weakref()

    this.scene.show(true)
    this.updateButtonsStatus()
  }

  function getMaxSectionsCount() {
    if (!hasFeature("SeparateTopMenuButtons"))
      return 1

    if (!checkObj(this.objForWidth))
      this.objForWidth = this.scene
    if (!checkObj(this.objForWidth))
      return 1

    let freeWidth = this.objForWidth.getSize()[0]
    let singleButtonMinWidth = this.guiScene.calcString("1@topMenuButtonWidth", null) || 1
    return max(freeWidth / singleButtonMinWidth, 1)
  }

  function initSectionsOrder() {
    if (this.sectionsOrder)
      return

    this.maxSectionsCount = this.getMaxSectionsCount()
    this.sectionsOrder = getTopMenuSectionsOrder(this.sectionsStructure, this.maxSectionsCount)
  }

  function getSectionsView() {
    if (!checkObj(this.scene))
      return {}

    this.initSectionsOrder()

    let sectionsView = []
    foreach (topMenuButtonIndex, sectionData in this.sectionsOrder) {
      let columnsCount = sectionData.buttons.len()
      let columns = []

      foreach (idx, column in sectionData.buttons) {
        columns.append({
          buttons = column
          addNewLine = idx != (columnsCount - 1)
          columnIndex = (idx + 1)
        })
      }

      let tmId = sectionData.getTopMenuButtonDivId()
      u.appendOnce(tmId, this.GCDropdownsList)

      sectionsView.append({
        tmId = tmId
        haveTmDiscount = sectionData.haveTmDiscount
        tmDiscountId = sectionData.getTopMenuDiscountId()
        visualStyle = sectionData.visualStyle
        tmText = sectionData.getText(this.maxSectionsCount)
        tmImage = sectionData.getImage(this.maxSectionsCount)
        tmWinkImage = sectionData.getWinkImage()
        tmHoverMenuPos = sectionData.hoverMenuPos
        tmOnClick = sectionData.onClick
        forceHoverWidth = sectionData.forceHoverWidth
        isWide = sectionData.isWide
        columnsCount = columnsCount
        columns = columns
        btnName = sectionData.btnName
        isLast = topMenuButtonIndex == this.sectionsOrder.len() - 1
        unseenIconMainButton = this.getSectionUnseenIcon(columns)
      })
    }
    return sectionsView
  }

  function getSectionUnseenIcon(columns) {
    let unseenList = []
    foreach (column in columns)
      foreach (button in column.buttons)
        if (!button.isHidden() && !button.isVisualDisabled()) {
          let unseenIcon = button.unseenIcon?()
          if (unseenIcon)
            unseenList.append(unseenIcon)
        }

    return unseenList.len() ? bhvUnseen.makeConfigStrByList(unseenList) : null
  }

  function onHoverSizeMove(obj) {
    if (obj?["class"] != "dropDown")
      obj = obj.getParent()

    let hover = obj.findObject($"{obj.id}_list_hover")
    if (checkObj(hover)) {
      let menu = obj.findObject($"{obj.id}_focus")
      menu.getScene().applyPendingChanges(true)
      hover["height-end"] = menu.getSize()[1] + this.guiScene.calcString("@dropDownMenuBottomActivityGap", null)
    }

    base.onHoverSizeMove(obj);
  }

  function updateButtonsStatus() {
    let needHideVisDisabled = hasFeature("HideDisabledTopMenuActions")
    let isInQueue = checkIsInQueue()
    let skipNavigation = this.parentHandlerWeak?.scene
      .findObject("gamercard_div")["gamercardSkipNavigation"] == "yes"

    foreach (_idx, section in this.sectionsOrder) {
      let sectionId = section.getTopMenuButtonDivId()
      let sectionObj = this.scene.findObject(sectionId)
      if (!checkObj(sectionObj))
        continue

      local isVisibleAnyButton = false
      foreach (column in section.buttons) {
        foreach (button in column) {
          let btnObj = sectionObj.findObject(button.id)
          if (!checkObj(btnObj))
            continue

          local isVisualDisable = button.isVisualDisabled()
          local show = !button.isHidden(this.parentHandlerWeak)
          if (show && isVisualDisable)
            show = !needHideVisDisabled

          btnObj.show(show)
          btnObj.enable(show)
          isVisibleAnyButton = isVisibleAnyButton || show

          if (!show)
            continue

          isVisualDisable = isVisualDisable || (button.isInactiveInQueue && isInQueue)
          btnObj.inactiveColor = isVisualDisable ? "yes" : "no"
          btnObj.tooltip = button.tooltip()
        }
      }

      if (skipNavigation) {
        sectionObj["skip-navigation"] = "yes"
        sectionObj.findObject($"{sectionObj.id}_btn")["skip-navigation"] = "yes"
      }

      sectionObj.show(isVisibleAnyButton)
      sectionObj.enable(isVisibleAnyButton)
    }
  }

  function hideHoverMenu(name) {
    let obj = this.getObj(name)
    if (!checkObj(obj))
      return

    obj["_size-timer"] = "0"
    obj.setFloatProp(dagui_propid_add_name_id("_size-timer"), 0.0)
    obj.height = "0"
  }

  function onClick(obj) {
    if (!handlersManager.isHandlerValid(this.parentHandlerWeak))
      return

    let btn = getButtonConfigById(obj.id)
    if (btn.isDelayed)
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          btn.onClickFunc(null, this.parentHandlerWeak)
      })
    else
      btn.onClickFunc(obj, this.parentHandlerWeak)
  }

  function onChangeCheckboxValue(obj) {
    let btn = getButtonConfigById(obj.id)
    btn.onChangeValueFunc(obj.getValue())
  }

  function switchMenuFocus() {
    let section = this.sectionsStructure.getSectionByName(this.ON_ESC_SECTION_OPEN)
    if (u.isEmpty(section))
      return

    if (showConsoleButtons.value && section.mergeIndex >= -1) {
      this.scene.findObject("top_menu_panel_place").setValue(section.mergeIndex)
      return
    }

    let buttonObj = this.scene.findObject(section.getTopMenuButtonDivId())
    if (checkObj(buttonObj))
      this[section.onClick](buttonObj)
  }

  function topmenuMenuActivate(obj) {
    let curVal = obj.getValue()
    if (curVal < 0)
      return

    let selObj = obj.getChild(curVal)
    if (!checkObj(selObj))
      return
    let eventName = selObj?._on_click ?? selObj?.on_click ?? selObj?.on_change_value
    if (!eventName || !(eventName in this))
      return

    if (selObj?.on_change_value)
      selObj.setValue(!selObj.getValue())

    this.unstickLastDropDown()
    this[eventName](selObj)
  }

  function stickLeftDropDown(obj)  { this.moveDropDownFocus(obj, -1) }
  function stickRightDropDown(obj) { this.moveDropDownFocus(obj, 1)  }

  function moveDropDownFocus(obj, direction) {
    this.forceCloseDropDown(obj)

    local mergeIdx = -1
    foreach (idx, section in this.sectionsOrder)
      if (obj.sectionId == section.getTopMenuButtonDivId())
        mergeIdx = idx

    mergeIdx += direction
    if (mergeIdx < 0 || mergeIdx >= this.sectionsOrder.len()) {
      set_dirpad_event_processed(false)
      return
    }

    let panelObj = this.scene.findObject("top_menu_panel_place")
    this.onGCDropdown(panelObj.getChild(mergeIdx))
    panelObj.setValue(mergeIdx)
  }

  function onEventQueueChangeState(_p) {
    this.doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventUpdateGamercard(_p) {
    this.doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventXboxMultiplayerPrivilegeUpdated(_p) {
    this.doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventCrossPlayOptionChanged(_p) {
    this.doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventActiveHandlersChanged(_p) {
    if (!this.isSceneActiveNoModals())
      this.unstickLastDropDown()
  }
}
