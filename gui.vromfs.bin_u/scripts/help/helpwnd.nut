from "%scripts/dagui_library.nut" import *
from "%scripts/mainConsts.nut" import HELP_CONTENT_SET

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { g_mission_type } = require("%scripts/missions/missionType.nut")
let { g_hud_action_bar_type } = require("%scripts/hud/hudActionBarType.nut")
let { g_hud_event_manager } = require("%scripts/hud/hudEventManager.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { isXInputDevice } = require("controls")
let { ceil } = require("math")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_child_by_value } = require("%sqDagui/daguiUtil.nut")
let { handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { format } = require("string")
let { get_current_mission_name } = require("mission")
let { get_meta_mission_info_by_name } = require("guiMission")
let { blkFromPath } = require("%sqstd/datablock.nut")
let { search, isEmpty, isTMatrix } = require("%sqStdLibs/helpers/u.nut")
let gamepadIcons = require("%scripts/controls/gamepadIcons.nut")
let helpTabs = require("%scripts/controls/help/controlsHelpTabs.nut")
let helpMarkup = require("%scripts/controls/help/controlsHelpMarkup.nut")
let shortcutsAxisListModule = require("%scripts/controls/shortcutsList/shortcutsAxis.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { EII_BULLET } = require("hudActionBarConst")
let { profileCountrySq } = require("%scripts/user/playerCountry.nut")
let { hotasControlImagePath } = require("%scripts/controls/hotas.nut")
let { getControlsList } = require("%scripts/controls/controlsUtils.nut")
let { CONTROL_TYPE } = require("%scripts/controls/controlsConsts.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { getLocalizedControlName } = require("%scripts/controls/controlsVisual.nut")
let helpTypes = require("%scripts/controls/help/controlsHelpTypes.nut")
let { getLinkLinesMarkup } = require("%scripts/linesGenerator.nut")
let { joystickGetCurSettings, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")
let { getCurControlsPreset } = require("%scripts/controls/controlsState.nut")

require("%scripts/viewUtils/bhvHelpFrame.nut")

function gui_modal_help(isStartedFromMenu, contentSet, missionType = null) {
  loadHandler(gui_handlers.helpWndModalHandler, {
    isStartedFromMenu
    contentSet
    missionType
  })
}

gui_handlers.helpWndModalHandler <- class (gui_handlers.BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/help/helpWnd.blk"

  defaultLinkLinesInterval = "@helpLineInterval"

  curTabIdx = -1
  curSubTabIdx = -1
  visibleTabs = []

  contentSet = HELP_CONTENT_SET.MISSION
  missionType = null
  isStartedFromMenu = false

  preset = null

  pageUnitType = null
  pageUnitTag = null
  modifierSymbols = null

  kbdKeysRemapByLang = {
    German = { Y = "Z", Z = "Y" }
    French = { Q = "A", A = "Q", W = "Z", Z = "W" }
  }

  function initScreen() {
    this.preset = this.preset || getCurControlsPreset()
    this.visibleTabs = helpTabs.getTabs(this.contentSet)
    this.fillTabs()

    let subTabsObj = this.scene.findObject("sub_tabs_list")
    move_mouse_on_child_by_value(subTabsObj?.isVisible()
      ? subTabsObj
      : this.scene.findObject("tabs_list"))

    g_hud_event_manager.onHudEvent("helpOpened")
  }

  function fillTabs() {
    let tabsObj = this.scene.findObject("tabs_list")
    let countVisibleTabs = this.visibleTabs.len()

    let preselectedTab = helpTabs.getPreferableType(this.contentSet)

    this.curTabIdx = 0
    let view = { tabs = [] }
    foreach (idx, group in this.visibleTabs) {
      local isSelected = false
      foreach (sIdx, subTab in group.list)
        if (subTab == preselectedTab) {
          isSelected = true
          this.curSubTabIdx = sIdx
          this.curTabIdx = idx
        }

      view.tabs.append({
        tabName = group.title
        navImagesText = getNavigationImagesText(idx, countVisibleTabs)
        selected = isSelected
      })
    }

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    this.guiScene.replaceContentFromText(tabsObj, data, data.len(), this)

    this.fillSubTabs()
  }

  function fillSubTabs() {
    let subTabsList = this.visibleTabs[this.curTabIdx].list

    let isSubTabsVisible = subTabsList.len() > 1
    let subTabsObj = showObjById("sub_tabs_list", isSubTabsVisible, this.scene)
    if (!subTabsObj)
      return

    let view = { items = [] }
    if (isSubTabsVisible) {
      foreach (idx, tType in subTabsList) {
        view.items.append({
          text = tType.subTabName
          selected = idx == this.curSubTabIdx
        })
      }

      let data = handyman.renderCached("%gui/commonParts/shopFilter.tpl", view)
      this.guiScene.replaceContentFromText(subTabsObj, data, data.len(), this)
    }

    this.fillSubTabContent()
  }

  function getCurrentSubTab() {
    let list = this.visibleTabs[this.curTabIdx].list
    let tab = list?[this.curSubTabIdx] ?? list?[0]
    let ctrlHelpCfgName = g_mission_type.getControlHelpName()

    if (tab?.name == "MISSION_OBJECTIVES" && ctrlHelpCfgName != null) {
      let helpCfg = helpTypes[ctrlHelpCfgName]
      let addCfg = { pageFillfuncName = null } 
      let fieldsToAddToMissionHelp = [
        "pageBlkName", "actionBars", "linkLines", "defaultValues",
        "imagePattern", "hasImageByCountries", "countryRelatedObjs", "customUpdateSheetFunc"
      ]

      foreach (fieldToAdd in fieldsToAddToMissionHelp) {
        let val = helpCfg?[fieldToAdd]
        if (val != null)
          addCfg[fieldToAdd] <- val
      }
      return tab.__merge(addCfg)
    }

    return tab
  }

  function onHelpSheetChange(obj) {
    let selTabIdx = obj.getValue()
    if (this.curTabIdx == selTabIdx)
      return

    this.curTabIdx = selTabIdx
    this.fillSubTabs()
  }

  function onHelpSubSheetChange(obj) {
    let selTabIdx = obj.getValue()
    if (obj.childrenCount() > 1 && this.curSubTabIdx == selTabIdx)
      return

    this.curSubTabIdx = selTabIdx
    this.fillSubTabContent()
  }

  function fillSubTabContent() {
    let tab = this.getCurrentSubTab()
    if (!tab)
      return

    this.pageUnitType = unitTypes.getByBit(tab?.pageUnitTypeBit)
    this.pageUnitTag = tab?.pageUnitTag

    let sheetObj = this.scene.findObject("help_sheet")
    let pageBlkName = getTblValue("pageBlkName", tab, "")
    if (!isEmpty(pageBlkName))
      this.guiScene.replaceContent(sheetObj, pageBlkName, this)

    let fillFuncName = getTblValue("pageFillfuncName", tab)
    let fillFunc = fillFuncName ? getTblValue(fillFuncName, this) : this.fillHelpPage
    fillFunc()

    this.showTabSpecificControls(tab)
    tab?.customUpdateSheetFunc(sheetObj)
    this.guiScene.performDelayed(this, function() {
      if (!this.isValid())
        return

      this.fillTabLinkLines(tab)
    })
  }

  function showTabSpecificControls(tab) {
    let countryRelatedObjs = getTblValue("countryRelatedObjs", tab, null)
    if (countryRelatedObjs != null) {
      local selectedCountry = profileCountrySq.get().slice(8)
      selectedCountry = (selectedCountry in countryRelatedObjs) ? selectedCountry : tab.defaultValues.country
      let selectedCountryConfig = countryRelatedObjs?[selectedCountry] ?? []
      foreach (_key, countryConfig in countryRelatedObjs)
        foreach (_idx, value in countryConfig) {
          let obj = this.scene.findObject(value)
          if (checkObj(obj))
            obj.show(isInArray(value, selectedCountryConfig))
        }
    }
  }

  function fillTabLinkLines(tab) {
    let linkLines = getTblValue("linkLines", tab, null)
    this.scene.findObject("link_lines_block").show(linkLines != null)
    if (linkLines == null)
      return

    
    this.guiScene.applyPendingChanges(false)

    let linkContainer = this.scene.findObject("help_sheet")
    let linkLinesConfig = {
      startObjContainer = linkContainer
      endObjContainer = linkContainer
      lineInterval = getTblValue("lineInterval", linkLines, this.defaultLinkLinesInterval)
      links = linkLines?.links ?? []
      obstacles = getTblValue("obstacles", linkLines, null)
    }
    let linesData = getLinkLinesMarkup(linkLinesConfig)
    this.guiScene.replaceContentFromText(this.scene.findObject("link_lines_block"), linesData, linesData.len(), this)
  }

  function fillHelpPage() {
    let tab = this.getCurrentSubTab()
    if (!tab)
      return

    let basePresets = this.preset.getBasePresetNames()
    let haveIconsForControls = isXInputDevice() ||
      (search(basePresets, @(val) val == "keyboard" || val == "keyboard_shooter") != null)
    this.showDefaultControls(haveIconsForControls)
    if ("moveControlsFrames" in tab)
      tab.moveControlsFrames(haveIconsForControls, this.scene)

    let backImg = this.scene.findObject("help_background_image")
    local curCountry = profileCountrySq.get().slice(8)
    if ("hasImageByCountries" in tab)
      curCountry = isInArray(curCountry, tab.hasImageByCountries)
                     ? curCountry
                     : tab.defaultValues.country

    backImg["background-image"] = format(getTblValue("imagePattern", tab, ""), curCountry)
    this.fillActionBars(tab)
    this.updatePlatformControls()
  }

  

  function getModifierSymbol(id) {
    if (id in this.modifierSymbols)
      return this.modifierSymbols[id]

    let item = shortcutsAxisListModule[id]
    {
      if ("symbol" in item)
        this.modifierSymbols[id] <- colorize("axisSymbolColor", $"{loc(item.symbol)}{loc("ui/colon")}")
      return this.modifierSymbols[id]
    }

    this.modifierSymbols[id] <- ""
    return this.modifierSymbols[id]
  }

  function fillAllTexts() {
    this.remapKeyboardKeysByLang()

    let scTextFull = []
    let tipTexts = {} 
    this.modifierSymbols = {}

    let shortcutsList = getControlsList(this.pageUnitType, this.pageUnitTag ? [this.pageUnitTag] : [])
      .filter(@(item) item.needShowInHelp)

    for (local i = 0; i < shortcutsList.len(); i++) {
      let item = shortcutsList[i]
      let name = (type(item) == "table") ? item.id : item
      let isAxis = type(item) == "table" && item.type == CONTROL_TYPE.AXIS
      let isHeader = type(item) == "table" && ("type" in item) && (item.type == CONTROL_TYPE.HEADER || item.type == CONTROL_TYPE.SECTION)
      let shortcutNames = []
      let axisModifierButtons = []
      local scText = ""

      if (isHeader) {
        scTextFull.append([colorize("activeTextColor", loc($"hotkeys/{name}"))])
      }
      else {
        if (isAxis) {
          foreach (axisSc in shortcutsAxisListModule.types) {
            if (axisSc.type == CONTROL_TYPE.AXIS_SHORTCUT) {
              axisModifierButtons.append(axisSc.id)
              if (axisSc.id == "")
                shortcutNames.append(name)
              else
                shortcutNames.append($"{name}_{axisSc.id}")
            }
          }
        }
        else
          shortcutNames.append(name)

        let shortcuts = getShortcuts(shortcutNames, this.preset)
        let btnList = {} 

        
        for (local sc = 0; sc < shortcuts.len(); sc++) {
          let text = this.getShortcutText(shortcuts[sc], btnList, true)
          if (text != "" && (!isAxis || axisModifierButtons[sc] != "")) 
            scText = "".concat(scText, scText != "" ? ";  " : "",
              isAxis ? this.getModifierSymbol(axisModifierButtons[sc]) : "", text)
        }

        scText = "".concat(loc($"{isAxis ? "controls/" : "hotkeys/"}{name}"), loc("ui/colon"), scText)

        foreach (btnName, isMain in btnList)
          if (btnName in tipTexts) {
            tipTexts[btnName].isMain = tipTexts[btnName].isMain || isMain
            if (isMain)
              tipTexts[btnName].text =  "\n".concat(scText, tipTexts[btnName].text)
            else
              tipTexts[btnName].text = "\n".concat(tipTexts[btnName].text, scText)
          }
          else
            tipTexts[btnName] <- { text = scText, isMain = isMain }

        scTextFull[scTextFull.len() - 1].append(scText)
      }
    }

    
    let view = { texts = [] }
    foreach (_idx, textsArr in scTextFull)
      view.texts.append({
        width = "".concat(100.0 / max(scTextFull.len(), 1), "%pw")
        viewclass = "parInvert"
        text = "\n".join(textsArr, true)
      })

    let obj = this.scene.findObject("full_shortcuts_texts")
    let data = handyman.renderCached("%gui/commonParts/text.tpl", view)
    this.guiScene.replaceContentFromText(obj, data, data.len(), this)

    let kbdObj = this.scene.findObject("keyboard_div")
    foreach (btnName, btn in tipTexts) {
      let objId = btnName.replace(" ", "_")
      let tipObj = kbdObj.findObject(objId)
      if (tipObj) {
        tipObj.tooltip = btn.text
        if (btn.isMain)
          tipObj.mainKey = "yes"
      }
      else {
        log($"tipObj = {objId} not found in the scene!")
        debugTableData(btn)
      }
    }
  }

  function remapKeyboardKeysByLang() {
    let map = getTblValue(getLanguageName(), this.kbdKeysRemapByLang)
    if (!map)
      return
    let kbdObj = this.scene.findObject("keyboard_div")
    if (!checkObj(kbdObj))
      return

    let replaceData = {}
    foreach (key, val in map) {
      let textObj = kbdObj.findObject(val)
      replaceData[val] <- {
        obj = kbdObj.findObject(key)
        text = (checkObj(textObj) && textObj.text) || val
      }
    }
    foreach (id, data in replaceData)
      if (data.obj.isValid()) {
        data.obj.id = id
        data.obj.setValue(data.text)
      }
  }

  function getShortcutText(shortcut, btnList, color = true) {
    let scText = []
    for (local i = 0; i < shortcut.len(); i++) {
      let sc = shortcut[i]
      if (!sc)
        continue

      let textArr = []
      for (local k = 0; k < sc.dev.len(); k++) {
        textArr.append(getLocalizedControlName(this.preset, sc.dev[k], sc.btn[k]))
        local btnName = this.preset.getButtonName(sc.dev[k], sc.btn[k])
        if (btnName == "MWUp" || btnName == "MWDown")
          btnName = "MMB"
        if (btnName in btnList)
          btnList[btnName] = btnList[btnName] || (i == 0)
        else
          btnList[btnName] <- (i == 0)
      }
      if (textArr.len() > 0) {
        let text = " + ".join(textArr)
        scText.append(color ? $"<color=@hotkeyColor>{text}</color>" : text)
      }
    }
    return ", ".join(scText)
  }

  function initGamepadPage() {
    this.guiScene.setUpdatesEnabled(false, false)
    this.updateGamepadIcons()
    this.updateGamepadTexts()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function updateGamepadIcons() {
    foreach (name, _val in gamepadIcons.fullIconsList) {
      let obj = this.scene.findObject($"ctrl_img_{name}")
      if (checkObj(obj))
        obj["background-image"] = gamepadIcons.getTexture(name)
    }
  }

  function updateGamepadTexts() {
    let forceButtons = (this.pageUnitType == unitTypes.AIRCRAFT) ? ["camx"] : (this.pageUnitType == unitTypes.TANK) ? ["ID_ACTION_BAR_ITEM_5"] : []
    let ignoreButtons = ["ID_CONTINUE_SETUP"]
    let ignoreAxis = ["camx", "camy"]
    let customLocalization = { ["camx"] = "controls/help/camx" }

    let curJoyParams = joystickGetCurSettings()
    let axisIds = [
      { id = "joy_axis_l", x = 0, y = 1 }
      { id = "joy_axis_r", x = 2, y = 3 }
    ]

    let joystickButtons = array(gamepadIcons.TOTAL_BUTTON_INDEXES, null)
    let joystickAxis = array(axisIds.len() * 2, null)

    let scList = getControlsList(this.pageUnitType, this.pageUnitTag ? [this.pageUnitTag] : [])

    let shortcutNames = scList.filter(function(sc) {
      if (sc.type == CONTROL_TYPE.SHORTCUT || sc.type == CONTROL_TYPE.AXIS_SHORTCUT)
        return ignoreButtons.findvalue(@(b) b == sc.id) == null || forceButtons.findvalue(@(b) b == sc.id) != null

      if (sc.type == CONTROL_TYPE.AXIS) {
        if (forceButtons.findvalue(@(b) b == sc.id) != null)
          return true 
        if (ignoreAxis.findvalue(@(b) b == sc.id) != null)
          return false

        let axisId = curJoyParams.getAxis(sc.axisIndex).axisId
        if (axisId != -1 && axisId < joystickAxis.len()) {
          joystickAxis[axisId] = joystickAxis[axisId] ?? []
          joystickAxis[axisId].append(sc.id)
        }
      }

      return false
    }).map(@(sc) sc.id)

    let shortcuts = getShortcuts(shortcutNames, this.preset)
    foreach (i, item in shortcuts) {
      if (item.len() == 0)
        continue

      foreach (_itemIdx, itemButton in item) {
        if (itemButton.dev.len() > 1) 
          continue

        foreach (idx, devId in itemButton.dev)
          if (devId == JOYSTICK_DEVICE_0_ID) {
            let btnId = itemButton.btn[idx]
            if (!(btnId in joystickButtons))
              continue

            joystickButtons[btnId] = joystickButtons[btnId] ?? []
            joystickButtons[btnId].append(shortcutNames[i])
          }
      }
    }

    let bullet =$"-{nbsp}"
    foreach (btnId, actions in joystickButtons) {
      let idSuffix = gamepadIcons.getButtonNameByIdx(btnId)
      if (idSuffix == "")
        continue

      let tObj = this.scene.findObject($"joy_{idSuffix}")
      if (checkObj(tObj)) {
        local title = ""
        local tooltip = ""

        if (actions) {
          local titlesCount = 0
          let sliceBtn = "button"
          let sliceDirpad = "dirpad"
          let slicedSuffix = idSuffix.slice(0, 6)
          local maxActionsInTitle = 2
          if (slicedSuffix == sliceBtn || slicedSuffix == sliceDirpad)
            maxActionsInTitle = 1

          for (local a = 0; a < actions.len(); a++) {
            let actionId = actions[a]

            local shText = loc($"hotkeys/{actionId}")
            if (getTblValue(actionId, customLocalization, null))
              shText = loc(customLocalization[actionId])

            if (titlesCount < maxActionsInTitle) {
              title = "".concat(title, title.len() ? $"{loc("ui/semicolon")}\n" : "", shText)
              titlesCount++
            }

            tooltip = "".concat(tooltip, tooltip.len() ? "\n" : "", bullet, shText)
          }
        }
        title = title.len() ? title : "---"
        tooltip = tooltip.len() ? tooltip : loc("controls/unmapped")
        tooltip = "".concat(loc("controls/help/press"), loc("ui/colon"), "\n", tooltip)
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    foreach (axis in axisIds) {
      let tObj = this.scene.findObject(axis.id)
      if (checkObj(tObj)) {
        let actionsX = (axis.x < joystickAxis.len() && joystickAxis[axis.x]) ? joystickAxis[axis.x] : []
        let actionsY = (axis.y < joystickAxis.len() && joystickAxis[axis.y]) ? joystickAxis[axis.y] : []

        let actionIdX = actionsX.len() ? actionsX[0] : null
        let isIgnoredX = actionIdX && isInArray(actionIdX, ignoreAxis)
        let titleX = (actionIdX && !isIgnoredX) ? loc($"controls/{actionIdX}") : "---"

        let actionIdY = actionsY.len() ? actionsY[0] : null
        let isIgnoredY = actionIdY && isInArray(actionIdY, ignoreAxis)
        let titleY = (actionIdY && !isIgnoredY) ? loc($"controls/{actionIdY}") : "---"

        local tooltipX = ""
        for (local a = 0; a < actionsX.len(); a++)
          tooltipX = "".concat(tooltipX, tooltipX.len() ? "\n" : "", bullet, loc($"controls/{actionsX[a]}"))
        tooltipX = tooltipX.len() ? tooltipX : loc("controls/unmapped")
        tooltipX = "".concat(loc("controls/help/mouse_aim_x"), loc("ui/colon"), "\n", tooltipX)

        local tooltipY = ""
        for (local a = 0; a < actionsY.len(); a++)
          tooltipY = "".concat(tooltipY, tooltipY.len() ? "\n" : "", bullet, loc($"controls/{actionsY[a]}"))
        tooltipY = tooltipY.len() ? tooltipY : loc("controls/unmapped")
        tooltipY = "".concat(loc("controls/help/mouse_aim_y"), loc("ui/colon"), "\n", tooltipY)

        let title = $"{titleX} + {titleY}"
        let tooltip =  "\n\n".concat(tooltipX, tooltipY)
        tObj.setValue(title)
        tObj.tooltip = tooltip
      }
    }

    let tObj = this.scene.findObject("joy_btn_share")
    if (checkObj(tObj)) {
      let title = loc(helpMarkup.btnBackLocId)
      tObj.setValue(title)
      tObj.tooltip = "".concat(loc("controls/help/press"), loc("ui/colon"), "\n", title)
    }

    let mouseObj = this.scene.findObject("joy_mouse")
    if (checkObj(mouseObj)) {
      let mouse_aim_x = (this.pageUnitType == unitTypes.AIRCRAFT) ? "controls/mouse_aim_x" : "controls/gm_mouse_aim_x"
      let mouse_aim_y = (this.pageUnitType == unitTypes.AIRCRAFT) ? "controls/mouse_aim_y" : "controls/gm_mouse_aim_y"

      let titleX = loc(mouse_aim_x)
      let titleY = loc(mouse_aim_y)
      let title = $"{titleX} + {titleY}"
      let tooltipX = "".concat(loc("controls/help/mouse_aim_x"), loc("ui/colon"), "\n", loc(mouse_aim_x))
      let tooltipY = "".concat(loc("controls/help/mouse_aim_y"), loc("ui/colon"), "\n", loc(mouse_aim_y))
      let tooltip =  "\n\n".concat(tooltipX, tooltipY)
      mouseObj.setValue(title)
      mouseObj.tooltip = tooltip
    }
  }

  function showDefaultControls(isDefaultControls) {
    let tab = this.getCurrentSubTab()
    if (!tab)
      return

    let frameForHideIds = getTblValue("defaultControlsIds", tab, [])
    foreach (item in frameForHideIds)
      if ("frameId" in item)
        this.scene.findObject(item.frameId).show(isDefaultControls)

    let defControlsFrame = showObjById("not_default_controls_frame", !isDefaultControls, this.scene)
    if (isDefaultControls || !defControlsFrame)
      return

    let view = {
      rows = []
    }
    foreach (item in frameForHideIds) {
      let shortcutId = getTblValue("shortcut", item)
      if (!shortcutId)
        continue

      let rowData = {
        text = loc($"controls/help/{shortcutId}_0")
        shortcutMarkup = g_shortcut_type.getShortcutMarkup(shortcutId, this.preset)
      }
      view.rows.append(rowData)
    }

    let markup = handyman.renderCached("%gui/help/helpShortcutsList.tpl", view)
    this.guiScene.replaceContentFromText(defControlsFrame, markup, markup.len(), this)
  }

  function updatePlatformControls() {
    let isGamepadPreset = isXInputDevice()

    let buttonsList = {
      controller_switching_ammo = isGamepadPreset
      keyboard_switching_ammo = !isGamepadPreset
      controller_smoke_screen_label = isGamepadPreset
      smoke_screen_label = !isGamepadPreset
      controller_medicalkit_label = isGamepadPreset
      medicalkit_label = !isGamepadPreset
    }

    showObjectsByTable(this.scene, buttonsList)

  }

  function fillMissionObjectivesTexts() {
    let misHelpBlkPath = (this.missionType?.helpBlkPath ?? "") != ""
      ? this.missionType.helpBlkPath
      : g_mission_type.getHelpPathForCurrentMission()
    if (misHelpBlkPath == null)
      return

    let sheetObj = this.scene.findObject("help_sheet")
    this.guiScene.replaceContent(sheetObj, misHelpBlkPath, this)

    let airCaptureZoneDescTextObj = this.scene.findObject("air_capture_zone_desc")
    if (checkObj(airCaptureZoneDescTextObj)) {
      local altitudeBottom = 0
      local altitudeTop = 0

      let misInfoBlk = get_meta_mission_info_by_name(get_current_mission_name())
      let misBlk = misInfoBlk?.mis_file ? blkFromPath(misInfoBlk.mis_file) : null
      let areasBlk = misBlk?.areas
      if (areasBlk) {
        for (local i = 0; i < areasBlk.blockCount(); i++) {
          let block = areasBlk.getBlock(i)
          if (block && block.type == "Cylinder" && isTMatrix(block.tm)) {
            altitudeBottom = ceil(block.tm[3].y)
            altitudeTop = ceil(block.tm[1].y + block.tm[3].y)
            break
          }
        }
      }

      if (altitudeBottom && altitudeTop) {
        airCaptureZoneDescTextObj.setValue(" ".concat(
          loc("hints/tutorial_newbie/air_domination/air_capture_zone"),
          loc("hints/tutorial_newbie/air_domination/air_capture_zone/altitudes", {
            altitudeBottom = colorize("userlogColoredText", altitudeBottom),
            altitudeTop = colorize("userlogColoredText", altitudeTop)
          })
        ))
      }
    }
  }

  function fillHotas4Image() {
    let imgObj = this.scene.findObject("image")
    if (!checkObj(imgObj))
      return

    imgObj["background-image"] = hotasControlImagePath
  }

  function afterModalDestroy() {
    if (this.isStartedFromMenu) {
      let curHandler = handlersManager.getActiveBaseHandler()
      if (curHandler != null && curHandler instanceof gui_handlers.FlightMenu)
        curHandler.onResumeRaw()
    }
  }

  function fillActionBars(tab) {
    foreach (actionBar in (tab?.actionBars ?? [])) {
      let obj = this.scene.findObject(actionBar?.nest)
      let actionBarItems = actionBar?.items ?? []
      if (!checkObj(obj) || !actionBarItems.len())
        continue

      let items = []
      foreach (item in actionBarItems)
        items.append(this.buildActionbarItemView(item, actionBar))

      let view = {
        items = items
      }
      let blk = handyman.renderCached(("%gui/help/helpActionBarItem.tpl"), view)
      this.guiScene.replaceContentFromText(obj, blk, blk.len(), this)
    }
  }

  function buildActionbarItemView(item, actionBar) {
    let actionBarType = g_hud_action_bar_type.getByActionItem(item)
    let viewItem = {}

    viewItem.id                 <- item.id
    viewItem.selected           <- item?.selected ? "yes" : "no"
    viewItem.active             <- item?.active ? "yes" : "no"

    if (item.type == EII_BULLET)
      viewItem.icon <- item.icon
    else
      viewItem.icon <- actionBarType.getIcon(item, null,
        getAircraftByName(actionBar?.unitId ?? ""), actionBar?.hudUnitType ?? "")

    return viewItem
  }
}

return {
  gui_modal_help
}