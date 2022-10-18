from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#implicit-this

from "soundOptions" import *

let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { format } = require("string")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { saveProfile, forceSaveProfile } = require("%scripts/clientState/saveProfile.nut")
let { needUseHangarDof } = require("%scripts/viewUtils/hangarDof.nut")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getFullUnlockDesc } = require("%scripts/unlocks/unlocksViewModule.nut")

let function get_country_by_team(team_index) {
  local countries = null
  if (::mission_settings && ::mission_settings.layout)
    countries = ::get_mission_team_countries(::mission_settings.layout)
  return countries?[team_index] ?? ""
}

::gui_handlers.GenericOptions <- class extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "%gui/options/genericOptions.blk"
  sceneNavBlkName = "%gui/options/navOptionsBack.blk"
  shouldBlurSceneBgFn = needUseHangarDof

  currentContainerName = "generic_options"
  options = null
  optionsConfig = null //config forwarded to ::get_option
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

    this.setSceneTitle(titleText, this.scene, "menu-title")
  }

  function loadOptions(opt, optId)
  {
    let optListObj = this.scene.findObject("optionslist")
    if (!checkObj(optListObj))
      return assert(false, "Error: cant load options when no optionslist object.")

    let container = ::create_options_container(optId, opt, true, columnsRatio, true, optionsConfig)
    this.guiScene.setUpdatesEnabled(false, false);
    optionIdToObjCache.clear()
    this.guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    optionsContainers.append(container.descr)
    this.guiScene.setUpdatesEnabled(true, true)

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
      let objTbl = this.getObj(container.name)
      if (objTbl == null)
        continue

      foreach(_idx, option in container.data)
      {
        if(option.controlType == optionControlType.HEADER ||
           option.controlType == optionControlType.BUTTON)
          continue

        let obj = this.getObj(option.id)
        if (!checkObj(obj))
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

  function onApply(_obj)
  {
    applyOptions(true)
  }

  function applyOptions(v_forcedSave = false)
  {
    forcedSave = v_forcedSave
    if (doApply())
      applyReturn()
  }

  function onApplyOffline(_obj)
  {
    let coopObj = this.getObj("coop_mode")
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
          newDescr = func(this.guiScene, obj, container.data[i])
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
    let option = get_option_by_id(obj?.id)
    if (option)
      ::set_option(option.type, obj.getValue(), option)
    return option
  }

  function updateOptionDelayed(optionType)
  {
    this.guiScene.performDelayed(this, function()
    {
      if (this.isValid())
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
          let newOption = ::get_option(optionType, optionsConfig)
          container.data[idx] = newOption
          updateOptionImpl(newOption)
        }
  }

  function updateOptionImpl(option)
  {
    let obj = this.scene.findObject(option.id)
    if (!checkObj(obj))
      return

    isOptionInUpdate = true
    if (option.controlType == optionControlType.LIST)
    {
      let markup = ::create_option_combobox(option.id, option.items, option.value, null, false)
      this.guiScene.replaceContentFromText(obj, markup, markup.len(), this)
    } else
      obj.setValue(option.value)
    isOptionInUpdate = false
  }

  function onEventQueueChangeState(_p) {
    let opt = findOptionInContainers(::USEROPT_PS4_CROSSPLAY)
    if (opt == null)
      return

    enableOptionRow(opt, !::checkIsInQueue())
  }

  function getOptionObj(option) {
    local obj = optionIdToObjCache?[option.id]
    if (!checkObj(obj))
    {
      obj = this.getObj(option.getTrId())
      if (!checkObj(obj))
        return null
      optionIdToObjCache[option.id] <- obj
    }

    return obj
  }

  function showOptionRow(option, show) {
    let obj = getOptionObj(option)
    if (obj == null)
      return false

    let isInactive = !show || option.controlType == optionControlType.HEADER
    obj.show(show)
    obj.inactive = isInactive ? "yes" : null
    return true
  }

  function enableOptionRow(option, status) {
    let obj = getOptionObj(option)
    if (obj == null)
      return

    obj.enable(status)
  }

  function onNumPlayers(obj)
  {
    if (obj != null)
    {
      let numPlayers = obj.getValue() + 2
      let objPriv = this.getObj("numPrivateSlots")
      if (objPriv != null)
      {
        let numPriv = objPriv.getValue()
        if (numPriv >= numPlayers)
          objPriv.setValue(numPlayers - 1)
      }
    }
  }

  function onNumPrivate(obj)
  {
    if (obj != null)
    {
      let numPriv = obj.getValue()
      let objPlayers = this.getObj("numPlayers")
      if (objPlayers != null)
      {
        let numPlayers = objPlayers.getValue() + 2
        if (numPriv >= numPlayers)
          obj.setValue(numPlayers - 1)
      }
    }
  }

  function onVolumeChange(obj)
  {
    if (obj.id == "volume_music")
      set_sound_volume(SND_TYPE_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_menu_music")
      set_sound_volume(SND_TYPE_MENU_MUSIC, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_sfx")
      set_sound_volume(SND_TYPE_SFX, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_radio")
      set_sound_volume(SND_TYPE_RADIO, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_engine")
      set_sound_volume(SND_TYPE_ENGINE, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_my_engine")
      set_sound_volume(SND_TYPE_MY_ENGINE, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_dialogs")
      set_sound_volume(SND_TYPE_DIALOGS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_in")
      set_sound_volume(SND_TYPE_VOICE_IN, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_voice_out")
      set_sound_volume(SND_TYPE_VOICE_OUT, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_master")
      set_sound_volume(SND_TYPE_MASTER, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_guns")
      set_sound_volume(SND_TYPE_GUNS, obj.getValue() / 100.0, false)
    else if (obj.id == "volume_tinnitus")
      set_sound_volume(SND_TYPE_TINNITUS, obj.getValue() / 100.0, false)
    updateOptionValueTextByObj(obj)
  }

  function onFilterEditBoxActivate(){}

  function onFilterEditBoxChangeValue(){}

  function onFilterEditBoxCancel(){}

  function onPTTChange(obj)
  {
    ::set_option_ptt(::get_option(::USEROPT_PTT).value ? 0 : 1);
    ::showBtn("ptt_buttons_block", obj.getValue(), this.scene)
  }

  function onVoicechatChange(_obj)
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
    let option = get_option_by_id(obj?.id)
    if (option && option.values[obj.getValue()] == TANK_ALT_CROSSHAIR_ADD_NEW)
    {
      let unit = getPlayerCurUnit()
      let success = ::add_tank_alt_crosshair_template()
      let message = success && unit ? format(loc("hud/successUserSight"), unit.name) : loc("hud/failUserSight")

      this.guiScene.performDelayed(this, function()
      {
        if (!this.isValid())
          return

        ::showInfoMsgBox(message)
        updateOption(::USEROPT_TANK_ALT_CROSSHAIR)
      })
    } else
      setOptionValueByControlObj(obj)
  }

  function onChangeCrossPlay(obj) {
    let option = get_option_by_id(obj?.id)
    if (!option)
      return

    let val = obj.getValue()
    if (val == false)
    {
      ::set_option(::USEROPT_PS4_ONLY_LEADERBOARD, true)
      updateOption(::USEROPT_PS4_ONLY_LEADERBOARD)
    }
    let opt = findOptionInContainers(::USEROPT_PS4_ONLY_LEADERBOARD)
    if (opt != null)
      enableOptionRow(opt, val)
  }

  function onChangeCrossNetworkChat(obj)
  {
    let value = obj.getValue()
    if (value == true)
    {
      //Just send notification that value changed
      setCrossNetworkChatValue(null, true, true)
      return
    }

    this.msgBox(
      "crossnetwork_changes_warning",
      loc("guiHints/ps4_crossnetwork_chat"),
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
    if (checkObj(obj))
      obj.setValue(value)

    if (needSendNotification)
    {
      ::broadcastEvent("CrossNetworkChatOptionChanged")

      if (value == false) //Turn off voice if we turn off crossnetwork opt
      {
        let voiceOpt = ::get_option(::USEROPT_VOICE_CHAT)
        if (voiceOpt.value == true && voiceOpt?.cb != null) // onVoicechatChange toggles value
          this[voiceOpt.cb](null)
        else
          ::set_option(::USEROPT_VOICE_CHAT, false)
      }

      let listObj = this.scene.findObject("groups_list")
      if (checkObj(listObj))
      {
        let voiceTabObj = listObj.findObject("voicechat")
        if (checkObj(voiceTabObj))
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
    let res = []
    if (!optionsContainers)
      return res
    foreach (container in optionsContainers)
      for (local i = 0; i < container.data.len(); ++i)
        if (isInArray(container.data[i].type, optTypeList))
          res.append(container.data[i])
    return res
  }

  function findOptionInContainers(optionType)
  {
    if (!optionsContainers)
      return null
    foreach (container in optionsContainers)
    {
      let option = ::u.search(container.data, @(o) o.type == optionType)
      if (option)
        return option
    }
    return null
  }

  function getSceneOptValue(optName)
  {
    let option = get_option_by_id(optName) || ::get_option(optName)
    if (option.values.len() == 0)
      return null
    let obj = this.scene.findObject(option.id)
    let value = obj? obj.getValue() : option.value
    if (value in option.values)
      return option.values[value]
    return option.values[option.value]
  }

  function onGammaChange(obj)
  {
    let gamma = obj.getValue() / 100.0
    ::set_option_gamma(gamma, false)
  }

  function onControls(_obj)
  {
    this.goForward(::gui_start_controls);
  }

  function onProfileChange(_obj)
  {
    this.fillGamercard()
  }

  function onLayoutChange(_obj)
  {
    let countryOption = ::get_option(::USEROPT_MP_TEAM_COUNTRY);
    let cobj = this.getObj(countryOption.id);
    local country = ""
    if(checkObj(cobj))
    {
      country = get_country_by_team(cobj.getValue())
      ::set_option(::USEROPT_MP_TEAM_COUNTRY, cobj.getValue())
    }
    let yearOption = ::get_option(::USEROPT_YEAR)
    let unitsByYears = ::get_number_of_units_by_years(country, yearOption.valuesInt)
    let yearObj = this.getObj(yearOption.id)
    if (!yearObj)
      return;

    assert(yearObj.childrenCount() == yearOption.values.len())
    for (local i = 0; i < yearObj.childrenCount(); i++)
    {
      let line = yearObj.getChild(i);
      if (!line)
        continue;
      let text = line.findObject("option_text");
      if (!text)
        continue;

      local enabled = true
      local tooltip = ""
      if (::current_campaign && country!="")
      {
        let yearId = $"{country}_{yearOption.values[i]}"
        let unlockBlk = ::g_unlocks.getUnlockById(yearId)
        if (unlockBlk)
        {
          enabled = ::is_unlocked_scripted(UNLOCKABLE_YEAR, yearId)
          tooltip = enabled ? "" : getFullUnlockDesc(::build_conditions_config(unlockBlk))
        }
      }

      line.enable(enabled)
      line.tooltip = tooltip
      let year = yearOption.valuesInt[i]
      text.setValue(format(loc("options/year_text"), year,
        unitsByYears[$"year{year}"], unitsByYears[$"beforeyear{year}"]))
    }

    let value = yearObj.getValue();
    yearObj.setValue(value >= 0 ? value : 0);
  }

  function getOptValue(optName, return_default_when_no_obj = true)
  {
    let option = ::get_option(optName)
    let obj = this.scene.findObject(option.id)
    if (!obj && !return_default_when_no_obj)
      return null
    let value = obj? obj.getValue() : option.value
    if (option.controlType == optionControlType.LIST)
      return option.values[value]
    return value
  }

  function update_internet_radio(obj)
  {
    let option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)

    ::update_volume_for_music();
    this.updateInternerRadioButtons()
  }

  function onMissionCountriesType(_obj)
  {
    checkMissionCountries()
  }

  function checkMissionCountries()
  {
    if (getTblValue("isEventRoom", optionsConfig, false))
      return

    let optList = find_options_in_containers([::USEROPT_BIT_COUNTRIES_TEAM_A, ::USEROPT_BIT_COUNTRIES_TEAM_B])
    if (!optList.len())
      return

    let countriesType = getOptValue(::USEROPT_MISSION_COUNTRIES_TYPE)
    foreach(option in optList)
    {
      let show = countriesType == misCountries.CUSTOM
                   || (countriesType == misCountries.SYMMETRIC && option.type == ::USEROPT_BIT_COUNTRIES_TEAM_A)
      showOptionRow(option, show)
    }
  }

  function onUseKillStreaks(_obj)
  {
    checkAllowedUnitTypes()
  }

  function checkAllowedUnitTypes()
  {
    let option = findOptionInContainers(::USEROPT_BIT_UNIT_TYPES)
    if (!option)
      return
    let optionTrObj = this.getObj(option.getTrId())
    if (!checkObj(optionTrObj))
      return

    let missionBlk = ::get_mission_meta_info(optionsConfig?.missionName ?? "")
    let useKillStreaks = missionBlk && ::is_skirmish_with_killstreaks(missionBlk) &&
      getOptValue(::USEROPT_USE_KILLSTREAKS, false)
    let allowedUnitTypesMask  = ::get_mission_allowed_unittypes_mask(missionBlk, useKillStreaks)

    foreach (unitType in unitTypes.types)
    {
      if (unitType == unitTypes.INVALID || !unitType.isPresentOnMatching)
        continue
      let isShow = !!(allowedUnitTypesMask & unitType.bit)
      let itemObj = optionTrObj.findObject("bit_" + unitType.tag)
      if (!checkObj(itemObj))
        continue
      itemObj.show(isShow)
      itemObj.enable(isShow)
    }

    let itemObj = optionTrObj.findObject("text_after")
      if (checkObj(itemObj))
        itemObj.show(useKillStreaks)
  }

  function onOptionBotsAllowed(_obj)
  {
    checkBotsOption()
  }

  function checkBotsOption()
  {
    let isBotsAllowed = getOptValue(::USEROPT_IS_BOTS_ALLOWED, false)
    if (isBotsAllowed == null) //no such option in current options list
      return

    let optList = find_options_in_containers([::USEROPT_USE_TANK_BOTS,
      ::USEROPT_USE_SHIP_BOTS])
    foreach(option in optList)
      showOptionRow(option, isBotsAllowed)
  }

  function updateOptionValueTextByObj(obj) //dagui scene callback
  {
    let option = get_option_by_id(obj?.id)
    if (option)
      updateOptionValueText(option, obj.getValue())
  }

  function updateOptionValueText(option, value)
  {
    let obj = this.scene.findObject("value_" + option.id)
    if (checkObj(obj))
      obj.setValue(option.getValueLocText(value))
  }

  function onMissionChange(_obj) {}
  function onSectorChange(_obj) {}
  function onYearChange(_obj) {}
  function onGamemodeChange(_obj) {}
  function onOptionsListboxDblClick(_obj) {}
  function onGroupSelect(_obj) {}
  function onDifficultyChange(_obj) {}
}

::gui_handlers.GenericOptionsModal <- class extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "%gui/options/navOptionsBack.blk"
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
      ::move_mouse_on_obj(this.scene.findObject("btn_apply"))
  }

  function initNavigation()
  {
    let handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = this.scene.findObject("control_navigation")
        onSelectCb = Callback(doNavigateToSection, this)
        panelWidth        = "0.4@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "1@buttonHeight"
      })
    this.registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function doNavigateToSection(navItem)
  {
    let objTbl = this.scene.findObject(this.currentContainerName)
    if ( ! checkObj(objTbl))
      return

    local trId = ""
    foreach(_idx, option in getCurrentOptionsList())
    {
      if(option.controlType == optionControlType.HEADER
        && option.id == navItem.id)
      {
        trId = option.getTrId()
        break
      }
    }
    if(::u.isEmpty(trId))
      return

    let rowObj = objTbl.findObject(trId)
    if (checkObj(rowObj))
      rowObj.scrollToView(true)
  }

  function resetNavigation()
  {
    if(navigationHandlerWeak)
      navigationHandlerWeak.setNavItems([])
  }

  function onTblSelect(_obj)
  {
    checkCurrentNavigationSection()

    if (::show_console_buttons)
      return

    let option = getSelectedOption()
    if (option.controlType == optionControlType.EDITBOX)
      ::select_editbox(this.getObj(option.id))
  }

  function checkCurrentNavigationSection()
  {
    let navItems = navigationHandlerWeak.getNavItems()
    if(navItems.len() < 2)
      return

    let currentOption = getSelectedOption()
    if( ! currentOption)
      return

    let currentHeader = getOptionHeader(currentOption)
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
    let objTbl = this.scene.findObject(this.currentContainerName)
    if (!checkObj(objTbl))
      return null

    let idx = objTbl.getValue()
    if (idx < 0 || objTbl.childrenCount() <= idx)
      return null

    let activeOptionsList = getCurrentOptionsList()
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
    let containerName = this.currentContainerName
    let container = ::u.search(this.optionsContainers, @(c) c.name == containerName)
    return getTblValue("data", container, [])
  }

  function setNavigationItems()
  {
    headersToOptionsList.clear();
    let headersItems = []
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
      this.applyOptions(true)
    else
    {
      base.goBack()
      this.restoreMainOptions()
    }
  }

  function applyReturn()
  {
    if (!this.applyFunc)
      this.restoreMainOptions()
    base.applyReturn()
  }
}
