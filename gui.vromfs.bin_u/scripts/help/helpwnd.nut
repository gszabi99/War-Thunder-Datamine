local u = require("sqStdLibs/helpers/u.nut")
local gamepadIcons = require("scripts/controls/gamepadIcons.nut")
local helpTabs = require("scripts/controls/help/controlsHelpTabs.nut")
local helpMarkup = require("scripts/controls/help/controlsHelpMarkup.nut")
local shortcutsAxisListModule = require("scripts/controls/shortcutsList/shortcutsAxis.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

require("scripts/viewUtils/bhvHelpFrame.nut")

::gui_modal_help <- function gui_modal_help(isStartedFromMenu, contentSet)
{
  ::gui_start_modal_wnd(::gui_handlers.helpWndModalHandler, {
    isStartedFromMenu  = isStartedFromMenu
    contentSet = contentSet
  })
}

::gui_start_flight_menu_help <- function gui_start_flight_menu_help()
{
  if (!::has_feature("ControlsHelp"))
  {
    ::get_gui_scene().performDelayed(::getroottable(), function() {
      ::close_ingame_gui()
      if (::is_game_paused())
        ::pause_game(false)
    })
    return
  }
  local needFlightMenu = !::get_is_in_flight_menu() && !::is_flight_menu_disabled();
  if (needFlightMenu)
    ::get_cur_base_gui_handler().goForward(function(){::gui_start_flight_menu()})
  ::gui_modal_help(needFlightMenu, HELP_CONTENT_SET.MISSION)
}

class ::gui_handlers.helpWndModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/help/helpWnd.blk"

  defaultLinkLinesInterval = "@helpLineInterval"

  curTabIdx = -1
  curSubTabIdx = -1
  visibleTabs = []

  contentSet = HELP_CONTENT_SET.MISSION
  isStartedFromMenu = false

  preset = null

  pageUnitType = null
  pageUnitTag = null
  modifierSymbols = null

  kbdKeysRemapByLang = {
    German = { Y = "Z", Z = "Y"}
    French = { Q = "A", A = "Q", W = "Z", Z = "W" }
  }

  function initScreen()
  {
    preset = preset || ::g_controls_manager.getCurPreset()
    visibleTabs = helpTabs.getTabs(contentSet)
    fillTabs()

    local subTabsObj = scene.findObject("sub_tabs_list")
    ::move_mouse_on_child_by_value(subTabsObj?.isVisible()
      ? subTabsObj
      : scene.findObject("tabs_list"))

    ::g_hud_event_manager.onHudEvent("helpOpened")
  }

  function fillTabs()
  {
    local tabsObj = scene.findObject("tabs_list")
    local countVisibleTabs = visibleTabs.len()

    local preselectedTab = helpTabs.getPrefferableType(contentSet)

    curTabIdx = 0
    local view = { tabs = [] }
    foreach (idx, group in visibleTabs)
    {
      local isSelected = false
      foreach (sIdx, subTab in group.list)
        if (subTab == preselectedTab)
        {
          isSelected = true
          curSubTabIdx = sIdx
          curTabIdx = idx
        }

      view.tabs.append({
        tabName = group.title
        navImagesText = ::get_navigation_images_text(idx, countVisibleTabs)
        selected = isSelected
      })
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    fillSubTabs()
  }

  function fillSubTabs()
  {
    local subTabsList = visibleTabs[curTabIdx].list

    local isSubTabsVisible = subTabsList.len() > 1
    local subTabsObj = showSceneBtn("sub_tabs_list", isSubTabsVisible)
    if (!subTabsObj)
      return

    local view = { items = [] }
    if (isSubTabsVisible)
    {
      foreach (idx, tType in subTabsList)
      {
        view.items.append({
          text = tType.subTabName
          selected = idx == curSubTabIdx
        })
      }

      local data = ::handyman.renderCached("gui/commonParts/shopFilter", view)
      guiScene.replaceContentFromText(subTabsObj, data, data.len(), this)
    }

    fillSubTabContent()
  }

  function getCurrentSubTab()
  {
    local list = visibleTabs[curTabIdx].list
    return list?[curSubTabIdx] ?? list?[0]
  }

  function onHelpSheetChange(obj)
  {
    local selTabIdx = obj.getValue()
    if (curTabIdx == selTabIdx)
      return

    curTabIdx = selTabIdx
    fillSubTabs()
  }

  function onHelpSubSheetChange(obj)
  {
    local selTabIdx = obj.getValue()
    if (obj.childrenCount() > 1 && curSubTabIdx == selTabIdx)
      return

    curSubTabIdx = selTabIdx
    fillSubTabContent()
  }

  function fillSubTabContent()
  {
    local tab = getCurrentSubTab()
    if (!tab)
      return

    pageUnitType = unitTypes.getByBit(tab?.pageUnitTypeBit)
    pageUnitTag = tab?.pageUnitTag

    local sheetObj = scene.findObject("help_sheet")
    local pageBlkName = ::getTblValue("pageBlkName", tab, "")
    if (!::u.isEmpty(pageBlkName))
      guiScene.replaceContent(sheetObj, pageBlkName, this)

    local fillFuncName = ::getTblValue("pageFillfuncName", tab)
    local fillFunc = fillFuncName ? ::getTblValue(fillFuncName, this) : fillHelpPage
    fillFunc()

    showTabSpecificControls(tab)
    guiScene.performDelayed(this, function() {
      if (!isValid())
        return

      fillTabLinkLines(tab)
    })
  }

  function showTabSpecificControls(tab)
  {
    local countryRelatedObjs = ::getTblValue("countryRelatedObjs", tab, null)
    if (countryRelatedObjs != null)
    {
      local selectedCountry = ::get_profile_country_sq().slice(8)
      selectedCountry = (selectedCountry in countryRelatedObjs) ? selectedCountry : tab.defaultValues.country
      local selectedCountryConfig = countryRelatedObjs?[selectedCountry] ?? []
      foreach(key, countryConfig in countryRelatedObjs)
        foreach (idx, value in countryConfig)
        {
          local obj = scene.findObject(value)
          if (::checkObj(obj))
            obj.show(::isInArray(value, selectedCountryConfig))
        }
    }
  }

  function fillTabLinkLines(tab)
  {
    local linkLines = ::getTblValue("linkLines", tab, null)
    scene.findObject("link_lines_block").show(linkLines != null)
    if (linkLines == null)
      return

    //Need for update elements visible
    guiScene.applyPendingChanges(false)

    local linkContainer = scene.findObject("help_sheet")
    local linkLinesConfig = {
      startObjContainer = linkContainer
      endObjContainer = linkContainer
      lineInterval = ::getTblValue("lineInterval", linkLines, defaultLinkLinesInterval)
      links = linkLines?.links ?? []
      obstacles = ::getTblValue("obstacles", linkLines, null)
    }
    local linesData = ::LinesGenerator.getLinkLinesMarkup(linkLinesConfig)
    guiScene.replaceContentFromText(scene.findObject("link_lines_block"), linesData, linesData.len(), this)
  }

  function fillHelpPage()
  {
    local tab = getCurrentSubTab()
    if (!tab)
      return

    local basePresets = preset.getBasePresetNames()
    local haveIconsForControls = ::is_xinput_device() ||
      (u.search(basePresets, @(val) val == "keyboard"|| val == "keyboard_shooter") != null)
    showDefaultControls(haveIconsForControls)
    if ("moveControlsFrames" in tab)
      tab.moveControlsFrames(haveIconsForControls, scene)

    local backImg = scene.findObject("help_background_image")
    local curCountry = ::get_profile_country_sq().slice(8)
    if ("hasImageByCountries" in tab)
      curCountry = ::isInArray(curCountry, tab.hasImageByCountries)
                     ? curCountry
                     : tab.defaultValues.country

    backImg["background-image"] = ::format(::getTblValue("imagePattern", tab, ""), curCountry)
    fillActionBars(tab)
    updatePlatformControls()
  }

  //---------------------------- HELPER FUNCTIONS ----------------------------//

  function getModifierSymbol(id)
  {
    if (id in modifierSymbols)
      return modifierSymbols[id]

    local item = shortcutsAxisListModule[id]
    {
      if ("symbol" in item)
        modifierSymbols[id] <- ::colorize("axisSymbolColor", ::loc(item.symbol) + ::loc("ui/colon"))
      return modifierSymbols[id]
    }

    modifierSymbols[id] <- ""
    return modifierSymbols[id]
  }

  function fillAllTexts()
  {
    remapKeyboardKeysByLang()

    local scTextFull = []
    local tipTexts = {} //btnName = { text, isMain }
    modifierSymbols = {}

    local shortcutsList = ::g_controls_utils.getControlsList({
      unitType = pageUnitType,
      unitTags = pageUnitTag? [pageUnitTag] : []
    }).filter(@(item) item.needShowInHelp)

    for(local i=0; i<shortcutsList.len(); i++)
    {
      local item = shortcutsList[i]
      local name = (typeof(item)=="table")? item.id : item
      local isAxis = typeof(item)=="table" && item.type == CONTROL_TYPE.AXIS
      local isHeader = typeof(item)=="table" && ("type" in item) && (item.type == CONTROL_TYPE.HEADER || item.type == CONTROL_TYPE.SECTION)
      local shortcutNames = []
      local axisModifyerButtons = []
      local scText = ""

      if (isHeader)
      {
        scTextFull.append([::colorize("activeTextColor", ::loc("hotkeys/" + name))])
      }
      else
      {
        if (isAxis)
        {
          foreach (axisSc in shortcutsAxisListModule.types)
          {
            if (axisSc.type == CONTROL_TYPE.AXIS_SHORTCUT)
            {
              axisModifyerButtons.append(axisSc.id)
              if (axisSc.id == "")
                shortcutNames.append(name)
              else
                shortcutNames.append(name + "_" + axisSc.id)
            }
          }
        }
        else
          shortcutNames.append(name)

        local shortcuts = ::get_shortcuts(shortcutNames, preset)
        local btnList = {} //btnName = isMain

        //--- F1 help window ---
        for(local sc=0; sc<shortcuts.len(); sc++)
        {
          local text = getShortcutText(shortcuts[sc], btnList, true)
          if (text!="" && (!isAxis || axisModifyerButtons[sc] != "")) //do not show axis text (axis buttons only)
            scText += ((scText!="")? ";  ":"") +
            (isAxis? getModifierSymbol(axisModifyerButtons[sc]) : "") +
            text;
        }

        scText = ::loc((isAxis? "controls/":"hotkeys/") + name) + ::loc("ui/colon") + scText

        foreach(btnName, isMain in btnList)
          if (btnName in tipTexts)
          {
            tipTexts[btnName].isMain = tipTexts[btnName].isMain || isMain
            if (isMain)
              tipTexts[btnName].text = scText + "\n" + tipTexts[btnName].text
            else
              tipTexts[btnName].text += "\n" + scText
          } else
            tipTexts[btnName] <- { text = scText, isMain = isMain }

        scTextFull[scTextFull.len()-1].append(scText)
      }
    }

    //set texts and tooltips
    local view = {texts = [] }
    foreach(idx, textsArr in scTextFull)
      view.texts.append({
        width = 100.0 / (scTextFull.len() || 1) + "%pw"
        viewclass = "parInvert"
        text = ::g_string.implode(textsArr, "\n")
      })

    local obj = scene.findObject("full_shortcuts_texts")
    local data = ::handyman.renderCached("gui/commonParts/text", view)
    guiScene.replaceContentFromText(obj, data, data.len(), this)

    local kbdObj = scene.findObject("keyboard_div")
    foreach(btnName, btn in tipTexts)
    {
      local objId = ::stringReplace(btnName, " ", "_")
      local tipObj = kbdObj.findObject(objId)
      if (tipObj)
      {
        tipObj.tooltip = btn.text
        if (btn.isMain)
          tipObj.mainKey = "yes"
      }
      else
      {
        ::dagor.debug("tipObj = " + objId + " not found in the scene!")
        ::debugTableData(btn)
      }
    }
  }

  function remapKeyboardKeysByLang()
  {
    local map = ::getTblValue(::g_language.getLanguageName(), kbdKeysRemapByLang)
    if (!map)
      return
    local kbdObj = scene.findObject("keyboard_div")
    if (!::checkObj(kbdObj))
      return

    local replaceData = {}
    foreach(key, val in map)
    {
      local textObj = kbdObj.findObject(val)
      replaceData[val] <- {
        obj = kbdObj.findObject(key)
        text = (::checkObj(textObj) && textObj.text) || val
      }
    }
    foreach(id, data in replaceData)
      if (data.obj.isValid())
      {
        data.obj.id = id
        data.obj.setValue(data.text)
      }
  }

  function getShortcutText(shortcut, btnList, color = true)
  {
    local scText = ""
    for(local i=0; i<shortcut.len(); i++)
    {
      local sc = shortcut[i]
      if (!sc) continue

      local text = ""
      for (local k = 0; k < sc.dev.len(); k++)
      {
        text += ((k != 0)? " + ":"") + ::getLocalizedControlName(preset, sc.dev[k], sc.btn[k])
        local btnName = preset.getButtonName(sc.dev[k], sc.btn[k])
        if (btnName=="MWUp" || btnName=="MWDown")
          btnName = "MMB"
        if (btnName in btnList)
          btnList[btnName] = btnList[btnName] || (i==0)
        else
          btnList[btnName] <- (i==0)
      }
      if (text!="")
        scText += ((scText!="")? ", ":"") + (color? ("<color=@hotkeyColor>" + text + "</color>") : text)
    }
    return scText
  }

  function initGamepadPage()
  {
    guiScene.setUpdatesEnabled(false, false)
    updateGamepadIcons()
    updateGamepadTexts()
    guiScene.setUpdatesEnabled(true, true)
  }

  function updateGamepadIcons()
  {
    foreach(name, val in gamepadIcons.fullIconsList)
    {
      local obj = scene.findObject("ctrl_img_" + name)
      if (::check_obj(obj))
        obj["background-image"] = gamepadIcons.getTexture(name)
    }
  }

  function updateGamepadTexts()
  {
    local forceButtons = (pageUnitType == unitTypes.AIRCRAFT) ? ["camx"] : (pageUnitType == unitTypes.TANK) ? ["ID_ACTION_BAR_ITEM_5"] : []
    local ignoreButtons = ["ID_CONTINUE_SETUP"]
    local ignoreAxis = ["camx", "camy"]
    local customLocalization = { ["camx"] = "controls/help/camx" }

    local curJoyParams = ::JoystickParams()
    curJoyParams.setFrom(::joystick_get_cur_settings())
    local axisIds = [
      { id="joy_axis_l", x=0, y=1 }
      { id="joy_axis_r", x=2, y=3 }
    ]

    local joystickButtons = array(gamepadIcons.TOTAL_BUTTON_INDEXES, null)
    local joystickAxis = array(axisIds.len()*2, null)

    local scList = ::g_controls_utils.getControlsList({
      unitType = pageUnitType,
      unitTags = pageUnitTag? [pageUnitTag] : []
    })

    local shortcutNames = scList.filter(function(sc) {
      if (sc.type == CONTROL_TYPE.SHORTCUT || sc.type == CONTROL_TYPE.AXIS_SHORTCUT)
        return ignoreButtons.findvalue(@(b) b == sc.id) == null || forceButtons.findvalue(@(b) b == sc.id) != null

      if (sc.type == CONTROL_TYPE.AXIS)
      {
        if (forceButtons.findvalue(@(b) b == sc.id) != null)
          return true // Puts "camx" axis as a shortcut.
        if (ignoreAxis.findvalue(@(b) b == sc.id) != null)
          return false

        local axisId = curJoyParams.getAxis(sc.axisIndex).axisId
        if (axisId != -1 && axisId < joystickAxis.len())
        {
          joystickAxis[axisId] = joystickAxis[axisId] || []
          joystickAxis[axisId].append(sc.id)
        }
      }

      return false
    }).map(@(sc) sc.id)

    local shortcuts = ::get_shortcuts(shortcutNames, preset)
    foreach (i, item in shortcuts)
    {
      if (item.len() == 0)
        continue

      foreach(itemIdx, itemButton in item)
      {
        if (itemButton.dev.len() > 1) ///!!!TEMP: need to understand, how to show doubled/tripled/etc. shortcuts
          continue

        foreach(idx, devId in itemButton.dev)
          if (devId == ::JOYSTICK_DEVICE_0_ID)
          {
            local btnId = itemButton.btn[idx]
            if (!(btnId in joystickButtons))
              continue

            joystickButtons[btnId] = joystickButtons[btnId] || []
            joystickButtons[btnId].append(shortcutNames[i])
          }
      }
    }

    local bullet = "-"+ ::nbsp
    foreach (btnId, actions in joystickButtons)
    {
      local idSuffix = gamepadIcons.getButtonNameByIdx(btnId)
      if (idSuffix == "")
        continue

      local tObj = scene.findObject("joy_" + idSuffix)
      if (::checkObj(tObj))
      {
        local title = ""
        local tooltip = ""

        if (actions)
        {
          local titlesCount = 0
          local sliceBtn = "button"
          local sliceDirpad = "dirpad"
          local slicedSuffix = idSuffix.slice(0, 6)
          local maxActionsInTitle = 2
          if (slicedSuffix == sliceBtn || slicedSuffix == sliceDirpad)
            maxActionsInTitle = 1

          for (local a=0; a<actions.len(); a++)
          {
            local actionId = actions[a]

            local shText = ::loc("hotkeys/" + actionId)
            if (::getTblValue(actionId, customLocalization, null))
              shText = ::loc(customLocalization[actionId])

            if (titlesCount < maxActionsInTitle)
            {
              title += (title.len()? (::loc("ui/semicolon") + "\n"): "") + shText
              titlesCount++
            }

            tooltip += (tooltip.len()? "\n" : "") + bullet + shText
          }
        }
        title = title.len()? title : "---"
        tooltip = tooltip.len()? tooltip : ::loc("controls/unmapped")
        tooltip = ::loc("controls/help/press") + ::loc("ui/colon") + "\n" + tooltip
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    foreach (axis in axisIds)
    {
      local tObj = scene.findObject(axis.id)
      if (::checkObj(tObj))
      {
        local actionsX = (axis.x < joystickAxis.len() && joystickAxis[axis.x])? joystickAxis[axis.x] : []
        local actionsY = (axis.y < joystickAxis.len() && joystickAxis[axis.y])? joystickAxis[axis.y] : []

        local actionIdX = actionsX.len()? actionsX[0] : null
        local isIgnoredX = actionIdX && isInArray(actionIdX, ignoreAxis)
        local titleX = (actionIdX && !isIgnoredX)? ::loc("controls/" + actionIdX) : "---"

        local actionIdY = actionsY.len()? actionsY[0] : null
        local isIgnoredY = actionIdY && isInArray(actionIdY, ignoreAxis)
        local titleY = (actionIdY && !isIgnoredY)? ::loc("controls/" + actionIdY) : "---"

        local tooltipX = ""
        for (local a=0; a<actionsX.len(); a++)
          tooltipX += (tooltipX.len()? "\n" : "") + bullet + ::loc("controls/" + actionsX[a])
        tooltipX = tooltipX.len()? tooltipX : ::loc("controls/unmapped")
        tooltipX = ::loc("controls/help/mouse_aim_x") + ::loc("ui/colon") + "\n" + tooltipX

        local tooltipY = ""
        for (local a=0; a<actionsY.len(); a++)
          tooltipY += (tooltipY.len()? "\n" : "") + bullet + ::loc("controls/" + actionsY[a])
        tooltipY = tooltipY.len()? tooltipY : ::loc("controls/unmapped")
        tooltipY = ::loc("controls/help/mouse_aim_y") + ::loc("ui/colon") + "\n" + tooltipY

        local title = titleX + " + " + titleY
        local tooltip = tooltipX + "\n\n" + tooltipY
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    local tObj = scene.findObject("joy_btn_share")
    if (::checkObj(tObj))
    {
      local title = ::loc(helpMarkup.btnBackLocId)
      tObj.setValue(title)
      tObj.tooltip = ::loc("controls/help/press") + ::loc("ui/colon") + "\n" + title
    }

    local mouseObj = scene.findObject("joy_mouse")
    if (::checkObj(mouseObj))
    {
      local mouse_aim_x = (pageUnitType == unitTypes.AIRCRAFT) ? "controls/mouse_aim_x" : "controls/gm_mouse_aim_x"
      local mouse_aim_y = (pageUnitType == unitTypes.AIRCRAFT) ? "controls/mouse_aim_y" : "controls/gm_mouse_aim_y"

      local titleX = ::loc(mouse_aim_x)
      local titleY = ::loc(mouse_aim_y)
      local title = titleX + " + " + titleY
      local tooltipX = ::loc("controls/help/mouse_aim_x") + ::loc("ui/colon") + "\n" + ::loc(mouse_aim_x)
      local tooltipY = ::loc("controls/help/mouse_aim_y") + ::loc("ui/colon") + "\n" + ::loc(mouse_aim_y)
      local tooltip = tooltipX + "\n\n" + tooltipY
      mouseObj.setValue(title)
      mouseObj.tooltip = tooltip
    }
  }

  function showDefaultControls(isDefaultControls)
  {
    local tab = getCurrentSubTab()
    if (!tab)
      return

    local frameForHideIds = ::getTblValue("defaultControlsIds", tab, [])
    foreach (item in frameForHideIds)
      if ("frameId" in item)
        scene.findObject(item.frameId).show(isDefaultControls)

    local defControlsFrame = showSceneBtn("not_default_controls_frame", !isDefaultControls)
    if (isDefaultControls || !defControlsFrame)
      return

    local view = {
      rows = []
    }
    foreach (item in frameForHideIds)
    {
      local shortcutId = ::getTblValue("shortcut", item)
      if (!shortcutId)
        continue

      local rowData = {
        text = ::loc("controls/help/"+shortcutId+"_0")
        shortcutMarkup = ::g_shortcut_type.getShortcutMarkup(shortcutId, preset)
      }
      view.rows.append(rowData)
    }

    local markup = ::handyman.renderCached("gui/help/helpShortcutsList", view)
    guiScene.replaceContentFromText(defControlsFrame, markup, markup.len(), this)
  }

  function updatePlatformControls()
  {
    local isGamepadPreset = ::is_xinput_device()

    local buttonsList = {
      controller_switching_ammo = isGamepadPreset
      keyboard_switching_ammo = !isGamepadPreset
      controller_smoke_screen_label = isGamepadPreset
      smoke_screen_label = !isGamepadPreset
      controller_medicalkit_label = isGamepadPreset
      medicalkit_label = !isGamepadPreset
    }

    ::showBtnTable(scene, buttonsList)

  }

  function fillMissionObjectivesTexts()
  {
    local misHelpBlkPath = ::g_mission_type.getHelpPathForCurrentMission()
    if (misHelpBlkPath == null)
      return

    local sheetObj = scene.findObject("help_sheet")
    guiScene.replaceContent(sheetObj, misHelpBlkPath, this)

    local airCaptureZoneDescTextObj = scene.findObject("air_capture_zone_desc")
    if (::checkObj(airCaptureZoneDescTextObj))
    {
      local altitudeBottom = 0
      local altitudeTop = 0

      local misInfoBlk = ::get_mission_meta_info(::get_current_mission_name())
      local misBlk = misInfoBlk?.mis_file ? ::blkFromPath(misInfoBlk.mis_file) : null
      local areasBlk = misBlk?.areas
      if (areasBlk)
      {
        for (local i = 0; i < areasBlk.blockCount(); i++)
        {
          local block = areasBlk.getBlock(i)
          if (block && block.type == "Cylinder" && ::u.isTMatrix(block.tm))
          {
            altitudeBottom = ::ceil(block.tm[3].y)
            altitudeTop = ::ceil(block.tm[1].y + block.tm[3].y)
            break
          }
        }
      }

      if (altitudeBottom && altitudeTop)
      {
        airCaptureZoneDescTextObj.setValue(::loc("hints/tutorial_newbie/air_domination/air_capture_zone") + " " +
          ::loc("hints/tutorial_newbie/air_domination/air_capture_zone/altitudes", {
          altitudeBottom = ::colorize("userlogColoredText", altitudeBottom),
          altitudeTop = ::colorize("userlogColoredText", altitudeTop)
          }))
      }
    }
  }

  function fillHotas4Image()
  {
    local imgObj = scene.findObject("image")
    if (!::checkObj(imgObj))
      return

    imgObj["background-image"] = ::loc("thrustmaster_tflight_hotas_4_controls_image", "")
  }

  function afterModalDestroy()
  {
    if (isStartedFromMenu)
    {
      local curHandler = ::handlersManager.getActiveBaseHandler()
      if (curHandler != null && curHandler instanceof ::gui_handlers.FlightMenu)
        curHandler.onResumeRaw()
    }
  }

  function fillActionBars(tab)
  {
    foreach (actionBar in (tab?.actionBars ?? []))
    {
      local obj = scene.findObject(actionBar?.nest)
      local actionBarItems = actionBar?.items ?? []
      if (!::check_obj(obj) || !actionBarItems.len())
        continue

      local items = []
      foreach (item in actionBarItems)
        items.append(buildActionbarItemView(item, actionBar))

      local view = {
        items = items
      }
      local blk = ::handyman.renderCached(("gui/help/helpActionBarItem"), view)
      guiScene.replaceContentFromText(obj, blk, blk.len(), this)
    }
  }

  function buildActionbarItemView(item, actionBar)
  {
    local actionBarType = ::g_hud_action_bar_type.getByActionItem(item)
    local viewItem = {}

    viewItem.id                 <- item.id
    viewItem.selected           <- item?.selected ? "yes" : "no"
    viewItem.active             <- item?.active ? "yes" : "no"

    if (item.type == ::EII_BULLET)
      viewItem.icon <- item.icon
    else
      viewItem.icon <- actionBarType.getIcon(null, ::getAircraftByName(actionBar?.unitId ?? ""))

    return viewItem
  }
}
