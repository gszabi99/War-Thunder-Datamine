from "%scripts/dagui_natives.nut" import get_option_gamma, is_internet_radio_station_removable, remove_internet_radio_station, get_internet_radio_options, set_option_gamma, gchat_voice_echo_test, get_cur_gui_scene
from "%scripts/dagui_library.nut" import *
from "%scripts/controls/controlsConsts.nut" import optionControlType
from "%scripts/utils_sa.nut" import is_multiplayer

let { isPC } = require("%sqstd/platform.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { broadcastEvent, addListenersWithoutEnv } = require("%sqStdLibs/helpers/subscriptions.nut")
let { saveLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { set_gui_option } = require("guiOptions")
let optionsListModule = require("%scripts/options/optionsList.nut")
let { isCrossNetworkChatEnabled } = require("%scripts/social/crossplay.nut")
let { fillSystemGuiOptions, resetSystemGuiOptions, onSystemGuiOptionChanged, onRestartClient,
  onSystemOptionControlHover } = require("%scripts/options/systemOptions.nut")
let fxOptions = require("%scripts/options/fxOptions.nut")
let { openAddRadioWnd } = require("%scripts/options/handlers/addRadioWnd.nut")
let preloaderOptionsModal = require("%scripts/options/handlers/preloaderOptionsModal.nut")
let openTankSightSettings = require("%scripts/options/handlers/tankSightSettings.nut")
let { isPlatformXbox } = require("%scripts/clientState/platform.nut")
let { resetTutorialSkip } = require("%scripts/tutorials/tutorialsState.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { SND_NUM_TYPES, get_sound_volume, set_sound_volume, reset_volumes } = require("soundOptions")
let { showGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")
let { canRestartClient } = require("%scripts/utils/restartClient.nut")
let { isOptionReqRestartChanged, setOptionReqRestartValue
} = require("%scripts/options/optionsUtils.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { setShortcutsAndSaveControls, getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PTT, USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")
let { isInFlight } = require("gameplayBinding")
let { create_options_container, get_option } = require("%scripts/options/optionsExt.nut")
let { guiStartPostfxSettings } = require("%scripts/postFxSettings.nut")
let { addPopup } = require("%scripts/popups/popups.nut")
let { chatStatesCanUseVoice } = require("%scripts/chat/chatStates.nut")
let { setTimeout, clearTimer, defer } = require("dagor.workcycle")
let { assignButtonWindow } = require("%scripts/controls/assignButtonWnd.nut")
let { openShipHitIconsMenu } = require("%scripts/options/handlers/shipHitIconsMenu.nut")
let { getShortcutText, hackTextAssignmentForR2buttonOnPS4 } = require("%scripts/controls/controlsVisual.nut")
let { addPromoAction } = require("%scripts/promo/promoActions.nut")
let { initOptions } = require("%scripts/options/initOptions.nut")

let getNavigationImagesText = require("%scripts/utils/getNavigationImagesText.nut")

const DELAY_BEFORE_PRELOAD_HOVERED_OPT_IMAGES_SEC = 0.25
const MAX_NUM_VISIBLE_FILTER_OPTIONS = 25

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
    sceneNavBlkName = "%gui/options/navOptionsIngame.blk"
    function cancelFunc() {
      set_option_gamma(get_option_gamma(), false)
      for (local i = 0; i < SND_NUM_TYPES; i++)
        set_sound_volume(i, get_sound_volume(i), false)
    }
  }
}

function openOptionsWnd(group = null, initOptionId = "") {
  return handlersManager.loadHandler(gui_handlers.Options, getOptionsWndOpenParams(group, initOptionId))
}

gui_handlers.Options <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/options/optionsWnd.blk"
  sceneNavBlkName = "%gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false
  needMoveMouseOnButtonApply = false

  filterText = ""

  getOptionInfoViewFn = null
  lastHoveredRowId = null

  preloadOptionsImgTimer = null
  initOptionId = ""

  function initScreen() {
    if (!this.optGroups)
      base.goBack()

    base.initScreen()
    setBreadcrumbGoBackParams(this)

    let view = { tabs = [] }
    local curOption = 0
    foreach (idx, gr in this.optGroups) {
      view.tabs.append({
        id = gr.name
        visualDisable = gr.name == "voicechat" && !isCrossNetworkChatEnabled()
        tabName =$"#options/{gr.name}"
        navImagesText = getNavigationImagesText(idx, this.optGroups.len())
      })

      if (getTblValue("selected", gr) == true)
        curOption = idx
    }

    let data = handyman.renderCached("%gui/frameHeaderTabs.tpl", view)
    let groupsObj = this.scene.findObject("groups_list")
    this.optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(groupsObj, data, data.len(), this)
    groupsObj.show(true)
    groupsObj.setValue(curOption)

    let showWebUI = isPC && isInFlight() && ::WebUI.get_port() != 0
    showObjById("web_ui_button", showWebUI, this.scene)
    this.selectOptionOnInit()
  }

  function selectOptionOnInit() {
    if (this.initOptionId == "")
      return

    let objTbl = this.scene.findObject(this.currentContainerName)
    if (!objTbl?.isValid())
      return

    let initOptId = this.initOptionId
    let option = this.getCurrentOptionsList().findvalue(@(opt) opt.id == initOptId)
    if (option == null)
      return

    let currentHeader = this.getOptionHeader(option)
    if (currentHeader == null)
      return

    let navItems = this.navigationHandlerWeak?.getNavItems() ?? []
    foreach (navItem in navItems)
      if (navItem.id == currentHeader.id) {
        this.navigationHandlerWeak.setCurrentItem(navItem)
        this.doNavigateToSection(navItem)
        return
      }
  }

  function onDestroy() {
    clearTimer(this.preloadOptionsImgTimer)
    defer(@() get_cur_gui_scene().discardUnusedPicture())
  }

  function onGroupSelect(obj) {
    if (!obj)
      return

    let newGroup = obj.getValue()
    if (this.curGroup == newGroup && !(newGroup in this.optGroups))
      return

    this.scene.findObject("option_info_container").show(false)
    this.lastHoveredRowId = null
    clearTimer(this.preloadOptionsImgTimer)

    this.resetNavigation()

    if (this.curGroup >= 0) {
      this.applyFunc = function() {
        this.fillOptions(newGroup)
        this.applyFunc = null
      }
      this.applyOptions()
    }
    else
      this.fillOptions(newGroup)

    let groupName = this.optGroups[newGroup].name
    this.setupSearch()
    this.joinEchoChannel(false)
    handlersManager.setLastBaseHandlerStartParams({ handlerName = "Options", params = getOptionsWndOpenParams(groupName) })
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
    let { isInfoOnTheRight = false } = this.optGroups[group]
    let optsListObj = this.scene.findObject("optionslist")
    optsListObj.alignMode = isInfoOnTheRight ? "left" : "center"
    optsListObj.width = isInfoOnTheRight ? "0.45pw" : "pw"
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

    let markup = handyman.renderCached("%gui/options/internetRadioOptions.tpl", { hotkeyOpts })
    this.guiScene.appendWithBlk(this.scene.findObject(this.currentContainerName), markup, this);
    this.updateInternerRadioButtons()
  }

  function fillSocialOptions(_group) {
    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/socialOptions.blk", this)
  }

  function setupSearch() {
    showObjById("search_container", this.isSearchInCurrentGroupAvaliable(), this.scene)
    this.resetSearch()
  }

  function isSearchInCurrentGroupAvaliable() {
    return getTblValue("isSearchAvaliable", this.optGroups[this.curGroup])
  }

  function onFilterEditBoxChangeValue() {
    this.applySearchFilter()
  }

  function onFilterEditBoxCancel(obj = null) {
    if ((obj?.getValue() ?? "") != "")
      this.resetSearch()
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.goBack()
      })
  }

  function applySearchFilter() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (!checkObj(filterEditBox))
      return

    this.filterText = utf8ToLower(filterEditBox.getValue())

    if (! this.filterText.len()) {
      this.showOptionsSelectedNavigation()
      showObjById("filter_notify", false, this.scene)
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

      base.showOptionRow(option, show)

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
      base.showOptionRow(header, true)
    }

    let filterNotifyObj = showObjById("filter_notify", needShowSearchNotify, this.scene)
    if (needShowSearchNotify && filterNotifyObj != null)
      filterNotifyObj.setValue(loc("menu/options/maxNumFilterOptions",
        { num = MAX_NUM_VISIBLE_FILTER_OPTIONS }))
  }

  function resetSearch() {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (! checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function doNavigateToSection(_navItem) {
    this.resetSearch()
    this.showOptionsSelectedNavigation()
  }

  function showOptionRow(id, show) {
    this.resetSearch()
    base.showOptionRow(id, show)
  }

  function getShortcutText(shortcut_id_name) {
    let shortcut = getShortcuts([shortcut_id_name])
    let data = getShortcutText({ shortcuts = shortcut, shortcutId = 0 })
    return data == "" ? "---" : data
}

  function bindShortcutButton(devs, btns, shortcut_id_name, shortcut_object_name) {
    let shortcut = getShortcuts([shortcut_id_name]);

    let event = shortcut[0];

    event.append({ dev = devs, btn = btns });
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    let data = getShortcutText({ shortcuts = shortcut, shortcutId = 0 })
    this.scene.findObject(shortcut_object_name).setValue(data);
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name) {
    let shortcut = getShortcuts([shortcut_id_name]);

    shortcut[0] = [];

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    this.scene.findObject(shortcut_object_name).setValue("---");
  }

  function onAssignInternetRadioButton() {
    assignButtonWindow(this, this.bindInternetRadioButton);
  }
  function bindInternetRadioButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onClearInternetRadioButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onAssignInternetRadioPrevButton() {
    assignButtonWindow(this, this.bindInternetRadioPrevButton);
  }
  function bindInternetRadioPrevButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onClearInternetRadioPrevButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onAssignInternetRadioNextButton() {
    assignButtonWindow(this, this.bindInternetRadioNextButton);
  }
  function bindInternetRadioNextButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }
  function onClearInternetRadioNextButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function fillSoundOptions(group) {
    this.fillOptionsList(group)

    if (!chatStatesCanUseVoice())
      return

    let needShowOptions = isCrossNetworkChatEnabled() || isPlatformXbox
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

    let markup = handyman.renderCached("%gui/options/voicechatOptions.tpl", {
      needShowOptions, hotkeyOpts
    })
    this.guiScene.appendWithBlk(this.scene.findObject(this.currentContainerName), markup, this)
    if (needShowOptions)
      showObjById("ptt_buttons_block", get_option(USEROPT_PTT).value, this.scene)
  }

  function getPttShortcutText() {
    let ptt_shortcut = getShortcuts(["ID_PTT"]);
    let pttShortcutText = getShortcutText({ shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false });
    return pttShortcutText == ""
      ? "---"
      : $"<color=@hotkeyColor>{hackTextAssignmentForR2buttonOnPS4(pttShortcutText)}</color>"
  }

  function onAssignVoiceButton() {
    assignButtonWindow(this, this.bindVoiceButton);
  }

  function bindVoiceButton(devs, btns) {
    let ptt_shortcut = getShortcuts(["ID_PTT"]);

    let event = ptt_shortcut[0];

    event.append({ dev = devs, btn = btns });
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(ptt_shortcut, ["ID_PTT"]);
    this.save(false);

    local data = getShortcutText({ shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false })
    data = $"<color=@hotkeyColor>{hackTextAssignmentForR2buttonOnPS4(data)}</color>"
    this.scene.findObject("ptt_shortcut").setValue(data);
  }

  function onClearVoiceButton() {
    this.onClearShortcutButton("ID_PTT", "ptt_shortcut")
  }

  function joinEchoChannel(join) {
    this.echoTest = join;
    gchat_voice_echo_test(join);
  }

  function onEchoTestButton() {
    let echoButton = this.scene.findObject("joinEchoButton");

    this.joinEchoChannel(!this.echoTest);
    if (echoButton) {
      echoButton.setValue(this.echoTest ? loc("options/leaveEcho") : loc("options/joinEcho"))
      echoButton.tooltip = this.echoTest ? loc("guiHints/leaveEcho") : loc("guiHints/joinEcho")
    }
  }

  function fillSystemOptions(_group) {
    this.optionsContainers = [{ name = "options_systemOptions", data = [] }]
    fillSystemGuiOptions(this.scene.findObject("optionslist"), this)
  }

  function onSystemOptionChanged(obj) {
    onSystemGuiOptionChanged(obj)
  }

  function onSystemOptionsRestartClient(_obj) {
    this.applyOptions()
    onRestartClient()
  }

  function onSystemOptionsReset(_obj) {
    resetSystemGuiOptions()
  }

  function passValueToParent(obj) {
    if (!checkObj(obj))
      return
    let objParent = obj.getParent()
    if (!checkObj(objParent))
      return
    let val = obj.getValue()
    if (objParent.getValue() != val)
      objParent.setValue(val)
  }

  function onOptionContainerHover(obj) {
    if (!this.scene?.isValid() || !obj?.isValid() || obj?.disabled == "yes")
      return
    let id = obj.id.split("_tr")[0]
    let infoContainerObj = this.scene.findObject("option_info_container")
    if (!infoContainerObj?.isValid())
      return

    let opt = this.get_option_by_id(id)
    let view = this.getOptionInfoViewFn?(id)
      ?? {
            title = opt?.text ?? loc($"options/{id}")
            description = opt?.hint ?? loc($"guiHints/{id}", "")
         }
    let markup = handyman.renderCached("%gui/options/optionInfo.tpl", view)

    this.guiScene.replaceContentFromText(infoContainerObj, markup, markup.len(), this)
    infoContainerObj.show(true)

    if (this.lastHoveredRowId != null) {
      let lastHoveredRow = this.scene.findObject(this.lastHoveredRowId)
      if (lastHoveredRow?.isValid())
        lastHoveredRow.active="no"
    }
    obj.active = "yes"
    this.lastHoveredRowId = obj.id

    clearTimer(this.preloadOptionsImgTimer)
    if (view?.hasImages) {
      let cb = Callback(this.preloadOptionImages, this)
      this.preloadOptionsImgTimer =
        setTimeout(DELAY_BEFORE_PRELOAD_HOVERED_OPT_IMAGES_SEC, @() cb())
    }
  }

  function preloadOptionImages() {
    if (!this.scene?.isValid())
      return
    let container = this.scene.findObject("preloaded_images_container")
    if (!container?.isValid())
      return
    container.show(true)
  }

  onSystemOptionControlHover = @(obj) this.guiScene.performDelayed({}, 
    @() onSystemOptionControlHover(obj))

  function fillOptionsList(group) {
    this.curGroup = group
    let config = this.optGroups[group]

    if ("options" not in config)
      return

    if (this.optionsConfig == null)
      this.optionsConfig = {
        onTblClick = "onTblSelect"
        containerCb = "onChangeOptionValue"
      }

    this.optionsConfig.__update({
      onHoverFnName = config?.isInfoOnTheRight ? "onOptionContainerHover" : null
    })

    this.currentContainerName =$"options_{config.name}"
    let ratio = config?.isInfoOnTheRight ? 0.55 : 0.5
    let container = create_options_container(this.currentContainerName, config.options, true, ratio,
      true, this.optionsConfig)
    this.optionsContainers = [container.descr]

    this.guiScene.setUpdatesEnabled(false, false)
    this.optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(this.scene.findObject("optionsList"), container.tbl, container.tbl.len(), this)
    this.updateOptionsListStyle(group)
    if (config?.showNav) {
      this.setNavigationItems()
      this.showOptionsSelectedNavigation()
    }
    this.updateNavbar()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function showOptionsSelectedNavigation() {
    let currentHeaderId = this.navigationHandlerWeak?.getCurrentItem().id
    if (currentHeaderId == null)
      return

    local isCurrentSection = false
    foreach (option in this.getCurrentOptionsList()) {
      if (option.controlType == optionControlType.HEADER) {
        isCurrentSection = currentHeaderId == option.id
        base.showOptionRow(option, false)
        continue
      }

      base.showOptionRow(option, isCurrentSection)
    }
  }

  onOpenGpuBenchmark = showGpuBenchmarkWnd
  onPreloaderSettings = @() preloaderOptionsModal()
  onTankSightSettings = openTankSightSettings
  onDialogAddRadio = @() openAddRadioWnd()
  onShipHitIconsVisibilityClick = openShipHitIconsMenu

  function onPostFxSettings(_obj) {
    this.applyFunc = guiStartPostfxSettings
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onHdrSettings(_obj) {
    this.applyFunc = fxOptions.openHdrSettings
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onWebUiMap() {
    if (::WebUI.get_port() == 0)
      return

    ::WebUI.launch_browser()
  }

  function fullReloadScene() {
    this.doApply()
    base.fullReloadScene()
  }

  function doApply() {
    this.joinEchoChannel(false);
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
    let obj = this.scene.findObject("groups_list")
    if (!obj)
      return
    this.fillInternetRadioOptions(obj.getValue())
    this.updateInternerRadioButtons()
  }

  function updateInternerRadioButtons() {
    let radio = get_internet_radio_options()
    let isEnable = radio?.station ? is_internet_radio_station_removable(radio.station) : false
    let btnEditRadio = this.scene.findObject("btn_edit_radio")
    if (btnEditRadio)
      btnEditRadio.enable(isEnable)
    let btnRemoveRadio = this.scene.findObject("btn_remove_radio")
    if (btnRemoveRadio)
      btnRemoveRadio.enable(isEnable)
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

  function isRestartPending() {
    foreach (container in this.optionsContainers) {
      foreach (option in container.data) {
        if (!option.needRestartClient)
          continue
        let obj = this.scene.findObject(option.id)
        if (!(obj?.isValid() ?? false))
          continue

        if (isOptionReqRestartChanged(option, obj.getValue()))
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
    showObjById("restart_suggestion", showRestartText, this.scene)
    showObjById("btn_restart", showRestartText && canRestartClient(), this.scene)
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

addPromoAction("options", @(_handler, params, _obj) openOptionsWnd(params?[0], params?[1] ?? ""))

addListenersWithoutEnv({
  showOptionsWnd = @(p) openOptionsWnd(p?.group)
})

return {
  openOptionsWnd
}
