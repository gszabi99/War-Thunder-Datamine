local unitTypes = require("scripts/unit/unitTypesList.nut")
local { saveProfile, forceSaveProfile } = require("scripts/clientState/saveProfile.nut")
local { needUseHangarDof } = require("scripts/viewUtils/hangarDof.nut")

class ::gui_handlers.GenericOptions extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/options/genericOptions.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  currentContainerName = "generic_options"
  options = null
  optionsConfig = null //config forwarded to get_option
  optionsContainers = null
  applyFunc = null
  cancelFunc = null
  forcedSave = false

  columnsRatio = 0.5 //0..1
  titleText = null

  owner = null

  optionIdToObjCache = {}

  isOptionInUpdate = false

  function initScreen()
  {
    if (!optionsContainers)
      optionsContainers = []
    if (options)
      loadOptions(options, currentContainerName)

    setSceneTitle(titleText, scene, "menu-title")
  }

  function loadOptions(opt, optId)
  {
    local optListObj = scene.findObject("optionslist")
    if (!::checkObj(optListObj))
      return ::dagor.assertf(false, "Error: cant load options when no optionslist object.")

    local container = ::create_options_container(optId, opt, true, columnsRatio, true, optionsConfig)
    guiScene.setUpdatesEnabled(false, false);
    optionIdToObjCache.clear()
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    optionsContainers.append(container.descr)
    guiScene.setUpdatesEnabled(true, true)

    updateLinkedOptions()
  }

  function updateLinkedOptions()
  {
    onLayoutChange(null)
    checkMissionCountries()
    checkAllowedUnitTypes()
    checkBotsOption()
  }

  function applyReturn()
  {
    if (applyFunc != null)
      applyFunc()
    else
      base.goBack()
  }

  function doApply()
  {
    foreach (container in optionsContainers)
    {
      local objTbl = getObj(container.name)
      if (objTbl == null)
        continue

      foreach(idx, option in container.data)
      {
        if(option.controlType == optionControlType.HEADER ||
           option.controlType == optionControlType.BUTTON)
          continue

        local obj = getObj(option.id)
        if (!::checkObj(obj))
        {
          ::script_net_assert_once("Bad option",
            "Error: not found obj for option " + option.id + ", type = " + option.type)
          continue
        }

        if (!::set_option(option.type, obj.getValue(), option))
          return false
      }
    }

    if (forcedSave)
      forceSaveProfile()
    else
      saveProfile()
    forcedSave = false
    return true
  }

  function goBack()
  {
    if (cancelFunc != null)
      cancelFunc()
    base.goBack()
  }

  function onApply(obj)
  {
    applyOptions(true)
  }

  function applyOptions(_forcedSave = false)
  {
    forcedSave = _forcedSave
    if (doApply())
      applyReturn()
  }

  function onApplyOffline(obj)
  {
    local coopObj = getObj("coop_mode")
    if (coopObj) coopObj.setValue(2)
    applyOptions()
  }

  function updateOptionDescr(obj, func) //!!FIXME: use updateOption instead
  {
    local newDescr = null
    foreach (container in optionsContainers)
    {
      for (local i = 0; i < container.data.len(); ++i)
      {
        if (container.data[i].id == obj?.id)
        {
          newDescr = func(guiScene, obj, container.data[i])
          break
        }
      }

      if (newDescr != null)
        break
    }

    if (newDescr != null)
    {
      foreach (container in optionsContainers)
      {
        for (local i = 0; i < container.data.len(); ++i)
        {
          if (container.data[i].id == newDescr.id)
          {
            container.data[i] = newDescr
            return
          }
        }
      }
    }
  }

  function setOptionValueByControlObj(obj)
  {
    local option = get_option_by_id(obj?.id)
    if (option)
      ::set_option(option.type, obj.getValue(), option)
    return option
  }

  function updateOptionDelayed(optionType)
  {
    guiScene.performDelayed(this, function()
    {
      if (isValid())
        updateOption(optionType)
    })
  }

  function updateOption(optionType)
  {
    if (!optionsContainers)
      return null
    foreach (container in optionsContainers)
      foreach(idx, option in container.data)
        if (option.type == optionType)
        {
          local newOption = ::get_option(optionType, optionsConfig)
          container.data[idx] = newOption
          updateOptionImpl(newOption)
        }
  }

  function updateOptionImpl(option)
  {
    local obj = scene.findObject(option.id)
    if (!::check_obj(obj))
      return

    isOptionInUpdate = true
    if (option.controlType == optionControlType.LIST)
    {
      local markup = ::create_option_combobox(option.id, option.items, option.value, null, false)
      guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    } else
      obj.setValue(option.value)
    isOptionInUpdate = false
  }

  function onEventQueueChangeState(p) {
    local opt = findOptionInContainers(::USEROPT_PS4_CROSSPLAY)
    if (opt == null)
      return

    enableOptionRow(opt, !::checkIsInQueue())
  }

  function getOptionObj(option) {
    local obj = optionIdToObjCache?[option.id]
    if (!::check_obj(obj))
    {
      obj = getObj(option.getTrId())
      if (!::check_obj(obj))
        return null
      optionIdToObjCache[option.id] <- obj
    }

    return obj
  }

  function showOptionRow(option, show) {
    local obj = getOptionObj(option)
    if (obj == null)
      return false

    local isInactive = !show || option.controlType == optionControlType.HEADER
    obj.show(show)
    obj.inactive = isInactive ? "yes" : null
    return true
  }

  function enableOptionRow(option, status) {
    local obj = getOptionObj(option)
    if (obj == null)
      return

    obj.enable(status)
  }

  function onNumPlayers(obj)
  {
    if (obj != null)
    {
      local numPlayers = obj.getValue() + 2
      local objPriv = getObj("numPrivateSlots")
      if (objPriv != null)
      {
        local numPriv = objPriv.getValue()
        if (numPriv >= numPlayers)
          objPriv.setValue(numPlayers - 1)
      }
    }
  }

  function onNumPrivate(obj)
  {
    if (obj != null)
    {
      local numPriv = obj.getValue()
      local objPlayers = getObj("numPlayers")
      if (objPlayers != null)
      {
        local numPlayers = objPlayers.getValue() + 2
        if (numPriv >= numPlayers)
          obj.setValue(numPlayers - 1)
      }
    }
  }

  function onVolumeChange(obj)
  {
    if (obj.id == "volume_music")
      ::set_sound_volume(::SND_TYPE_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_menu_music")
      ::set_sound_volume(::SND_TYPE_MENU_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_sfx")
      ::set_sound_volume(::SND_TYPE_SFX, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_radio")
      ::set_sound_volume(::SND_TYPE_RADIO, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_engine")
      ::set_sound_volume(::SND_TYPE_ENGINE, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_my_engine")
      ::set_sound_volume(::SND_TYPE_MY_ENGINE, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_dialogs")
      ::set_sound_volume(::SND_TYPE_DIALOGS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_in")
      ::set_sound_volume(::SND_TYPE_VOICE_IN, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_out")
      ::set_sound_volume(::SND_TYPE_VOICE_OUT, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_master")
      ::set_sound_volume(::SND_TYPE_MASTER, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_guns")
      ::set_sound_volume(::SND_TYPE_GUNS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_tinnitus")
      ::set_sound_volume(::SND_TYPE_TINNITUS, obj.getValue() / 100.0, false)
    updateOptionValueTextByObj(obj)
  }

  function onFilterEditBoxActivate(){}

  function onFilterEditBoxChangeValue(){}

  function onFilterEditBoxCancel(){}

  function onPTTChange(obj)
  {
    ::set_option_ptt(get_option(::USEROPT_PTT).value ? 0 : 1);
    ::showBtn("ptt_buttons_block", obj.getValue(), scene)
  }

  function onVoicechatChange(obj)
  {
    ::set_option(::USEROPT_VOICE_CHAT, !::get_option(::USEROPT_VOICE_CHAT).value)
    ::broadcastEvent("VoiceChatOptionUpdated")
  }

  function onInstantOptionApply(obj)
  {
    setOptionValueByControlObj(obj)
  }

  function onTankAltCrosshair(obj)
  {
    if (isOptionInUpdate)
      return
    local option = get_option_by_id(obj?.id)
    if (option && option.values[obj.getValue()] == TANK_ALT_CROSSHAIR_ADD_NEW)
    {
      local unit = ::get_player_cur_unit()
      local success = ::add_tank_alt_crosshair_template()
      local message = success && unit ? ::format(::loc("hud/successUserSight"), unit.name) : ::loc("hud/failUserSight")

      guiScene.performDelayed(this, function()
      {
        if (!isValid())
          return

        ::showInfoMsgBox(message)
        updateOption(::USEROPT_TANK_ALT_CROSSHAIR)
      })
    } else
      setOptionValueByControlObj(obj)
  }

  function onChangeCrossPlay(obj) {
    local option = get_option_by_id(obj?.id)
    if (!option)
      return

    local val = obj.getValue()
    if (val == false)
    {
      ::set_option(::USEROPT_PS4_ONLY_LEADERBOARD, true)
      updateOption(::USEROPT_PS4_ONLY_LEADERBOARD)
    }
    local opt = findOptionInContainers(::USEROPT_PS4_ONLY_LEADERBOARD)
    if (opt != null)
      enableOptionRow(opt, val)
  }

  function onChangeCrossNetworkChat(obj)
  {
    local value = obj.getValue()
    if (value == true)
    {
      //Just send notification that value changed
      setCrossNetworkChatValue(null, true, true)
      return
    }

    msgBox(
      "crossnetwork_changes_warning",
      ::loc("guiHints/ps4_crossnetwork_chat"),
      [
        ["ok", @() setCrossNetworkChatValue(null, false, true)], //Send notification of changed value
        ["no", @() setCrossNetworkChatValue(obj, true, false)] //Silently return value
      ],
      "no",
      {cancel_fn = @() setCrossNetworkChatValue(obj, true, false)}
    )
  }

  function setCrossNetworkChatValue(obj, value, needSendNotification = false)
  {
    if (::check_obj(obj))
      obj.setValue(value)

    if (needSendNotification)
    {
      ::broadcastEvent("CrossNetworkChatOptionChanged")

      if (value == false) //Turn off voice if we turn off crossnetwork opt
      {
        local voiceOpt = ::get_option(::USEROPT_VOICE_CHAT)
        if (voiceOpt.value == true && voiceOpt?.cb != null) // onVoicechatChange toggles value
          this[voiceOpt.cb](null)
        else
          ::set_option(::USEROPT_VOICE_CHAT, false)
      }

      local listObj = scene.findObject("groups_list")
      if (::check_obj(listObj))
      {
        local voiceTabObj = listObj.findObject("voicechat")
        if (::check_obj(voiceTabObj))
          voiceTabObj.inactive = value? "no" : "yes"
      }
    }
  }

  function get_option_by_id(id)
  {
    local res = null;
    foreach (container in optionsContainers)
      for (local i = 0; i < container.data.len(); ++i)
        if (container.data[i].id == id)
          res = container.data[i];
    return res;
  }

  function find_options_in_containers(optTypeList)
  {
    local res = []
    if (!optionsContainers)
      return res
    foreach (container in optionsContainers)
      for (local i = 0; i < container.data.len(); ++i)
        if (::isInArray(container.data[i].type, optTypeList))
          res.append(container.data[i])
    return res
  }

  function findOptionInContainers(optionType)
  {
    if (!optionsContainers)
      return null
    foreach (container in optionsContainers)
    {
      local option = ::u.search(container.data, @(o) o.type == optionType)
      if (option)
        return option
    }
    return null
  }

  function getSceneOptValue(optName)
  {
    local option = get_option_by_id(optName) || ::get_option(optName)
    local obj = scene.findObject(option.id)
    local value = obj? obj.getValue() : option.value
    if (value in option.values)
      return option.values[value]
    return option.values[option.value]
  }

  function onGammaChange(obj)
  {
    local gamma = obj.getValue() / 100.0
    ::set_option_gamma(gamma, false)
  }

  function onControls(obj)
  {
    goForward(::gui_start_controls);
  }

  function onProfileChange(obj)
  {
    fillGamercard()
  }

  function onLayoutChange(obj)
  {
    local countryOption = get_option(::USEROPT_MP_TEAM_COUNTRY);
    local cobj = getObj(countryOption.id);
    local country = ""
    if(::checkObj(cobj))
    {
      country = get_country_by_team(cobj.getValue())
      ::set_option(::USEROPT_MP_TEAM_COUNTRY, cobj.getValue())
    }
    local unitsByYears = get_number_of_units_by_years(country);
    local yearObj = getObj(get_option(::USEROPT_YEAR).id);
    if (!yearObj)
      return;

    dagor.assert(yearObj.childrenCount() == ::unit_year_selection_max - ::unit_year_selection_min + 1);
    for (local i = 0; i < yearObj.childrenCount(); i++)
    {
      local line = yearObj.getChild(i);
      if (!line)
        continue;
      local text = line.findObject("option_text");
      if (!text)
        continue;

      local enabled = true
      local tooltip = ""
      if (::current_campaign && country!="")
      {
        local yearId = country + "_" + ::get_option(::USEROPT_YEAR).values[i]
        local unlockBlk = ::g_unlocks.getUnlockById(yearId)
        if (!unlockBlk)
          ::dagor.assertf(false, "Error: not found year unlock = " + yearId)
        else
        {
          local blk = build_conditions_config(unlockBlk)
          ::build_unlock_desc(blk)
          enabled = ::is_unlocked_scripted(::UNLOCKABLE_YEAR, yearId)
          tooltip = enabled? "" : blk.text
        }
      }

      line.enable(enabled)
      line.tooltip = tooltip
      local year = ::unit_year_selection_min + i;
      local parameter1 = "year" + year;
      local units1 = (parameter1 in unitsByYears) ? unitsByYears[parameter1] : 0;
      local parameter2 = "beforeyear" + year;
      local units2 = (parameter2 in unitsByYears) ? unitsByYears[parameter2] : 0;
      local optionText = format(::loc("options/year_text"), year, units1, units2);
      text.setValue(optionText);
    }

    local value = yearObj.getValue();
    yearObj.setValue(value >= 0 ? value : 0);
  }

  function getOptValue(optName, return_default_when_no_obj = true)
  {
    local option = ::get_option(optName)
    local obj = scene.findObject(option.id)
    if (!obj && !return_default_when_no_obj)
      return null
    local value = obj? obj.getValue() : option.value
    if (option.controlType == optionControlType.LIST)
      return option.values[value]
    return value
  }

  function update_internet_radio(obj)
  {
    local option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)

    ::update_volume_for_music();
    updateInternerRadioButtons()
  }

  function onMissionCountriesType(obj)
  {
    checkMissionCountries()
  }

  function checkMissionCountries()
  {
    if (::getTblValue("isEventRoom", optionsConfig, false))
      return

    local optList = find_options_in_containers([::USEROPT_BIT_COUNTRIES_TEAM_A, ::USEROPT_BIT_COUNTRIES_TEAM_B])
    if (!optList.len())
      return

    local countriesType = getOptValue(::USEROPT_MISSION_COUNTRIES_TYPE)
    foreach(option in optList)
    {
      local show = countriesType == misCountries.CUSTOM
                   || (countriesType == misCountries.SYMMETRIC && option.type == ::USEROPT_BIT_COUNTRIES_TEAM_A)
      showOptionRow(option, show)
    }
  }

  function onUseKillStreaks(obj)
  {
    checkAllowedUnitTypes()
  }

  function checkAllowedUnitTypes()
  {
    local option = findOptionInContainers(::USEROPT_BIT_UNIT_TYPES)
    if (!option)
      return
    local optionTrObj = getObj(option.getTrId())
    if (!::check_obj(optionTrObj))
      return

    local missionBlk = ::get_mission_meta_info(optionsConfig?.missionName ?? "")
    local useKillStreaks = missionBlk && ::is_skirmish_with_killstreaks(missionBlk) &&
      getOptValue(::USEROPT_USE_KILLSTREAKS, false)
    local allowedUnitTypesMask  = ::get_mission_allowed_unittypes_mask(missionBlk, useKillStreaks)

    foreach (unitType in unitTypes.types)
    {
      if (unitType == unitTypes.INVALID || !unitType.isPresentOnMatching)
        continue
      local isShow = !!(allowedUnitTypesMask & unitType.bit)
      local itemObj = optionTrObj.findObject("bit_" + unitType.tag)
      if (!::check_obj(itemObj))
        continue
      itemObj.show(isShow)
      itemObj.enable(isShow)
    }

    local itemObj = optionTrObj.findObject("text_after")
      if (::check_obj(itemObj))
        itemObj.show(useKillStreaks)
  }

  function onOptionBotsAllowed(obj)
  {
    checkBotsOption()
  }

  function checkBotsOption()
  {
    local isBotsAllowed = getOptValue(::USEROPT_IS_BOTS_ALLOWED, false)
    if (isBotsAllowed == null) //no such option in current options list
      return

    local optList = find_options_in_containers([::USEROPT_USE_TANK_BOTS,
      ::USEROPT_USE_SHIP_BOTS, ::USEROPT_BOTS_RANKS])
    foreach(option in optList)
      showOptionRow(option, isBotsAllowed)
  }

  function updateOptionValueTextByObj(obj) //dagui scene callback
  {
    local option = get_option_by_id(obj?.id)
    if (option)
      updateOptionValueText(option, obj.getValue())
  }

  function updateOptionValueText(option, value)
  {
    local obj = scene.findObject("value_" + option.id)
    if (::check_obj(obj))
      obj.setValue(option.getValueLocText(value))
  }

  function onMissionChange(obj) {}
  function onSectorChange(obj) {}
  function onYearChange(obj) {}
  function onGamemodeChange(obj) {}
  function onOptionsListboxDblClick(obj) {}
  function onGroupSelect(obj) {}
  function onDifficultyChange(obj) {}
}

class ::gui_handlers.GenericOptionsModal extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  multipleInstances = true

  applyAtClose = true
  needMoveMouseOnButtonApply = true

  navigationHandlerWeak = null
  headersToOptionsList = {}

  function initScreen()
  {
    base.initScreen()

    initNavigation()

    if (needMoveMouseOnButtonApply)
      ::move_mouse_on_obj(scene.findObject("btn_apply"))
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.4@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "1@buttonHeight"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function doNavigateToSection(navItem)
  {
    local objTbl = scene.findObject(currentContainerName)
    if ( ! ::check_obj(objTbl))
      return

    local trId = ""
    local index = 0
    foreach(idx, option in getCurrentOptionsList())
    {
      if(option.controlType == optionControlType.HEADER
        && option.id == navItem.id)
      {
        trId = option.getTrId()
        index = idx
        break
      }
    }
    if(::u.isEmpty(trId))
      return

    local rowObj = objTbl.findObject(trId)
    if (::check_obj(rowObj))
      rowObj.scrollToView(true)
  }

  function resetNavigation()
  {
    if(navigationHandlerWeak)
      navigationHandlerWeak.setNavItems([])
  }

  function onTblSelect(obj)
  {
    checkCurrentNavigationSection()

    if (::show_console_buttons)
      return

    local option = getSelectedOption()
    if (option.controlType == optionControlType.EDITBOX)
      ::select_editbox(getObj(option.id))
  }

  function checkCurrentNavigationSection()
  {
    local navItems = navigationHandlerWeak.getNavItems()
    if(navItems.len() < 2)
      return

    local currentOption = getSelectedOption()
    if( ! currentOption)
      return

    local currentHeader = getOptionHeader(currentOption)
    if( ! currentHeader)
      return

    foreach(navItem in navItems)
    {
      if(navItem.id == currentHeader.id)
      {
        navigationHandlerWeak.setCurrentItem(navItem)
        return
      }
    }
  }

  function getSelectedOption()
  {
    local objTbl = scene.findObject(currentContainerName)
    if (!::check_obj(objTbl))
      return null

    local idx = objTbl.getValue()
    if (idx < 0 || objTbl.childrenCount() <= idx)
      return null

    local activeOptionsList = getCurrentOptionsList()
      .filter(@(option) option.controlType != optionControlType.HEADER)
    return activeOptionsList?[idx]
  }

  function getOptionHeader(option)
  {
    foreach(header, optionsArray in headersToOptionsList)
      if(optionsArray.indexof(option) != null)
        return header
    return null
  }

  function getCurrentOptionsList()
  {
    local containerName = currentContainerName
    local container = ::u.search(optionsContainers, @(c) c.name == containerName)
    return ::getTblValue("data", container, [])
  }

  function setNavigationItems()
  {
    headersToOptionsList.clear();
    local headersItems = []
    local lastHeader = null
    foreach(option in getCurrentOptionsList())
    {
      if(option.controlType == optionControlType.HEADER)
      {
        lastHeader = option
        headersToOptionsList[lastHeader] <- []
        headersItems.append({id = option.id, text = option.getTitle()})
      }
      else if (lastHeader != null)
        headersToOptionsList[lastHeader].append(option)
    }

    if (navigationHandlerWeak)
    {
      navigationHandlerWeak.setNavItems(headersItems)
      checkCurrentNavigationSection()
    }
  }

  function goBack()
  {
    if (applyAtClose)
      applyOptions(true)
    else
    {
      base.goBack()
      restoreMainOptions()
    }
  }

  function applyReturn()
  {
    if (!applyFunc)
      restoreMainOptions()
    base.applyReturn()
  }
}
