import "%scripts/options/optionsList.nut" as optionsListModule
import "%scripts/options/fxOptions.nut" as fxOptions
import "%scripts/options/handlers/preloaderOptionsModal.nut" as preloaderOptionsModal
import "%scripts/options/handlers/tankSightSettings.nut" as openTankSightSettings
from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler, get_gui_handler
from "%scripts/genericOptions.nut" import GenericOptionsModal
from "%appGlobals/clientState/localProfile.nut" import saveLocalAccountSettings
from "%scripts/sqDagui/daguiUtil.nut" import removeTextareaTags
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/social/crossplay.nut" import isCrossNetworkChatEnabled
from "%scripts/options/systemOptions.nut" import fillSystemGuiOptions, resetSystemGuiOptions, resetSystemActiveTabDiffs,
  getActiveTabDiffSectionTitles, onSystemGuiOptionChanged, onRestartClient, onSystemOptionValueHover,
  updateGuiOptionsGroup, getOptionDiffTags, getOptionSectionTitle, getOptionIdByObjId
from "%scripts/options/handlers/addRadioWnd.nut" import openAddRadioWnd
from "%sqstd/platform.nut" import isPC, isXbox
from "%scripts/tutorials/tutorialsState.nut" import resetTutorialSkip
from "%scripts/breadcrumb.nut" import setBreadcrumbGoBackParams, getBackSceneName
from "%scripts/options/gpuBenchmarkWnd.nut" import showGpuBenchmarkWnd
from "%scripts/utils/restartClient.nut" import canRestartClient
from "%scripts/options/optionsUtils.nut" import isOptionReqRestartChanged, setOptionReqRestartValue
from "%scripts/controls/controlsCompatibility.nut" import setShortcutsAndSaveControls, getShortcuts
from "%scripts/options/optionsExtNames.nut" import OPTIONS_MODE_GAMEPLAY, USEROPT_PTT, USEROPT_SKIP_WEAPON_WARNING
from "%scripts/options/optionsExt.nut" import get_option, getOptionsRows
from "%scripts/postFxSettings.nut" import guiStartPostfxSettings
from "%scripts/popups/popups.nut" import addPopup
from "%scripts/chat/chatStates.nut" import chatStatesCanUseVoice
from "%scripts/controls/assignShortcut.nut" import openAssignShortcut
from "%scripts/options/handlers/shipHitIconsMenu.nut" import openShipHitIconsMenu
from "%scripts/promo/promoActions.nut" import addPromoAction
from "%scripts/options/initOptions.nut" import initOptions
from "%scripts/assistantMapQr.nut" import guiStartAssistantMapQrWindow, isAssistantMapEnabled, isAssistantMapAvailable
from "%sqStdLibs/helpers/subscriptions.nut" import broadcastEvent, addListenersWithoutEnv
from "%appGlobals/options/optionsScreenState.nut" import optionsScreen, optionsItems, getOptionsItem, setOptionsItem,
  setOptionsScreenField, resetOptionsScreen
from "%scripts/dargScreenBridge.nut" import locText, resolveColorTags, mkComboItems, mkControlObj, subscribeScreenActions
from "string" import format
from "guiOptions" import set_gui_option
from "soundOptions" import reset_volumes, toggle_test_headphones_sound, stop_test_headphones_sound
from "%sqstd/string.nut" import utf8ToLower
from "gameplayBinding" import isInFlight
from "dagor.workcycle" import defer
from "eventbus" import eventbus_subscribe
from "%scripts/dagui_natives.nut" import is_internet_radio_station_removable, remove_internet_radio_station, get_internet_radio_options, gchat_voice_echo_test
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/utils_sa.nut" import is_multiplayer

let webui = require_optional("webui")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { getShortcutText, hackTextAssignmentForR2buttonOnPS4 } = require("%scripts/controls/controlsVisual.nut")

const MAX_NUM_VISIBLE_FILTER_OPTIONS = 25

const WND_CALLS = ["goBack", "onApply", "onSystemOptionsRestartClient", "onSystemOptionsReset",
  "onSystemOptionsResetTab", "onOpenGpuBenchmark", "onWebUiMap", "onAssistantMapQrCode",
  "onDialogAddRadio", "onDialogEditRadio", "onRemoveRadio", "onEchoTestButton",
  "onAssignInternetRadioButton", "onClearInternetRadioButton", "onAssignInternetRadioPrevButton",
  "onClearInternetRadioPrevButton", "onAssignInternetRadioNextButton", "onClearInternetRadioNextButton",
  "onAssignVoiceButton", "onClearVoiceButton"]

