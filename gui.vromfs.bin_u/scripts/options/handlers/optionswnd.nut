from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

let { format } = require("string")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")

let { set_gui_option } = require("guiOptions")
let optionsListModule = require("%scripts/options/optionsList.nut")
let { isCrossNetworkChatEnabled } = require("%scripts/social/crossplay.nut")
let { fillSystemGuiOptions, resetSystemGuiOptions, onSystemGuiOptionChanged, onRestartClient
  } = require("%scripts/options/systemOptions.nut")
let fxOptions = require("%scripts/options/fxOptions.nut")
let { openAddRadioWnd } = require("%scripts/options/handlers/addRadioWnd.nut")
let preloaderOptionsModal = require("%scripts/options/handlers/preloaderOptionsModal.nut")
let { isPlatformSony } = require("%scripts/clientState/platform.nut")
let { resetTutorialSkip } = require("%scripts/tutorials/tutorialsData.nut")
let { setBreadcrumbGoBackParams } = require("%scripts/breadcrumb.nut")
let { SND_NUM_TYPES, get_sound_volume, set_sound_volume, reset_volumes } = require("soundOptions")
let { isAvailableFacebook } = require("%scripts/social/facebookStates.nut")
let { showGpuBenchmarkWnd } = require("%scripts/options/gpuBenchmarkWnd.nut")
let { canRestartClient } = require("%scripts/utils/restartClient.nut")
let { isOptionReqRestartChanged, setOptionReqRestartValue
} = require("%scripts/options/optionsUtils.nut")

const MAX_NUM_VISIBLE_FILTER_OPTIONS = 25

let function openOptionsWnd(group = null) {
  let isInFlight = ::is_in_flight()
  if (isInFlight)
    ::init_options()

  let options = optionsListModule.getOptionsList()

  if (group != null)
    foreach (o in options)
      if (o.name == group)
        o.selected <- true

  let params = {
    titleText = isInFlight
      ? ::is_multiplayer() ? null : loc("flightmenu/title")
      : loc("mainmenu/btnGameplay")
    optGroups = options
    wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY
    sceneNavBlkName = "%gui/options/navOptionsIngame.blk"
  }

  params.cancelFunc <- function() {
    ::set_option_gamma(::get_option_gamma(), false)
    for (local i = 0; i < SND_NUM_TYPES; i++)
      set_sound_volume(i, get_sound_volume(i), false)
  }

  return ::handlersManager.loadHandler(::gui_handlers.Options, params)
}

