//-file:plus-string
from "%scripts/dagui_library.nut" import *

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
let { fillSystemGuiOptions, resetSystemGuiOptions, onSystemGuiOptionChanged, onRestartClient
  } = require("%scripts/options/systemOptions.nut")
let fxOptions = require("%scripts/options/fxOptions.nut")
let { openAddRadioWnd } = require("%scripts/options/handlers/addRadioWnd.nut")
let preloaderOptionsModal = require("%scripts/options/handlers/preloaderOptionsModal.nut")
let { isPlatformXboxOne } = require("%scripts/clientState/platform.nut")
let { resetTutorialSkip } = require("%scripts/tutorials/tutorialsData.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { SND_NUM_TYPES, get_sound_volume, set_sound_volume, reset_volumes } = require("soundOptions")
let { showGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")
let { canRestartClient } = require("%scripts/utils/restartClient.nut")
let { isOptionReqRestartChanged, setOptionReqRestartValue
} = require("%scripts/options/optionsUtils.nut")
let { utf8ToLower } = require("%sqstd/string.nut")
let { setShortcutsAndSaveControls } = require("%scripts/controls/controlsCompatibility.nut")
let { OPTIONS_MODE_GAMEPLAY, USEROPT_PTT, USEROPT_SKIP_LEFT_BULLETS_WARNING,
  USEROPT_SKIP_WEAPON_WARNING } = require("%scripts/options/optionsExtNames.nut")
let { isInFlight } = require("gameplayBinding")
let { create_options_container } = require("%scripts/options/optionsExt.nut")

const MAX_NUM_VISIBLE_FILTER_OPTIONS = 25

let function getOptionsWndOpenParams(group) {
  if (isInFlight())
    ::init_options()

  let options = optionsListModule.getOptionsList()
  if (group != null)
    foreach (o in options)
      if (o.name == group)
        o.selected <- true

  return {
    titleText = isInFlight()
      ? ::is_multiplayer() ? null : loc("flightmenu/title")
      : loc("mainmenu/btnGameplay")
    optGroups = options
    wndOptionsMode = OPTIONS_MODE_GAMEPLAY
    sceneNavBlkName = "%gui/options/navOptionsIngame.blk"
    function cancelFunc() {
      ::set_option_gamma(::get_option_gamma(), false)
      for (local i = 0; i < SND_NUM_TYPES; i++)
        set_sound_volume(i, get_sound_volume(i), false)
    }
  }
}

let function openOptionsWnd(group = null) {
  return handlersManager.loadHandler(gui_handlers.Options, getOptionsWndOpenParams(group))
}

gui_handlers.Options <- class extends gui_handlers.GenericOptionsModal {
  wndType = handlerType.BASE
  sceneBlkName = "%gui/options/optionsWnd.blk"
  sceneNavBlkName = "%gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false
  needMoveMouseOnButtonApply = false

  filterText = ""

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
        tabName = "#options/" + gr.name
        navImagesText = ::get_navigation_images_text(idx, this.optGroups.len())
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

    let showWebUI = is_platform_pc && isInFlight() && ::WebUI.get_port() != 0
    this.showSceneBtn("web_ui_button", showWebUI)
  }

  function onGroupSelect(obj) {
    if (!obj)
      return

    let newGroup = obj.getValue()
    if (this.curGroup == newGroup && !(newGroup in this.optGroups))
      return

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

    if ("fillFuncName" in config) {
      this.curGroup = group
      this[config.fillFuncName](group);
      return;
    }

    if ("options" in config)
      this.fillOptionsList(group, "optionslist")

    this.updateLinkedOptions()
  }

  function fillInternetRadioOptions(group) {
    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/internetRadioOptions.blk", this);
    this.fillLocalInternetRadioOptions(group)
    this.updateInternerRadioButtons()
  }

  function fillSocialOptions(_group) {
    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/socialOptions.blk", this)
  }

  function setupSearch() {
    this.showSceneBtn("search_container", this.isSearchInCurrentGroupAvaliable())
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
      this.showSceneBtn("filter_notify", false)
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

    let filterNotifyObj = this.showSceneBtn("filter_notify", needShowSearchNotify)
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

  function fillShortcutInfo(shortcut_id_name, shortcut_object_name) {
    let shortcut = ::get_shortcuts([shortcut_id_name]);
    local data = ::get_shortcut_text({ shortcuts = shortcut, shortcutId = 0 })
    if (data == "")
      data = "---";
    this.scene.findObject(shortcut_object_name).setValue(data);
  }
  function bindShortcutButton(devs, btns, shortcut_id_name, shortcut_object_name) {
    let shortcut = ::get_shortcuts([shortcut_id_name]);

    let event = shortcut[0];

    event.append({ dev = devs, btn = btns });
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    let data = ::get_shortcut_text({ shortcuts = shortcut, shortcutId = 0 })
    this.scene.findObject(shortcut_object_name).setValue(data);
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name) {
    let shortcut = ::get_shortcuts([shortcut_id_name]);

    shortcut[0] = [];

    setShortcutsAndSaveControls(shortcut, [shortcut_id_name]);
    this.save(false);

    this.scene.findObject(shortcut_object_name).setValue("---");
  }

  function fillLocalInternetRadioOptions(group) {
    let config = this.optGroups[group]

    if ("options" in config)
      this.fillOptionsList(group, "internetRadioOptions")

    this.fillShortcutInfo("ID_INTERNET_RADIO", "internet_radio_shortcut");
    this.fillShortcutInfo("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
    this.fillShortcutInfo("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function onAssignInternetRadioButton() {
    ::assignButtonWindow(this, this.bindInternetRadioButton);
  }
  function bindInternetRadioButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onClearInternetRadioButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onAssignInternetRadioPrevButton() {
    ::assignButtonWindow(this, this.bindInternetRadioPrevButton);
  }
  function bindInternetRadioPrevButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onClearInternetRadioPrevButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onAssignInternetRadioNextButton() {
    ::assignButtonWindow(this, this.bindInternetRadioNextButton);
  }
  function bindInternetRadioNextButton(devs, btns) {
    this.bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }
  function onClearInternetRadioNextButton() {
    this.onClearShortcutButton("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function fillVoiceChatOptions(group) {
    let config = this.optGroups[group]

    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/voicechatOptions.blk", this)

    let needShowOptions = isCrossNetworkChatEnabled() || isPlatformXboxOne
    this.showSceneBtn("voice_disable_warning", !needShowOptions)

    this.showSceneBtn("voice_options_block", needShowOptions)
    if (!needShowOptions)
      return

    if ("options" in config)
      this.fillOptionsList(group, "voiceOptions")

    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);
    local data = ::get_shortcut_text({ shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false });
    if (data == "")
      data = "---";
    else
      data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"

    this.scene.findObject("ptt_shortcut").setValue(data)
    showObjById("ptt_buttons_block", ::get_option(USEROPT_PTT).value, this.scene)

    let echoButton = this.scene.findObject("joinEchoButton");
    if (echoButton)
      echoButton.enable(true)
  }

  function onAssignVoiceButton() {
    ::assignButtonWindow(this, this.bindVoiceButton);
  }

  function bindVoiceButton(devs, btns) {
    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    let event = ptt_shortcut[0];

    event.append({ dev = devs, btn = btns });
    if (event.len() > 1)
      event.remove(0);

    setShortcutsAndSaveControls(ptt_shortcut, ["ID_PTT"]);
    this.save(false);

    local data = ::get_shortcut_text({ shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false })
    data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"
    this.scene.findObject("ptt_shortcut").setValue(data);
  }

  function onClearVoiceButton() {
    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    ptt_shortcut[0] = [];

    setShortcutsAndSaveControls(ptt_shortcut, ["ID_PTT"]);
    this.save(false);

    this.scene.findObject("ptt_shortcut").setValue("---");
  }

  function joinEchoChannel(join) {
    this.echoTest = join;
    ::gchat_voice_echo_test(join);
  }

  function onEchoTestButton() {
    let echoButton = this.scene.findObject("joinEchoButton");

    this.joinEchoChannel(!this.echoTest);
    if (echoButton) {
      echoButton.text = (this.echoTest) ? (loc("options/leaveEcho")) : (loc("options/joinEcho"));
      echoButton.tooltip = (this.echoTest) ? (loc("guiHints/leaveEcho")) : (loc("guiHints/joinEcho"));
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

  function fillOptionsList(group, objName) {
    this.curGroup = group
    let config = this.optGroups[group]

    if (this.optionsConfig == null)
      this.optionsConfig = {
        onTblClick = "onTblSelect"
        containerCb = "onChangeOptionValue"
      }

    this.currentContainerName = "options_" + config.name
    let container = create_options_container(this.currentContainerName, config.options, true, this.columnsRatio,
      true, this.optionsConfig)
    this.optionsContainers = [container.descr]

    this.guiScene.setUpdatesEnabled(false, false)
    this.optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(this.scene.findObject(objName), container.tbl, container.tbl.len(), this)
    this.setNavigationItems()
    this.showOptionsSelectedNavigation()
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

  function onOpenGpuBenchmark() {
    showGpuBenchmarkWnd()
  }

  function onPostFxSettings(_obj) {
    this.applyFunc = ::gui_start_postfx_settings
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onHdrSettings(_obj) {
    this.applyFunc = fxOptions.openHdrSettings
    this.applyOptions()
    this.joinEchoChannel(false)
  }

  function onPreloaderSettings() {
    preloaderOptionsModal()
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

  function onDialogAddRadio() {
    openAddRadioWnd()
  }

  function onDialogEditRadio() {
    let radio = ::get_internet_radio_options()
    if (!radio)
      return this.updateInternerRadioButtons()

    openAddRadioWnd(radio?.station ?? "")
  }

  function onRemoveRadio() {
    let radio = ::get_internet_radio_options()
    if (!radio)
      return this.updateInternerRadioButtons()
    let nameRadio = radio?.station
    if (!nameRadio)
      return
    this.msgBox("warning",
      format(loc("options/msg_remove_radio"), nameRadio),
      [
        ["ok", function() {
          ::remove_internet_radio_station(nameRadio);
          broadcastEvent("UpdateListRadio", {})
        }],
        ["cancel", function() {}]
      ], "ok")
  }

  function onEventUpdateListRadio(_params) {
    let obj = this.scene.findObject("groups_list")
    if (!obj)
      return
    this.fillOptionsList(obj.getValue(), "internetRadioOptions")
    this.updateInternerRadioButtons()
  }

  function updateInternerRadioButtons() {
    let radio = ::get_internet_radio_options()
    let isEnable = radio?.station ? ::is_internet_radio_station_removable(radio.station) : false
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
    foreach (opt in [USEROPT_SKIP_LEFT_BULLETS_WARNING,
                     USEROPT_SKIP_WEAPON_WARNING
                    ])
      set_gui_option(opt, false)

    saveLocalAccountSettings("skipped_msg", null)
    resetTutorialSkip()
    broadcastEvent("ResetSkipedNotifications")

    //To notify player about success, it is only for player,
    // to be sure, that operation is done.
    ::g_popups.add("", loc("mainmenu/btnRevealNotifications/onSuccess"))
  }

  function resetVolumes() {
    reset_volumes()
    this.fillOptionsList(this.curGroup, "optionslist")
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
    this.showSceneBtn("restart_suggestion", showRestartText)
    this.showSceneBtn("btn_restart", showRestartText && canRestartClient())
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

addListenersWithoutEnv({
  showOptionsWnd = @(_p) openOptionsWnd()
})

return {
  openOptionsWnd
}