const HOTKEY_BY_BTN_NAME = { R3 = "J:RS", X = "J:X" }

let locOrDefault = @(text, defLocId) (text ?? "") != "" ? locText(text) : loc(defLocId)
let locHotkeyOpt = @(opt) opt.__merge({ optionText = locText(opt.optionText), tip = locText(opt?.tip),
  resetTip = locText(opt?.resetTip ?? "#mainmenu/btnReset") })

let controlKind = @(option) option.controlName == "list" || option.controlName == "spinner" ? "combobox"
  : option.controlName


function mkRowView(option) {
  let { id, controlType, controlName } = option
  let isHeader = controlType == optionControlType.HEADER
  let hasTitle = controlName != "button" || (option?.showTitle ?? false)
  return {
    id = option.getTrId()
    itemId = id
    isHeader
    label = hasTitle ? option.getTitle() : ""
    hint = resolveColorTags(option.hint ?? "")
    hasWarningIcon = option.hasWarningIcon
    control = isHeader ? null : {
      kind = controlKind(option)
      min = option?.min ?? 0
      max = option?.max ?? 100
      step = option?.step ?? 5
      hasValueText = option.needShowValueText
      textChecked = locOrDefault(option?.textChecked, "options/yes")
      textUnchecked = locOrDefault(option?.textUnchecked, "options/no")
      funcName = option?.funcName
      isDelayed = option?.delayed ?? false
      hotkey = HOTKEY_BY_BTN_NAME?[option?.shortcut]
    }
  }
}


let toSysoptItem = @(fields) fields.map(@(v, k) k != "items" || v == null ? v
  : mkComboItems(v).map(@(item) item.__merge({ text = removeTextareaTags(item.text) })))


let sysoptView = {
  function showSections(sections, items, errorText = null) {
    optionsScreen.mutate(@(s) s.__update({
      rows = []
      extraRows = null
      sysopt = { sections, errorText, curTab = 0, changedTabIds = {} }
    }))
    optionsItems.mutate(@(v) v.__update(items.map(toSysoptItem)))
  }

  function setItem(id, fields) {
    foreach (field, value in toSysoptItem(fields))
      setOptionsItem(id, field, value)
  }
}

function getOptionsWndOpenParams(group, initOptionId = "") {
  if (isInFlight())
    initOptions()

  let options = optionsListModule.getOptionsList()
  if (group != null)
    foreach (o in options)
      if (o.name == group)
        o.selected <- true

  return {
    titleText = isInFlight()
      ? is_multiplayer() ? null : loc("flightmenu/title")
      : loc("mainmenu/btnGameplay")
    optGroups = options
    initOptionId
    wndOptionsMode = OPTIONS_MODE_GAMEPLAY
  }
}

function openOptionsWnd(group = null, initOptionId = "") {
  return handlersManager.loadHandler(get_gui_handler("Options"), { group, initOptionId })
}

