local bhvUnseen = ::require("scripts/seen/bhvUnseen.nut")
local { getButtonConfigById } = require("scripts/mainmenu/topMenuButtons.nut")
local { stickedDropDown } = require("scripts/baseGuiHandlerWT.nut")

class ::gui_handlers.TopMenuButtonsHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.CUSTOM
  sceneBlkName = null
  sceneTplName = "gui/mainmenu/topmenu_menuPanel"

  parentHandlerWeak = null
  sectionsStructure = null
  objForWidth = null

  GCDropdownsList = null
  focusArray = null
  isPrimaryFocus = false

  maxSectionsCount = 0
  sectionsOrder = null

  ON_ESC_SECTION_OPEN = "menu"

  static function create(nestObj, parentHandler, sectionsStructure, objForWidth = null)
  {
    if (!::g_login.isLoggedIn())
      return null

    if (!::check_obj(nestObj))
      return null

    local handler = ::handlersManager.loadHandler(::gui_handlers.TopMenuButtonsHandler, {
                                           scene = nestObj
                                           parentHandlerWeak = parentHandler,
                                           sectionsStructure = sectionsStructure,
                                           objForWidth = objForWidth
                                        })
    return handler? handler.weakref() : null
  }

  function getSceneTplView()
  {
    GCDropdownsList = []
    focusArray = ["top_menu_panel_place"]
    return {
      section = getSectionsView()
    }
  }

  function initScreen()
  {
    if (parentHandlerWeak)
      parentHandlerWeak = parentHandlerWeak.weakref()

    scene.show(true)
    updateButtonsStatus()
    initFocusArray()
  }

  function getFocusObj()
  {
    if (curGCDropdown)
      return findObjInFocusArray(false)

    return scene.findObject("top_menu_panel_place")
  }

  function getMaxSectionsCount()
  {
    if (!::has_feature("SeparateTopMenuButtons"))
      return 1

    if (!::check_obj(objForWidth))
      objForWidth = scene
    if (!::check_obj(objForWidth))
      return 1

    local freeWidth = objForWidth.getSize()[0]
    local singleButtonMinWidth = guiScene.calcString("1@topMenuButtonWidth", null) || 1
    return ::max(freeWidth / singleButtonMinWidth, 1)
  }

  function initSectionsOrder()
  {
    if (sectionsOrder)
      return

    maxSectionsCount = getMaxSectionsCount()
    sectionsOrder = ::g_top_menu_sections.getSectionsOrder(sectionsStructure, maxSectionsCount)
  }

  function getSectionsView()
  {
    if (!::check_obj(scene))
      return {}

    initSectionsOrder()

    local sectionsView = []
    foreach (topMenuButtonIndex, sectionData in sectionsOrder)
    {
      local columnsCount = sectionData.buttons.len()
      local columns = []

      foreach (idx, column in sectionData.buttons)
      {
        columns.append({
          buttons = column
          addNewLine = idx != (columnsCount - 1)
          columnIndex = (idx+1)
        })
      }

      local tmId = sectionData.getTopMenuButtonDivId()
      ::u.appendOnce(tmId, GCDropdownsList)

      sectionsView.append({
        tmId = tmId
        haveTmDiscount = sectionData.haveTmDiscount
        tmDiscountId = sectionData.getTopMenuDiscountId()
        visualStyle = sectionData.visualStyle
        tmText = sectionData.getText(maxSectionsCount)
        tmImage = sectionData.getImage(maxSectionsCount)
        tmWinkImage = sectionData.getWinkImage()
        tmHoverMenuPos = sectionData.hoverMenuPos
        tmOnClick = sectionData.onClick
        forceHoverWidth = sectionData.forceHoverWidth
        isWide = sectionData.isWide
        columnsCount = columnsCount
        columns = columns
        btnName = sectionData.btnName
        isLast = topMenuButtonIndex == sectionsOrder.len() - 1
        unseenIconMainButton = getSectionUnseenIcon(columns)
      })
    }
    return sectionsView
  }

  function getSectionUnseenIcon(columns)
  {
    local unseenList = []
    foreach (column in columns)
      foreach (button in column.buttons)
      if (!button.isHidden() && !button.isVisualDisabled())
      {
        local unseenIcon = button.unseenIcon?()
        if (unseenIcon)
          unseenList.append(unseenIcon)
      }

    return unseenList.len() ? bhvUnseen.makeConfigStrByList(unseenList) : null
  }

  function onHoverSizeMove(obj)
  {
    if(obj?["class"] != "dropDown")
      obj = obj.getParent()

    local hover = obj.findObject(obj.id+"_list_hover")
    if (::check_obj(hover)) {
      local menu = obj.findObject(obj.id+"_focus")
      if (menu.getSize()[1] < 0)
        menu.getScene().applyPendingChanges(true)
      hover["height-end"] = menu.getSize()[1] + guiScene.calcString("@dropDownMenuBottomActivityGap", null)
    }

    base.onHoverSizeMove(obj);
  }

  function updateButtonsStatus()
  {
    local needHideVisDisabled = ::has_feature("HideDisabledTopMenuActions")
    local isInQueue = ::checkIsInQueue()

    foreach (idx, section in sectionsOrder)
    {
      local sectionId = section.getTopMenuButtonDivId()
      local sectionObj = scene.findObject(sectionId)
      if (!::check_obj(sectionObj))
        continue

      local isVisibleAnyButton = false
      foreach (column in section.buttons)
      {
        foreach (button in column)
        {
          local btnObj = sectionObj.findObject(button.id)
          if (!::checkObj(btnObj))
            continue

          local isVisualDisable = button.isVisualDisabled()
          local show = !button.isHidden(parentHandlerWeak)
          if (show && isVisualDisable)
            show = !needHideVisDisabled

          btnObj.show(show)
          btnObj.enable(show)
          isVisibleAnyButton = isVisibleAnyButton || show

          if (!show)
            continue

          isVisualDisable = isVisualDisable || (button.isInactiveInQueue && isInQueue)
          btnObj.inactiveColor = isVisualDisable? "yes" : "no"
        }
      }

      sectionObj.show(isVisibleAnyButton)
      sectionObj.enable(isVisibleAnyButton)
    }
  }

  function hideHoverMenu(name)
  {
    local obj = getObj(name)
    if (!::check_obj(obj))
      return

    obj["_size-timer"] = "0"
    obj.setFloatProp(::dagui_propid.add_name_id("_size-timer"), 0.0)
    obj.height = "0"
  }

  function onClick(obj)
  {
    if (!::handlersManager.isHandlerValid(parentHandlerWeak))
      return

    local btn = getButtonConfigById(obj.id)
    if (btn.isDelayed)
      guiScene.performDelayed(this, function()
      {
        if (isValid())
          btn.onClickFunc(null, parentHandlerWeak)
      })
    else
      btn.onClickFunc(obj, parentHandlerWeak)
  }

  function onChangeCheckboxValue(obj)
  {
    local btn = getButtonConfigById(obj.id)
    btn.onChangeValueFunc(obj.getValue())
  }

  function switchMenuFocus()
  {
    local section = sectionsStructure.getSectionByName(ON_ESC_SECTION_OPEN)
    if (::u.isEmpty(section))
      return

    if (::show_console_buttons && section.mergeIndex >= -1)
    {
      scene.findObject("top_menu_panel_place").setValue(section.mergeIndex)
      return
    }

    local buttonObj = scene.findObject(section.getTopMenuButtonDivId())
    if (::checkObj(buttonObj))
      this[section.onClick](buttonObj)
  }

  function topmenuMenuActivate(obj)
  {
    local curVal = obj.getValue()
    if (curVal < 0)
      return

    local selObj = obj.getChild(curVal)
    if (!::checkObj(selObj))
      return
    local eventName = selObj?._on_click ?? selObj?.on_click ?? selObj?.on_change_value
    if (!eventName || !(eventName in this))
      return

    if (selObj?.on_change_value)
      selObj.setValue(!selObj.getValue())

    unstickGCDropdownMenu()
    this[eventName](selObj)
  }

  function stickLeftDropDown(obj)  { moveDropDownFocus(obj, -1) }
  function stickRightDropDown(obj) { moveDropDownFocus(obj, 1)  }

  function moveDropDownFocus(obj, direction)
  {
    local mergeIdx = -1
    foreach (idx, section in sectionsOrder)
      if (obj.sectionId == section.getTopMenuButtonDivId())
        mergeIdx = idx

    local panelObj = scene.findObject("top_menu_panel_place")

    mergeIdx += direction

    if (mergeIdx < 0)
    {
      onWrapLeft(panelObj)
      return
    }
    else if (mergeIdx >= sectionsOrder.len())
    {
      onWrapRight(panelObj)
      return
    }

    onGCDropdown(panelObj.getChild(mergeIdx))
    panelObj.setValue(mergeIdx)
  }

  function onWrapDown(obj)
  {
    if (::show_console_buttons)
      onGCDropdown(obj.getChild(obj.getValue()))
    else
      base.onWrapDown(obj)
  }

  function onWrapLeft(obj)
  {
    local prevDropDown = stickedDropDown
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelLeft(obj)

    if (::check_obj(prevDropDown))
      prevDropDown.stickHover = "no"
  }

  function onWrapRight(obj)
  {
    local prevDropDown = stickedDropDown
    if (::handlersManager.isHandlerValid(parentHandlerWeak))
      parentHandlerWeak.onTopGCPanelRight(obj)

    if (::check_obj(prevDropDown))
      prevDropDown.stickHover = "no"
  }

  function onEventGameModesAvailability(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventQueueChangeState(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventUpdateGamercard(p)
  {
    doWhenActiveOnce("updateButtonsStatus")
  }

  function onEventActiveHandlersChanged(p)
  {
    if (!isSceneActiveNoModals())
      unstickLastDropDown()
  }
}