::gui_handlers.Options <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.BASE
  sceneBlkName = "%gui/options/optionsWnd.blk"
  sceneNavBlkName = "%gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false
  needMoveMouseOnButtonApply = false

  filterText = ""

  function initScreen()
  {
    if (!optGroups)
      base.goBack()

    base.initScreen()
    setBreadcrumbGoBackParams(this)

    let view = { tabs = [] }
    local curOption = 0
    foreach(idx, gr in optGroups)
    {
      view.tabs.append({
        id = gr.name
        visualDisable = gr.name == "voicechat" && !isCrossNetworkChatEnabled()
        tabName = "#options/" + gr.name
        navImagesText = ::get_navigation_images_text(idx, optGroups.len())
      })

      if (getTblValue("selected", gr) == true)
        curOption = idx
    }

    let data = ::handyman.renderCached("%gui/frameHeaderTabs", view)
    let groupsObj = this.scene.findObject("groups_list")
    this.optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(groupsObj, data, data.len(), this)
    groupsObj.show(true)
    groupsObj.setValue(curOption)

    let showWebUI = is_platform_pc && ::is_in_flight() && ::WebUI.get_port() != 0
    this.showSceneBtn("web_ui_button", showWebUI)
  }

  function onGroupSelect(obj)
  {
    if (!obj)
      return

    let newGroup = obj.getValue()
    if (curGroup==newGroup && !(newGroup in optGroups))
      return

    this.resetNavigation()

    if (curGroup>=0)
    {
      this.applyFunc = (@(newGroup) function() {
        fillOptions(newGroup)
        this.applyFunc = null
      })(newGroup)
      this.applyOptions()
    } else
      fillOptions(newGroup)

    let groupName = optGroups[newGroup].name
    setupSearch()
    joinEchoChannel(false)
    ::handlersManager.setLastBaseHandlerStartFunc(@() openOptionsWnd(groupName))
  }

  function fillOptions(group)
  {
    let config = optGroups[group]

    if ("fillFuncName" in config)
    {
      curGroup = group
      this[config.fillFuncName](group);
      return;
    }

    if ("options" in config)
      fillOptionsList(group, "optionslist")

    this.updateLinkedOptions()
  }

  function fillInternetRadioOptions(group)
  {
    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/internetRadioOptions.blk", this);
    fillLocalInternetRadioOptions(group)
    updateInternerRadioButtons()
  }

  function fillSocialOptions(_group)
  {
    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/socialOptions.blk", this)

    let hasFacebook = isAvailableFacebook()
    let fObj = this.showSceneBtn("facebook_frame", hasFacebook)
    if (hasFacebook && fObj)
    {
      fObj.findObject("facebook_like_btn").tooltip = loc("guiHints/facebookLike") + loc("ui/colon") + ::get_unlock_reward("facebook_like")
      checkFacebookLoginStatus()
    }
  }

  function setupSearch()
  {
    this.showSceneBtn("search_container", isSearchInCurrentGroupAvaliable())
    resetSearch()
  }

  function isSearchInCurrentGroupAvaliable()
  {
    return getTblValue("isSearchAvaliable", optGroups[curGroup])
  }

  function onFilterEditBoxChangeValue()
  {
    applySearchFilter()
  }

  function onFilterEditBoxCancel(obj = null)
  {
    if ((obj?.getValue() ?? "") != "")
      resetSearch()
    else
      this.guiScene.performDelayed(this, function() {
        if (this.isValid())
          this.goBack()
      })
  }

  function applySearchFilter()
  {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if (!checkObj(filterEditBox))
      return

    filterText = ::g_string.utf8ToLower(filterEditBox.getValue())

    if( ! filterText.len()) {
      showOptionsSelectedNavigation()
      this.showSceneBtn("filter_notify", false)
      return
    }

    let searchResultOptions = []
    let visibleHeadersArray = {}
    local needShowSearchNotify = false
    foreach(option in this.getCurrentOptionsList())
    {
      local show = ::g_string.utf8ToLower(option.getTitle()).indexof(filterText) != null
      needShowSearchNotify = needShowSearchNotify
        || (show && searchResultOptions.len() >= MAX_NUM_VISIBLE_FILTER_OPTIONS)
      show = show && !needShowSearchNotify

      base.showOptionRow(option, show)

      if(!show)
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

  function resetSearch()
  {
    let filterEditBox = this.scene.findObject("filter_edit_box")
    if ( ! checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function doNavigateToSection(_navItem)
  {
    resetSearch()
    showOptionsSelectedNavigation()
  }

  function showOptionRow(id, show)
  {
    resetSearch()
    base.showOptionRow(id, show)
  }

  function onFacebookLogin()
  {
    ::make_facebook_login_and_do(checkFacebookLoginStatus, this)
  }

  function onFacebookLike()
  {
    if (!::facebook_is_logged_in())
      return;

    ::facebook_like(loc("facebook/like_url"), "");
    onFacebookLikeShared();
  }

  function onFacebookLikeShared()
  {
    this.scene.findObject("facebook_like_btn").enable(false);
  }

  function onEventCheckFacebookLoginStatus(_params)
  {
    checkFacebookLoginStatus()
  }

  function checkFacebookLoginStatus()
  {
    if (!checkObj(this.scene))
      return

    let fbObj = this.scene.findObject("facebook_frame")
    if (!checkObj(fbObj))
      return

    let facebookLogged = ::facebook_is_logged_in();
    ::showBtn("facebook_login_btn", !facebookLogged, fbObj)
    fbObj.findObject("facebook_friends_btn").enable(facebookLogged)

    let showLikeBtn = hasFeature("FacebookWallPost")
    let likeBtn = ::showBtn("facebook_like_btn", showLikeBtn, fbObj)
    if (checkObj(likeBtn) && showLikeBtn)
    {
      let alreadyLiked = ::is_unlocked_scripted(UNLOCKABLE_ACHIEVEMENT, "facebook_like")
      likeBtn.enable(facebookLogged && !alreadyLiked && !isPlatformSony)
      likeBtn.show(!isPlatformSony)
    }
  }

  function fillShortcutInfo(shortcut_id_name, shortcut_object_name)
  {
    let shortcut = ::get_shortcuts([shortcut_id_name]);
    local data = ::get_shortcut_text({shortcuts = shortcut, shortcutId = 0})
    if (data == "")
      data = "---";
    this.scene.findObject(shortcut_object_name).setValue(data);
  }
  function bindShortcutButton(devs, btns, shortcut_id_name, shortcut_object_name)
  {
    let shortcut = ::get_shortcuts([shortcut_id_name]);

    let event = shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    this.save(false);

    let data = ::get_shortcut_text({shortcuts = shortcut, shortcutId = 0})
    this.scene.findObject(shortcut_object_name).setValue(data);
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name)
  {
    let shortcut = ::get_shortcuts([shortcut_id_name]);

    shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    this.save(false);

    this.scene.findObject(shortcut_object_name).setValue("---");
  }

  function fillLocalInternetRadioOptions(group)
  {
    let config = optGroups[group]

    if ("options" in config)
      fillOptionsList(group, "internetRadioOptions")

    fillShortcutInfo("ID_INTERNET_RADIO", "internet_radio_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function onAssignInternetRadioButton()
  {
    ::assignButtonWindow(this, bindInternetRadioButton);
  }
  function bindInternetRadioButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onClearInternetRadioButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO", "internet_radio_shortcut");
  }
  function onAssignInternetRadioPrevButton()
  {
    ::assignButtonWindow(this, bindInternetRadioPrevButton);
  }
  function bindInternetRadioPrevButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onClearInternetRadioPrevButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
  }
  function onAssignInternetRadioNextButton()
  {
    ::assignButtonWindow(this, bindInternetRadioNextButton);
  }
  function bindInternetRadioNextButton(devs, btns)
  {
    bindShortcutButton(devs, btns, "ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }
  function onClearInternetRadioNextButton()
  {
    onClearShortcutButton("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function fillVoiceChatOptions(group)
  {
    let config = optGroups[group]

    this.guiScene.replaceContent(this.scene.findObject("optionslist"), "%gui/options/voicechatOptions.blk", this)

    let needShowOptions = isCrossNetworkChatEnabled()
    this.showSceneBtn("voice_disable_warning", !needShowOptions)

    this.showSceneBtn("voice_options_block", needShowOptions)
    if (!needShowOptions)
      return

    if ("options" in config)
      fillOptionsList(group, "voiceOptions")

    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);
    local data = ::get_shortcut_text({shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false});
    if (data == "")
      data = "---";
    else
      data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"

    this.scene.findObject("ptt_shortcut").setValue(data)
    ::showBtn("ptt_buttons_block", ::get_option(::USEROPT_PTT).value, this.scene)

    let echoButton = this.scene.findObject("joinEchoButton");
    if (echoButton) echoButton.enable(true)
  }

  function onAssignVoiceButton()
  {
    ::assignButtonWindow(this, bindVoiceButton);
  }

  function bindVoiceButton(devs, btns)
  {
    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    let event = ptt_shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    this.save(false);

    local data = ::get_shortcut_text({shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false})
    data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"
    this.scene.findObject("ptt_shortcut").setValue(data);
  }

  function onClearVoiceButton()
  {
    let ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    ptt_shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    this.save(false);

    this.scene.findObject("ptt_shortcut").setValue("---");
  }

  function joinEchoChannel(join)
  {
    echoTest = join;
    ::gchat_voice_echo_test(join);
  }

  function onEchoTestButton()
  {
    let echoButton = this.scene.findObject("joinEchoButton");

    joinEchoChannel(!echoTest);
    if(echoButton)
    {
      echoButton.text = (echoTest)? (loc("options/leaveEcho")) : (loc("options/joinEcho"));
      echoButton.tooltip = (echoTest)? (loc("guiHints/leaveEcho")) : (loc("guiHints/joinEcho"));
    }
  }

  function fillSystemOptions(_group)
  {
    this.optionsContainers = [{ name="options_systemOptions", data=[] }]
    fillSystemGuiOptions(this.scene.findObject("optionslist"), this)
  }

  function onSystemOptionChanged(obj)
  {
    onSystemGuiOptionChanged(obj)
  }

  function onSystemOptionsRestartClient(_obj)
  {
    this.applyOptions()
    onRestartClient()
  }

  function onSystemOptionsReset(_obj)
  {
    resetSystemGuiOptions()
  }

  function passValueToParent(obj)
  {
    if (!checkObj(obj))
      return
    let objParent = obj.getParent()
    if (!checkObj(objParent))
      return
    let val = obj.getValue()
    if (objParent.getValue() != val)
      objParent.setValue(val)
  }

  function fillOptionsList(group, objName)
  {
    curGroup = group
    let config = optGroups[group]

    if(this.optionsConfig == null)
      this.optionsConfig = {
        onTblClick = "onTblSelect"
        containerCb = "onChangeOptionValue"
      }

    this.currentContainerName = "options_" + config.name
    let container = ::create_options_container(this.currentContainerName, config.options, true, this.columnsRatio,
      true, this.optionsConfig)
    this.optionsContainers = [container.descr]

    this.guiScene.setUpdatesEnabled(false, false)
    this.optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(this.scene.findObject(objName), container.tbl, container.tbl.len(), this)
    this.setNavigationItems()
    showOptionsSelectedNavigation()
    updateNavbar()
    this.guiScene.setUpdatesEnabled(true, true)
  }

  function showOptionsSelectedNavigation() {
    let currentHeaderId = this.navigationHandlerWeak?.getCurrentItem().id
    if (currentHeaderId == null)
      return

    local isCurrentSection = false
    foreach(option in this.getCurrentOptionsList())
    {
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

  function onPostFxSettings(_obj)
  {
    this.applyFunc = ::gui_start_postfx_settings
    this.applyOptions()
    joinEchoChannel(false)
  }

  function onHdrSettings(_obj)
  {
    this.applyFunc = fxOptions.openHdrSettings
    this.applyOptions()
    joinEchoChannel(false)
  }

  function onPreloaderSettings()
  {
    preloaderOptionsModal()
  }

  function onWebUiMap()
  {
    if(::WebUI.get_port() == 0)
      return

    ::WebUI.launch_browser()
  }

  function fullReloadScene() {
    doApply()
    base.fullReloadScene()
  }

  function doApply()
  {
    joinEchoChannel(false);
    let result = base.doApply();

    let group = curGroup == -1 ? null : optGroups[curGroup];
    if (group && ("onApplyHandler" in group) && group.onApplyHandler)
      group.onApplyHandler();

    return result;
  }

  function onDialogAddRadio()
  {
    openAddRadioWnd()
  }

  function onDialogEditRadio()
  {
    let radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()

    openAddRadioWnd(radio?.station ?? "")
  }

  function onRemoveRadio()
  {
    let radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()
    let nameRadio = radio?.station
    if (!nameRadio)
      return
    this.msgBox("warning",
      format(loc("options/msg_remove_radio"), nameRadio),
      [
        ["ok", (@(nameRadio) function() {
          ::remove_internet_radio_station(nameRadio);
          ::broadcastEvent("UpdateListRadio", {})
        })(nameRadio)],
        ["cancel", function() {}]
      ], "ok")
  }

  function onEventUpdateListRadio(_params)
  {
    let obj = this.scene.findObject("groups_list")
    if (!obj)
      return
    fillOptionsList(obj.getValue(), "internetRadioOptions")
    updateInternerRadioButtons()
  }

  function updateInternerRadioButtons()
  {
    let radio = ::get_internet_radio_options()
    let isEnable = radio?.station ? ::is_internet_radio_station_removable(radio.station) : false
    let btnEditRadio = this.scene.findObject("btn_edit_radio")
    if (btnEditRadio)
      btnEditRadio.enable(isEnable)
    let btnRemoveRadio = this.scene.findObject("btn_remove_radio")
    if (btnRemoveRadio)
      btnRemoveRadio.enable(isEnable)
  }

  function onRevealNotifications()
  {
    ::scene_msg_box("ask_reveal_notifications",
      null,
      loc("mainmenu/btnRevealNotifications/askPlayer"),
      [
        ["yes", Callback(resetNotifications, this)],
        ["no", @() null]
      ],
      "yes", { cancel_fn = @() null })
  }

  function resetNotifications()
  {
    foreach (opt in [::USEROPT_SKIP_LEFT_BULLETS_WARNING,
                     ::USEROPT_SKIP_WEAPON_WARNING
                    ])
      set_gui_option(opt, false)

    ::save_local_account_settings("skipped_msg", null)
    resetTutorialSkip()
    ::broadcastEvent("ResetSkipedNotifications")

    //To notify player about success, it is only for player,
    // to be sure, that operation is done.
    ::g_popups.add("", loc("mainmenu/btnRevealNotifications/onSuccess"))
  }

  function resetVolumes()
  {
    reset_volumes()
    fillOptionsList(curGroup, "optionslist")
  }

  function isRestartPending() {
    foreach (container in this.optionsContainers) {
      foreach(option in container.data) {
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
    let group = optGroups?[curGroup]
    if (group == null)
      return

    let showRestartText = isRestartPending()
    this.showSceneBtn("restart_suggestion", showRestartText)
    this.showSceneBtn("btn_restart", showRestartText && canRestartClient())
  }

  function onChangeOptionValue(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    if (option.needRestartClient) {
      setOptionReqRestartValue(option)
      updateNavbar()
    }

    if (option.optionCb != null)
      this[option.optionCb](obj)
  }
}

return {
  openOptionsWnd
}