let Options = class (GenericOptionsModal) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/options/optionsDargShell.blk"
  sceneNavBlkName = null

  optGroups = null
  curGroup = -1
  echoTest = false
  needMoveMouseOnButtonApply = false

  filterText = ""

  getOptionInfoViewFn = null
  lastHoveredRowId = null
  selectedRowId = null

  initOptionId = ""
  curTabUnitType = ""

  constructor(gui_scene, params = {}) {
    base.constructor(gui_scene, getOptionsWndOpenParams(params?.group, params?.initOptionId ?? ""))
  }

  getWidgetsList = @() [{ widgetId = DargWidgets.SCREEN, screen = "options" }]

  function initScreen() {
    resetOptionsScreen()
    if (!this.optGroups)
      base.goBack()

    base.initScreen()
    setBreadcrumbGoBackParams(this)
    setOptionsScreenField("backSceneName", getBackSceneName())

    local curOption = 0
    foreach (idx, gr in this.optGroups)
      if (gr?.selected == true)
        curOption = idx
    setOptionsScreenField("tabs", this.optGroups.map(@(gr) {
      id = gr.name
      text = loc($"options/{gr.name}")
      visualDisable = gr.name == "voicechat" && !isCrossNetworkChatEnabled()
    }))
    this.selectGroup(curOption)

    let showWebUI = isPC && isInFlight() && (webui?.get_port() ?? 0) != 0
    let showAssistantMapQr = isAssistantMapEnabled() && isAssistantMapAvailable()
    this.showSceneItem("web_ui_button", showWebUI)
    this.showSceneItem("assistant_map_qr_button", showAssistantMapQr)
    this.selectOptionOnInit()
  }

  getSelectedGroup = @() optionsScreen.get().curTab

  function selectOptionOnInit() {
    if (this.initOptionId == "")
      return

    let containerName = this.currentContainerName
    let container = this.optionsContainers.findvalue(@(c) c.name == containerName)
    if (container == null || !this.isOptionsContainerShown(container))
      return

    let initOptId = this.initOptionId
    let option = this.getCurrentOptionsList().findvalue(@(opt) opt.id == initOptId)
    if (option == null)
      return

    let currentHeader = this.getOptionHeader(option)
    if (currentHeader == null)
      return

    foreach (navItem in this.getNavItems())
      if (navItem.id == currentHeader.id) {
        this.setCurrentNavItem(navItem)
        this.doNavigateToSection(navItem)
        return
      }
  }

  function selectGroup(newGroup) {
    setOptionsScreenField("curTab", newGroup)
    if (this.curGroup == newGroup && !(newGroup in this.optGroups))
      return

    this.showOptionInfo(null)
    this.lastHoveredRowId = null
    this.curTabUnitType = ""

    this.setNavItems([])

    if (this.curGroup >= 0) {
      this.applyFunc = function(optionsHandler) {
        optionsHandler.fillOptions(newGroup)
        optionsHandler.applyFunc = null
      }
      this.applyOptions()
    }
    else
      this.fillOptions(newGroup)

    let groupName = this.optGroups[newGroup].name
    this.setupSearch()
    this.joinEchoChannel(false)
    handlersManager.setLastBaseHandlerStartParams({ eventbusName = "gui_start_options", params = { group = groupName } })
  }

  function fillOptions(group) {
    let config = this.optGroups[group]

    this.getOptionInfoViewFn = config?.getOptionInfoView

    if ("fillFuncName" in config) {
      this.curGroup = group
      this[config.fillFuncName](group)
      this.updateOptionsListStyle(group)
      return;
    }

    this.fillOptionsList(group)
    this.updateLinkedOptions()
  }

  function updateOptionsListStyle(group) {
    setOptionsScreenField("isInfoOnTheRight", this.optGroups[group]?.isInfoOnTheRight ?? false)
  }

  function fillInternetRadioOptions(group) {
    this.fillOptionsList(group)

    let hotkeyOpts = [
      {
        shortcutTextareaId = "internet_radio_shortcut"
        optionText = "#options/internet_radio_shortcut"
        tip = "#guiHints/internet_radio_shortcut"
        shortcutText = this.getShortcutText("ID_INTERNET_RADIO")
        onAssignFnName = "onAssignInternetRadioButton"
        onResetFnName = "onClearInternetRadioButton"
      }
      {
        shortcutTextareaId = "internet_radio_prev_shortcut"
        optionText = "#options/internet_radio_prev_shortcut"
        tip = "#guiHints/internet_radio_prev_shortcut"
        shortcutText = this.getShortcutText("ID_INTERNET_RADIO_PREV")
        onAssignFnName = "onAssignInternetRadioPrevButton"
        onResetFnName = "onClearInternetRadioPrevButton"
      }
      {
        shortcutTextareaId = "internet_radio_next_shortcut"
        optionText = "#options/internet_radio_next_shortcut"
        tip = "#guiHints/internet_radio_next_shortcut"
        shortcutText = this.getShortcutText("ID_INTERNET_RADIO_NEXT")
        onAssignFnName = "onAssignInternetRadioNextButton"
        onResetFnName = "onClearInternetRadioNextButton"
      }
    ]

    this.showInternetRadioRows(hotkeyOpts)
    this.updateInternerRadioButtons()
  }

  function showInternetRadioRows(hotkeyOpts) {
    foreach (opt in hotkeyOpts)
      setOptionsItem(opt.shortcutTextareaId, "value", opt.shortcutText)
    setOptionsScreenField("extraRows", { kind = "radio", hotkeyOpts = hotkeyOpts.map(locHotkeyOpt) })
  }

  function setupSearch() {
    this.showSceneItem("search_container", this.isSearchInCurrentGroupAvaliable())
    this.resetSearch()
  }

  function isSearchInCurrentGroupAvaliable() {
    return this.optGroups[this.curGroup]?.isSearchAvaliable
  }

  function onFilterEditBoxCancel(_obj = null) {
    if ((this.getSearchText() ?? "") != "")
      this.resetSearch()
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.goBack()
      })
  }

  getSearchText = @() optionsScreen.get().searchText

  function setSearchText(text) {
    setOptionsScreenField("searchText", text)
    this.applySearchFilter()
  }

  function applySearchFilter() {
    let searchText = this.getSearchText()
    if (searchText == null)
      return

    this.filterText = utf8ToLower(searchText)

    if (! this.filterText.len()) {
      this.showOptionsSelectedNavigation()
      this.showSceneItem("filter_notify", false)
      return
    }

    let searchResultOptions = []
    let visibleHeadersArray = {}
    local needShowSearchNotify = false
    foreach (option in this.getCurrentOptionsList()) {
      local show = utf8ToLower(option.getTitle()).indexof(this.filterText) != null
      needShowSearchNotify = needShowSearchNotify
        || (show && searchResultOptions.len() >= MAX_NUM_VISIBLE_FILTER_OPTIONS)
      show = show && !needShowSearchNotify

      this.setOptionRowShown(option, show)

      if (!show)
        continue

      searchResultOptions.append(option)
      if (option.controlType == optionControlType.HEADER) {
        visibleHeadersArray[option.id] <- true
        continue
      }

      let header = this.getOptionHeader(option)
      if (header == null || (visibleHeadersArray?[header.id] ?? false))
        continue

      searchResultOptions.append(header)
      visibleHeadersArray[header.id] <- true
      this.setOptionRowShown(header, true)
    }

    this.showSceneItem("filter_notify", needShowSearchNotify)
    if (needShowSearchNotify)
      this.setSceneItemValue("filter_notify", loc("menu/options/maxNumFilterOptions",
        { num = MAX_NUM_VISIBLE_FILTER_OPTIONS }))
  }

  function resetSearch() {
    setOptionsScreenField("searchText", "")
    this.applySearchFilter()
  }

  initNavigation = @() null
  getNavItems = @() optionsScreen.get().navItems

  function setNavItems(items) {
    setOptionsScreenField("navItems", items)
    setOptionsScreenField("curNavIdx", 0)
  }

  getCurrentNavItem = @() optionsScreen.get().navItems?[optionsScreen.get().curNavIdx]

  function setCurrentNavItem(item) {
    let idx = optionsScreen.get().navItems.indexof(item)
    if (idx != null)
      setOptionsScreenField("curNavIdx", idx)
  }

  function onNavItem(idx) {
    let item = optionsScreen.get().navItems?[idx]
    if (item == null)
      return
    setOptionsScreenField("curNavIdx", idx)
    this.doNavigateToSection(item)
  }

  function doNavigateToSection(_navItem) {
    this.resetSearch()
    this.showOptionsSelectedNavigation()
  }

  function showOptionRow(id, show) {
    this.resetSearch()
    base.showOptionRow(id, show)
  }

  showSceneItem = @(id, show) setOptionsItem(id, "shown", show)
  enableSceneItem = @(id, isEnabled) setOptionsItem(id, "enabled", isEnabled)
  setSceneItemValue = @(id, value) setOptionsItem(id, "value", value)

  function setOptionsGroupInactive(groupId, isInactive) {
    optionsScreen.mutate(@(s) s.inactiveTabs = s.inactiveTabs.__merge({ [groupId] = isInactive }))
  }

  hasRow = @(id) optionsScreen.get().rows.findvalue(@(r) r.itemId == id) != null

  setOptionRowShown = @(option, show) setOptionsItem(option.id, "shown", show)
  enableOptionRow = @(option, status) setOptionsItem(option.id, "enabled", status)
  getOptionControlValue = @(option) this.hasRow(option.id) ? getOptionsItem(option.id)?.value : null
  isOptionsContainerShown = @(container) container.name == this.currentContainerName

  function updateOptionImpl(option) {
    if (!this.hasRow(option.id))
      return
    this.isOptionInUpdate = true
    if (option.controlType == optionControlType.LIST) {
      setOptionsItem(option.id, "items", mkComboItems(option?.items))
      setOptionsItem(option.id, "value", option.value)
    }
    else
      this.setControlValue(option.id, option.value)
    this.isOptionInUpdate = false
  }

  updateOptionValueText = @(option, value)
    setOptionsItem(option.id, "valueText", option.getValueLocText(value))

  getControlValue = @(id) getOptionsItem(id)?.value

  
  function setControlValue(id, value) {
    if (getOptionsItem(id)?.value == value)
      return
    setOptionsItem(id, "value", value)
    this[id.startswith("sysopt_") ? "onSystemOptionChanged" : "onChangeOptionValue"](mkControlObj(this, id))
  }

  function callWndFunc(funcName, isDelayed) {
    let isOptionButton = this.getCurrentOptionsList().findvalue(@(o) o?.funcName == funcName) != null
      || (optionsScreen.get()?.sysopt?.sections ?? [])
        .findvalue(@(s) s.rows.findvalue(@(r) r.control?.funcName == funcName) != null) != null
    if (!isOptionButton && !WND_CALLS.contains(funcName))
      return
    let fn = this[funcName]
    
    let { parameters = null } = fn.getfuncinfos()
    let args = parameters?.len() == 1 ? [this] : [this, null]
    if (!isDelayed)
      return fn.acall(args)
    defer(function() {
      if (this.isValid())
        fn.acall(args)
    }.bindenv(this))
  }

  function onRowSelect(trId) {
    this.selectedRowId = trId
    this.onTblSelect(null)
  }

  function getSelectedOption() {
    let selectedRowId = this.selectedRowId
    return this.getCurrentOptionsList()
      .findvalue(@(o) o.controlType != optionControlType.HEADER && o.getTrId() == selectedRowId)
  }

  function getShortcutText(shortcut_id_name) {
    let shortcut = getShortcuts([shortcut_id_name])
    let data = getShortcutText({ shortcuts = shortcut, shortcutId = 0, colored = false })
    return data == "" ? "---" : data
}

  function bindShortcutButton(devs, btns, activationType, shortcut_id_name, shortcut_object_name) {
    let shortcut = getShortcuts([shortcut_id_name]);

    let event = shortcut[0];

    event.append({ dev = devs, btn = btns, activationType })
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    let data = getShortcutText({ shortcuts = shortcut, shortcutId = 0, colored = false })
    this.setSceneItemValue(shortcut_object_name, data)
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name) {
    let shortcut = getShortcuts([shortcut_id_name]);

    shortcut[0] = [];

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    this.setSceneItemValue(shortcut_object_name, "---")
  }

  function onAssignInternetRadioButton() {
    openAssignShortcut(this, this.bindInternetRadioButton, "ID_INTERNET_RADIO")
  }
  function bindInternetRadioButton(devs, btns, activationType) {
    this.bindShortcutButton(devs, btns, activationType, "ID_INTERNET_RADIO", "internet_radio_shortcut")
  }
  function onClearInternetRadioButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onAssignInternetRadioPrevButton() {
    openAssignShortcut(this, this.bindInternetRadioPrevButton, "ID_INTERNET_RADIO_PREV")
  }
  function bindInternetRadioPrevButton(devs, btns, activationType) {
    this.bindShortcutButton(devs, btns, activationType, "ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut")
  }
  function onClearInternetRadioPrevButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onAssignInternetRadioNextButton() {
    openAssignShortcut(this, this.bindInternetRadioNextButton, "ID_INTERNET_RADIO_NEXT")
  }
  function bindInternetRadioNextButton(devs, btns, activationType) {
    this.bindShortcutButton(devs, btns, activationType, "ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut")
  }
  function onClearInternetRadioNextButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function fillSoundOptions(group) {
    this.fillOptionsList(group)

    if (!chatStatesCanUseVoice())
      return

    let needShowOptions = isCrossNetworkChatEnabled() || isXbox
    let hotkeyOpts = needShowOptions ? {
      shortcutTextareaId = "ptt_shortcut"
      optRowId = "ptt_buttons_block"
      optionText = "#options/ptt_shortcut"
      tip = "#guiHints/ptt_shortcut"
      resetTip = "#guiHints/ptt_shortcut_reset"
      onAssignFnName = "onAssignVoiceButton"
      onResetFnName = "onClearVoiceButton"
      shortcutText = this.getPttShortcutText()
    } : null

    this.showVoiceChatRows(needShowOptions, hotkeyOpts)
    if (needShowOptions)
      this.showSceneItem("ptt_buttons_block", get_option(USEROPT_PTT).value)
  }

  function showVoiceChatRows(needShowOptions, hotkeyOpts) {
    if (hotkeyOpts != null)
      setOptionsItem(hotkeyOpts.shortcutTextareaId, "value", hotkeyOpts.shortcutText)
    setOptionsItem("joinEchoButton", "value", loc("options/joinEcho"))
    setOptionsItem("joinEchoButton", "tooltip", loc("guiHints/joinEcho"))
    setOptionsScreenField("extraRows", { kind = "voice", needShowOptions,
      hotkeyOpts = hotkeyOpts == null ? null : locHotkeyOpt(hotkeyOpts) })
  }

  function getPttShortcutText() {
    let ptt_shortcut = getShortcuts(["ID_PTT"]);
    let pttShortcutText = getShortcutText({ shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false, colored = false });
    return pttShortcutText == ""
      ? "---"
      : hackTextAssignmentForR2buttonOnPS4(pttShortcutText)
  }

  function onAssignVoiceButton() {
    openAssignShortcut(this, this.bindVoiceButton, "ID_PTT")
  }

  function bindVoiceButton(devs, btns, activationType) {
    let ptt_shortcut = getShortcuts(["ID_PTT"]);

    let event = ptt_shortcut[0];

    event.append({ dev = devs, btn = btns, activationType })
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(ptt_shortcut, ["ID_PTT"]);
    this.save(false);
    this.setSceneItemValue("ptt_shortcut", this.getPttShortcutText())
  }

  function onClearVoiceButton() {
    this.onClearShortcutButton("ID_PTT", "ptt_shortcut")
  }

  function joinEchoChannel(join) {
    this.echoTest = join;
    gchat_voice_echo_test(join);
  }

  function onEchoTestButton() {
    this.joinEchoChannel(!this.echoTest);
    this.setSceneItemValue("joinEchoButton", this.echoTest ? loc("options/leaveEcho") : loc("options/joinEcho"))
    setOptionsItem("joinEchoButton", "tooltip", this.echoTest ? loc("guiHints/leaveEcho") : loc("guiHints/joinEcho"))
  }

  function fillSystemOptions(_group) {
    this.optionsContainers = [{ name = "options_systemOptions", data = [] }]
    this.curTabUnitType = ""
    fillSystemGuiOptions(this, sysoptView)
  }

  function onSystemOptionChanged(obj) {
    onSystemGuiOptionChanged(obj)
    if (obj?.id != null)
      this.updateChangedTabIcons(getOptionIdByObjId(obj.id))
  }

  function onSystemOptionsRestartClient(_obj) {
    this.applyOptions()
    onRestartClient()
  }

  function onSystemOptionsReset(_obj) {
    resetSystemGuiOptions()
  }

  function onSystemOptionsResetTab(_obj) {
    let titles = getActiveTabDiffSectionTitles()
    if (titles.len() == 0)
      return

    let groupsList = ", ".join(titles.map(@(t) colorize("userlogColoredText", loc(t))))
    scene_msg_box("ask_reset_tab_values", null,
      loc("msgbox/ask_reset_tab_values", {groupsList}),
      [
        ["ok", @() resetSystemActiveTabDiffs()],
        ["cancel", @() null]
      ],
      "no", { cancel_fn = @() null })
  }

  function selectUnitTypeTab(tabIdx, unitTypeTag) {
    let { sysopt = null } = optionsScreen.get()
    if (sysopt == null || sysopt.curTab == tabIdx)
      return
    this.curTabUnitType = unitTypeTag
    setOptionsScreenField("sysopt", sysopt.__merge({ curTab = tabIdx }))
    foreach (section in sysopt.sections)
      if (section.tabs != null)
        updateGuiOptionsGroup(section.sectionIdx, tabIdx == 0, unitTypeTag)
  }

  function onUnitTypeTab(tabIdx) {
    let tabs = optionsScreen.get()?.sysopt?.sections.findvalue(@(s) s.tabs != null)?.tabs
    if (tabs?[tabIdx] != null)
      this.selectUnitTypeTab(tabIdx, tabs[tabIdx].unitTypeTag)
  }

  showOptionInfo = @(view) setOptionsScreenField("info", view == null ? null
    : { title = locText(view?.title), description = resolveColorTags(locText(view?.description)),
        imageSrc = view?.imageSrc })

  function onOptionRowHover(rowId) {
    if (rowId == this.lastHoveredRowId)
      return
    let id = rowId.split("_tr")[0]
    let opt = this.get_option_by_id(id)
    let view = this.getOptionInfoViewFn?(id)
      ?? {
            title = opt?.title ?? opt?.text ?? loc($"options/{id}")
            description = opt?.hint ?? loc($"guiHints/{id}", "")
         }
    this.showOptionInfo(view)
    this.lastHoveredRowId = rowId
    this.updateChangedTabIcons(id)
  }


  function setOptionInfoImage(src) {
    let { info } = optionsScreen.get()
    if (info != null)
      setOptionsScreenField("info", info.__merge({ imageSrc = src }))
  }

  function updateChangedTabIcons(optionId) {
    let { sysopt = null } = optionsScreen.get()
    if (sysopt == null || !hasFeature("HasTabsInGraphicsOption"))
      return
    let sectionTitle = getOptionSectionTitle(optionId)
    let changedTabIds = {}
    if (sectionTitle != null)
      foreach (tag, isChanged in getOptionDiffTags(optionId))
        if (isChanged)
          changedTabIds[$"{sectionTitle}_{tag}"] <- true
    setOptionsScreenField("sysopt", sysopt.__merge({ changedTabIds }))
  }

  function fillOptionsList(group) {
    this.curGroup = group
    let config = this.optGroups[group]

    if ("options" not in config)
      return

    this.currentContainerName =$"options_{config.name}"
    let ratio = config?.isInfoOnTheRight ? 0.55 : 0.5
    this.showOptionsList(config.options, ratio)
    this.updateOptionsListStyle(group)
    if (config?.showNav) {
      this.setNavigationItems()
      this.showOptionsSelectedNavigation()
    }
    this.updateNavbar()
  }

  function showOptionsList(options, columnsRatio) {
    let rows = getOptionsRows(options)
    this.optionsContainers = [{ name = this.currentContainerName, data = rows }]
    let items = {}
    foreach (option in rows)
      items[option.id] <- {
        shown = true
        enabled = option?.enabled ?? true
        value = option.controlType == optionControlType.BUTTON ? locText(option?.text) : option.value
        valueText = option.needShowValueText ? option.getValueLocText(option.value) : null
        items = controlKind(option) == "combobox" ? mkComboItems(option?.items) : null
      }
    this.selectedRowId = null
    optionsScreen.mutate(@(s) s.__update({
      rows = rows.map(mkRowView)
      columnsRatio
      sysopt = null
      extraRows = null
    }))
    optionsItems.mutate(@(v) v.__update(items))
  }

  function showOptionsSelectedNavigation() {
    let currentHeaderId = this.getCurrentNavItem()?.id
    if (currentHeaderId == null)
      return

    local isCurrentSection = false
    foreach (option in this.getCurrentOptionsList()) {
      if (option.controlType == optionControlType.HEADER) {
        isCurrentSection = currentHeaderId == option.id
        this.setOptionRowShown(option, false)
        continue
      }

      this.setOptionRowShown(option, isCurrentSection)
    }
  }

  function onOpenGpuBenchmark() {
    showGpuBenchmarkWnd(this.curTabUnitType)
  }
  onPreloaderSettings = @() preloaderOptionsModal()
  onTankSightSettings = openTankSightSettings
  onDialogAddRadio = @() openAddRadioWnd()
  onShipHitIconsVisibilityClick = openShipHitIconsMenu

  function onPostFxSettings(_obj) {
    this.applyFunc = @(_) guiStartPostfxSettings()
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onHdrSettings(_obj) {
    this.applyFunc = @(_) fxOptions.openHdrSettings()
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onWebUiMap() {
    if ((webui?.get_port() ?? 0) == 0)
      return

    webui.launch_browser()
  }

  function onAssistantMapQrCode() {
    guiStartAssistantMapQrWindow()
  }

  function fullReloadScene() {
    this.doApply()
    base.fullReloadScene()
  }

  function doApply() {
    this.joinEchoChannel(false);
    stop_test_headphones_sound();
    let result = base.doApply();

    let group = this.curGroup == -1 ? null : this.optGroups[this.curGroup];
    if (group && ("onApplyHandler" in group) && group.onApplyHandler)
      group.onApplyHandler();

    return result;
  }

  function onDialogEditRadio() {
    let radio = get_internet_radio_options()
    if (!radio)
      return this.updateInternerRadioButtons()

    openAddRadioWnd(radio?.station ?? "")
  }

  function onRemoveRadio() {
    let radio = get_internet_radio_options()
    if (!radio)
      return this.updateInternerRadioButtons()
    let nameRadio = radio?.station
    if (!nameRadio)
      return
    this.msgBox("warning",
      format(loc("options/msg_remove_radio"), nameRadio),
      [
        ["ok", function() {
          remove_internet_radio_station(nameRadio);
          broadcastEvent("UpdateListRadio", {})
        }],
        ["cancel", function() {}]
      ], "ok")
  }

  function onEventUpdateListRadio(_params) {
    let group = this.getSelectedGroup()
    if (group == null)
      return
    this.fillInternetRadioOptions(group)
    this.updateInternerRadioButtons()
  }

  function updateInternerRadioButtons() {
    let radio = get_internet_radio_options()
    let isEnable = radio?.station ? is_internet_radio_station_removable(radio.station) : false
    this.enableSceneItem("btn_edit_radio", isEnable)
    this.enableSceneItem("btn_remove_radio", isEnable)
  }

  function onRevealNotifications() {
    scene_msg_box("ask_reveal_notifications",
      null,
      loc("mainmenu/btnRevealNotifications/askPlayer"),
      [
        ["yes", Callback(this.resetNotifications, this)],
        ["no", @() null]
      ],
      "yes", { cancel_fn = @() null })
  }

  function resetNotifications() {
    set_gui_option(USEROPT_SKIP_WEAPON_WARNING, false)

    saveLocalAccountSettings("skipped_msg", null)
    resetTutorialSkip()
    broadcastEvent("ResetSkipedNotifications")

    
    
    addPopup("", loc("mainmenu/btnRevealNotifications/onSuccess"))
  }

  function resetVolumes() {
    reset_volumes()
    this.fillSoundOptions(this.curGroup)
  }

  function testHeadphones() {
    if (!this.isValid() || !this.hasRow("sound_test_headphones"))
      return
    let isPlaying = toggle_test_headphones_sound()
    this.setSceneItemValue("sound_test_headphones",
      isPlaying ? loc("options/stopTestHeadphones") : loc("options/playTestHeadphones"))
  }

  function isRestartPending() {
    foreach (container in this.optionsContainers) {
      foreach (option in container.data) {
        if (!option.needRestartClient)
          continue
        let value = this.getOptionControlValue(option)
        if (value != null && isOptionReqRestartChanged(option, value))
          return true
      }
    }
    return false
  }

  function updateNavbar() {
    let group = this.optGroups?[this.curGroup]
    if (group == null)
      return

    let showRestartText = this.isRestartPending()
    this.showSceneItem("restart_suggestion", showRestartText)
    this.showSceneItem("btn_restart", showRestartText && canRestartClient())
  }

  function onChangeOptionValue(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    if (option.needRestartClient) {
      setOptionReqRestartValue(option)
      this.updateNavbar()
    }

    if (option.optionCb != null)
      this[option.optionCb](obj)
  }
}
register_gui_handler("Options", Options)

subscribeScreenActions("optionsScreen.action", Options, {
  changeValue = @(h, p) h.setControlValue(p.id, p.value)
  selectTab = @(h, p) h.selectGroup(p.idx)
  selectNav = @(h, p) h.onNavItem(p.idx)
  search = @(h, p) h.setSearchText(p.text)
  searchCancel = @(h, _) h.onFilterEditBoxCancel()
  hoverRow = @(h, p) h.onOptionRowHover(p.trId)
  selectRow = @(h, p) h.onRowSelect(p.trId)
  call = @(h, p) h.callWndFunc(p.funcName, p?.isDelayed ?? true)
  sysoptTab = @(h, p) h.onUnitTypeTab(p.idx)
  sysoptValueHover = @(_h, p) onSystemOptionValueHover(p.optId, p.idx)
})

addPromoAction("options", @(_handler, params, _obj) openOptionsWnd(params?[0], params?[1] ?? ""))

addListenersWithoutEnv({
  showOptionsWnd = @(p) openOptionsWnd(p?.group)
})

eventbus_subscribe("gui_start_options", @(p) openOptionsWnd(p?.group))

return freeze({
  openOptionsWnd
})
