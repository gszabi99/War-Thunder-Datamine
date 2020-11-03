local optionsListModule = require("scripts/options/optionsList.nut")
local { isCrossNetworkChatEnabled } = require("scripts/social/crossplay.nut")
local { fillSystemGuiOptions, onSystemGuiOptionChanged, onRestartClient
  } = require("scripts/options/systemOptions.nut")
local fxOptions = require("scripts/options/fxOptions.nut")
local { openAddRadioWnd } = require("scripts/options/handlers/addRadioWnd.nut")
local { isPlatformSony } = require("scripts/clientState/platform.nut")
local backToMainScene = require("scripts/mainmenu/backToMainScene.nut")
local { resetTutorialSkip } = require("scripts/tutorials/tutorialsData.nut")

const MAX_NUM_VISIBLE_FILTER_OPTIONS = 25

class ::gui_handlers.Options extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.BASE
  sceneBlkName = "gui/options/optionsWnd.blk"
  sceneNavBlkName = "gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false
  needMoveMouseOnButtonApply = false

  filterText = ""

  function initScreen()
  {
    backSceneFunc = backToMainScene
    if (!optGroups)
      base.goBack()

    base.initScreen()

    local view = { tabs = [] }
    local curOption = 0
    foreach(idx, gr in optGroups)
    {
      view.tabs.append({
        id = gr.name
        visualDisable = gr.name == "voicechat" && !isCrossNetworkChatEnabled()
        tabName = "#options/" + gr.name
        navImagesText = ::get_navigation_images_text(idx, optGroups.len())
      })

      if (::getTblValue("selected", gr) == true)
        curOption = idx
    }

    local data = ::handyman.renderCached("gui/frameHeaderTabs", view)
    local groupsObj = scene.findObject("groups_list")
    optionIdToObjCache.clear()
    guiScene.replaceContentFromText(groupsObj, data, data.len(), this)
    groupsObj.show(true)
    groupsObj.setValue(curOption)
    onGroupSelect(groupsObj)

    showSceneBtn("btn_postfx_settings", !::is_compatibility_mode())
    showSceneBtn("btn_hdr_settings", ::is_hdr_enabled())

    local showWebUI = ::is_platform_pc && ::is_in_flight() && ::WebUI.get_port() != 0
    showSceneBtn("web_ui_button", showWebUI)
  }

  function onGroupSelect(obj)
  {
    if (!obj)
      return

    local newGroup = obj.getValue()
    if (curGroup==newGroup && !(newGroup in optGroups))
      return

    resetNavigation()

    if (curGroup>=0)
    {
      applyFunc = (@(newGroup) function() {
        fillOptions(newGroup)
        applyFunc = null
      })(newGroup)
      applyOptions()
    } else
      fillOptions(newGroup)

    setupSearch()
    joinEchoChannel(false);
  }

  function fillOptions(group)
  {
    local config = optGroups[group]

    if ("fillFuncName" in config)
    {
      curGroup = group
      this[config.fillFuncName](group);
      return;
    }

    if ("options" in config)
      fillOptionsList(group, "optionslist")

    updateLinkedOptions()
  }

  function fillInternetRadioOptions(group)
  {
    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/internetRadioOptions.blk", this);
    fillLocalInternetRadioOptions(group)
    updateInternerRadioButtons()
  }

  function fillSocialOptions(group)
  {
    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/socialOptions.blk", this)

    local hasFacebook = ::has_feature("Facebook")
    local fObj = showSceneBtn("facebook_frame", hasFacebook)
    if (hasFacebook && fObj)
    {
      fObj.findObject("facebook_like_btn").tooltip = ::loc("guiHints/facebookLike") + ::loc("ui/colon") + ::get_unlock_reward("facebook_like")
      checkFacebookLoginStatus()
    }
  }

  function setupSearch()
  {
    showSceneBtn("search_container", isSearchInCurrentGroupAvaliable())
    resetSearch()
  }

  function isSearchInCurrentGroupAvaliable()
  {
    return ::getTblValue("isSearchAvaliable", optGroups[curGroup])
  }

  function onFilterEditBoxChangeValue()
  {
    applySearchFilter()
  }

  function onFilterEditBoxCancel(obj = null)
  {
    if ((obj?.getValue() ?? "") == "")
      return goBack()
    resetSearch()
  }

  function applySearchFilter()
  {
    local filterEditBox = scene.findObject("filter_edit_box")
    if (!::checkObj(filterEditBox))
      return

    filterText = ::g_string.utf8ToLower(filterEditBox.getValue())

    if( ! filterText.len()) {
      showOptionsSelectedNavigation()
      showSceneBtn("filter_notify", false)
      return
    }

    local searchResultOptions = []
    local visibleHeadersArray = {}
    local needShowSearchNotify = false
    foreach(option in getCurrentOptionsList())
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

      local header = getOptionHeader(option)
      if (header == null || (visibleHeadersArray?[header.id] ?? false))
        continue

      searchResultOptions.append(header)
      visibleHeadersArray[header.id] <- true
      base.showOptionRow(header, true)
    }

    local filterNotifyObj = showSceneBtn("filter_notify", needShowSearchNotify)
    if (needShowSearchNotify && filterNotifyObj != null)
      filterNotifyObj.setValue(::loc("menu/options/maxNumFilterOptions",
        { num = MAX_NUM_VISIBLE_FILTER_OPTIONS }))
  }

  function resetSearch()
  {
    local filterEditBox = scene.findObject("filter_edit_box")
    if ( ! ::checkObj(filterEditBox))
      return

    filterEditBox.setValue("")
  }

  function doNavigateToSection(navItem)
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
    make_facebook_login_and_do(checkFacebookLoginStatus, this)
  }

  function onFacebookLike()
  {
    if (!::facebook_is_logged_in())
      return;

    ::facebook_like(::loc("facebook/like_url"), "");
    onFacebookLikeShared();
  }

  function onFacebookLikeShared()
  {
    scene.findObject("facebook_like_btn").enable(false);
  }

  function onEventCheckFacebookLoginStatus(params)
  {
    checkFacebookLoginStatus()
  }

  function checkFacebookLoginStatus()
  {
    if (!::checkObj(scene))
      return

    local fbObj = scene.findObject("facebook_frame")
    if (!::checkObj(fbObj))
      return

    local facebookLogged = ::facebook_is_logged_in();
    ::showBtn("facebook_login_btn", !facebookLogged, fbObj)
    fbObj.findObject("facebook_friends_btn").enable(facebookLogged)

    local showLikeBtn = ::has_feature("FacebookWallPost")
    local likeBtn = ::showBtn("facebook_like_btn", showLikeBtn, fbObj)
    if (::checkObj(likeBtn) && showLikeBtn)
    {
      local alreadyLiked = ::is_unlocked_scripted(::UNLOCKABLE_ACHIEVEMENT, "facebook_like")
      likeBtn.enable(facebookLogged && !alreadyLiked && !isPlatformSony)
      likeBtn.show(!isPlatformSony)
    }
  }

  function fillShortcutInfo(shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);
    local data = ::get_shortcut_text({shortcuts = shortcut, shortcutId = 0})
    if (data == "")
      data = "---";
    scene.findObject(shortcut_object_name).setValue(data);
  }
  function bindShortcutButton(devs, btns, shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);

    local event = shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    save(false);

    local data = ::get_shortcut_text({shortcuts = shortcut, shortcutId = 0})
    scene.findObject(shortcut_object_name).setValue(data);
  }

  function onClearShortcutButton(shortcut_id_name, shortcut_object_name)
  {
    local shortcut = ::get_shortcuts([shortcut_id_name]);

    shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(shortcut, [shortcut_id_name]);
    save(false);

    scene.findObject(shortcut_object_name).setValue("---");
  }

  function fillLocalInternetRadioOptions(group)
  {
    local config = optGroups[group]

    if ("options" in config)
      fillOptionsList(group, "internetRadioOptions")

    fillShortcutInfo("ID_INTERNET_RADIO", "internet_radio_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_PREV", "internet_radio_prev_shortcut");
    fillShortcutInfo("ID_INTERNET_RADIO_NEXT", "internet_radio_next_shortcut");
  }

  function onAssignInternetRadioButton()
  {
    assignButtonWindow(this, bindInternetRadioButton);
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
    assignButtonWindow(this, bindInternetRadioPrevButton);
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
    assignButtonWindow(this, bindInternetRadioNextButton);
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
    local config = optGroups[group]

    guiScene.replaceContent(scene.findObject("optionslist"), "gui/options/voicechatOptions.blk", this)

    local needShowOptions = isCrossNetworkChatEnabled()
    showSceneBtn("voice_disable_warning", !needShowOptions)

    showSceneBtn("voice_options_block", needShowOptions)
    if (!needShowOptions)
      return

    if ("options" in config)
      fillOptionsList(group, "voiceOptions")

    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);
    local data = ::get_shortcut_text({shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false});
    if (data == "")
      data = "---";
    else
      data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"

    scene.findObject("ptt_shortcut").setValue(data)
    ::showBtn("ptt_buttons_block", get_option(::USEROPT_PTT).value, scene)

    local echoButton = scene.findObject("joinEchoButton");
    if (echoButton) echoButton.enable(true)
  }

  function onAssignVoiceButton()
  {
    assignButtonWindow(this, bindVoiceButton);
  }

  function bindVoiceButton(devs, btns)
  {
    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    local event = ptt_shortcut[0];

    event.append({dev = devs, btn = btns});
    if (event.len() > 1)
      event.remove(0);

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    save(false);

    local data = ::get_shortcut_text({shortcuts = ptt_shortcut, shortcutId = 0, cantBeEmpty = false})
    data = "<color=@hotkeyColor>" + ::hackTextAssignmentForR2buttonOnPS4(data) + "</color>"
    scene.findObject("ptt_shortcut").setValue(data);
  }

  function onClearVoiceButton()
  {
    local ptt_shortcut = ::get_shortcuts(["ID_PTT"]);

    ptt_shortcut[0] = [];

    ::set_controls_preset(""); //custom mode

    ::set_shortcuts(ptt_shortcut, ["ID_PTT"]);
    save(false);

    scene.findObject("ptt_shortcut").setValue("---");
  }

  function joinEchoChannel(join)
  {
    echoTest = join;
    ::gchat_voice_echo_test(join);
  }

  function onEchoTestButton()
  {
    local echoButton = scene.findObject("joinEchoButton");

    joinEchoChannel(!echoTest);
    if(echoButton)
    {
      echoButton.text = (echoTest)? (::loc("options/leaveEcho")) : (::loc("options/joinEcho"));
      echoButton.tooltip = (echoTest)? (::loc("guiHints/leaveEcho")) : (::loc("guiHints/joinEcho"));
    }
  }

  function fillSystemOptions(group)
  {
    optionsContainers = [{ name="options_systemOptions", data=[] }]
    fillSystemGuiOptions(scene.findObject("optionslist"), this)
  }

  function onSystemOptionChanged(obj)
  {
    onSystemGuiOptionChanged(obj)
  }

  function onSystemOptionsRestartClient(obj)
  {
    onRestartClient()
  }

  function passValueToParent(obj)
  {
    if (!::checkObj(obj))
      return
    local objParent = obj.getParent()
    if (!::checkObj(objParent))
      return
    local val = obj.getValue()
    if (objParent.getValue() != val)
      objParent.setValue(val)
  }

  function fillOptionsList(group, objName)
  {
    curGroup = group
    local config = optGroups[group]

    if( ! optionsConfig)
        optionsConfig = {}
    optionsConfig.onTblClick <- "onTblSelect"

    currentContainerName = "options_" + config.name
    local container = ::create_options_container(currentContainerName, config.options, true, columnsRatio,
                        true, true, optionsConfig)
    optionsContainers = [container.descr]

    guiScene.setUpdatesEnabled(false, false)
    optionIdToObjCache.clear()
    guiScene.replaceContentFromText(scene.findObject(objName), container.tbl, container.tbl.len(), this)
    setNavigationItems()
    showOptionsSelectedNavigation()
    guiScene.setUpdatesEnabled(true, true)
  }

  function showOptionsSelectedNavigation() {
    local currentHeaderId = navigationHandlerWeak?.getCurrentItem().id
    if (currentHeaderId == null)
      return

    local isCurrentSection = false
    foreach(option in getCurrentOptionsList())
    {
      if (option.controlType == optionControlType.HEADER) {
        isCurrentSection = currentHeaderId == option.id
        base.showOptionRow(option, false)
        continue
      }

      base.showOptionRow(option, isCurrentSection)
    }
  }

  function onPostFxSettings(obj)
  {
    applyFunc = gui_start_postfx_settings
    applyOptions()
    joinEchoChannel(false)
  }

  function onHdrSettings(obj)
  {
    applyFunc = fxOptions.openHdrSettings
    applyOptions()
    joinEchoChannel(false)
  }

  function onWebUiMap()
  {
    if(::WebUI.get_port() == 0)
      return

    ::WebUI.launch_browser()
  }

  function afterModalDestroy()
  {
    joinEchoChannel(false);
    base.afterModalDestroy()
  }

  function doApply()
  {
    local result = base.doApply();

    local group = curGroup == -1 ? null : optGroups[curGroup];
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
    local radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()

    openAddRadioWnd(radio?.station ?? "")
  }

  function onRemoveRadio()
  {
    local radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()
    local nameRadio = radio?.station
    if (!nameRadio)
      return
    msgBox("warning",
      ::format(::loc("options/msg_remove_radio"), nameRadio),
      [
        ["ok", (@(nameRadio) function() {
          ::remove_internet_radio_station(nameRadio);
          ::broadcastEvent("UpdateListRadio", {})
        })(nameRadio)],
        ["cancel", function() {}]
      ], "ok")
  }

  function onEventUpdateListRadio(params)
  {
    local obj = scene.findObject("groups_list")
    if (!obj)
      return
    fillOptionsList(obj.getValue(), "internetRadioOptions")
    updateInternerRadioButtons()
  }

  function updateInternerRadioButtons()
  {
    local radio = ::get_internet_radio_options()
    local isEnable = radio?.station ? ::is_internet_radio_station_removable(radio.station) : false
    local btnEditRadio = scene.findObject("btn_edit_radio")
    if (btnEditRadio)
      btnEditRadio.enable(isEnable)
    local btnRemoveRadio = scene.findObject("btn_remove_radio")
    if (btnRemoveRadio)
      btnRemoveRadio.enable(isEnable)
  }

  function onRevealNotifications()
  {
    ::scene_msg_box("ask_reveal_notifications",
      null,
      ::loc("mainmenu/btnRevealNotifications/askPlayer"),
      [
        ["yes", ::Callback(resetNotifications, this)],
        ["no", @() null]
      ],
      "yes", { cancel_fn = @() null })
  }

  function resetNotifications()
  {
    foreach (opt in [::USEROPT_SKIP_LEFT_BULLETS_WARNING,
                     ::USEROPT_SKIP_WEAPON_WARNING
                    ])
      ::set_gui_option(opt, false)

    ::save_local_account_settings("skipped_msg", null)
    resetTutorialSkip()
    ::broadcastEvent("ResetSkipedNotifications")

    //To notify player about success, it is only for player,
    // to be sure, that operation is done.
    ::g_popups.add("", ::loc("mainmenu/btnRevealNotifications/onSuccess"))
  }
}

return {
  openOptionsWnd = function(group = null)
  {
    local isInFlight = ::is_in_flight()
    if (isInFlight)
      ::init_options()

    local options = optionsListModule.getOptionsList()

    if (group != null)
      foreach(o in options)
        if (o.name == group)
          o.selected <- true

    local params = {
      titleText = isInFlight ?
        ::is_multiplayer() ? null : ::loc("flightmenu/title")
        : ::loc("mainmenu/btnGameplay")
      optGroups = options
      wndOptionsMode = ::OPTIONS_MODE_GAMEPLAY
      sceneNavBlkName = "gui/options/navOptionsIngame.blk"
    }
    params.cancelFunc <- function()
    {
      ::set_option_gamma(::get_option_gamma(), false)
      for (local i = 0; i < ::SND_NUM_TYPES; i++)
        ::set_sound_volume(i, ::get_sound_volume(i), false)
    }

    return ::handlersManager.loadHandler(::gui_handlers.Options, params)
  }
}
