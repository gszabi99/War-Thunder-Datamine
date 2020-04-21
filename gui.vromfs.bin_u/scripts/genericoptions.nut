local { clearBorderSymbols } = require("std/string.nut")
local fxOptions = require("scripts/options/fxOptions.nut")
local { setUnitLastBullets,
        isBulletGroupActive } = require("scripts/weaponry/bulletsInfo.nut")
local { getLastWeapon,
        setLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")
local crossplayModule = require("scripts/social/crossplay.nut")

::generic_options <- null

class ::gui_handlers.GenericOptions extends ::gui_handlers.BaseGuiHandlerWT
{
  sceneBlkName = "gui/options/genericOptions.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  shouldBlurSceneBg = true

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
  lastWeaponCache = null
  lastBulletsCache = null

  function initScreen()
  {
    ::generic_options = this //?? FIX ME - need to remove this

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

    local container = ::create_options_container(optId, opt, true, true, columnsRatio, true, true, optionsConfig)
    guiScene.setUpdatesEnabled(false, false);
    optionIdToObjCache.clear()
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)
    optionsContainers.append(container.descr)
    guiScene.setUpdatesEnabled(true, true)

    updateLinkedOptions()
    onHintUpdate()
  }

  function getMainFocusObj()
  {
    return currentContainerName
  }

  function updateLinkedOptions()
  {
    checkBulletsRows()
    checkRocketDisctanceFuseRow()
    checkBombActivationTimeRow()
    checkVehicleModificationRow()
    checkDepthChargeActivationTimeRow()
    checkMineDepthRow()
    onLayoutChange(null)
    checkMissionCountries()
    checkAllowedUnitTypes()
    checkBotsOption()
    updateTripleAerobaticsSmokeOptions()
    updateVerticalTargetingOption()
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
        if(option.controlType == optionControlType.HEADER)
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

    ::save_profile_offline_limited(forcedSave)
    forcedSave = false
    return true
  }

/*  function afterSave()
  {
    if (::generic_options != null)
      ::generic_options.applyReturn()
  } */

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

  function onShowInfo(obj)
  {
    // foreach (container in optionsContainers)
    // {
      // local objTbl = getObj(container.name)
      // if (objTbl == null)
        // continue
      // local curRow = objTbl.cur_row.tointeger()
      // if (curRow >= 0 && curRow < container.data.len())
      // {
        // infoBox(container.data[curRow].hint)
      // }

      // break // HACK
    // }
  }

  function onHintUpdate()
  {
    //disabled
    /*foreach (container in optionsContainers)
    {
      local objTbl = getObj(container.name)
      local objHint = getObj("hint_box")
      if (objTbl == null || objHint == null)
        continue

      local curRow = objTbl.cur_row.tointeger()
      if (curRow >= 0 && curRow < container.data.len())
      {
        local hint = null;
        if ("hints" in container.data[curRow])
        {
          local objItemId = container.data[curRow].id
          local objItem = getObj(objItemId)
          if (objItem != null)
            hint = ::loc(container.data[curRow].hints[objItem.getValue()])
        }
        else
          hint = ::loc(container.data[curRow].hint)

        if (hint != null)
        {
          local objItemRowId = container.data[curRow].id + "_tr"
          local objItemRow = getObj(objItemRowId)
          if (objItemRow != null)
            objItemRow.tooltip = hint;

          objHint.setValue(hint);
        }
      }

      break
    }*/
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

  function onWeaponOptionUpdate(obj)
  {
    if (::generic_options != null)
    {
      local guiScene = ::get_gui_scene();
      guiScene.performDelayed(this, function(){ ::generic_options.onHintUpdate(); });
    }
  }

  function onMyWeaponOptionUpdate(obj)
  {
    local option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    onWeaponOptionUpdate(obj)
    if ("hints" in option)
      obj.tooltip = option.hints[ obj.getValue() ]
    else if ("hint" in option)
      obj.tooltip = ::g_string.stripTags( ::loc(option.hint, "") )
    checkBulletsRows()
    checkRocketDisctanceFuseRow()
    checkBombActivationTimeRow()
    checkDepthChargeActivationTimeRow()
    checkMineDepthRow()
  }

  function checkBulletsRows()
  {
    if (typeof(::aircraft_for_weapons) != "string")
      return
    local air = ::getAircraftByName(::aircraft_for_weapons)
    if (!air)
      return

    for (local groupIndex = 0; groupIndex < air.unitType.bulletSetsQuantity; groupIndex++)
    {
      local show = isBulletGroupActive(air, groupIndex)
      if (!showOptionRow(get_option(::USEROPT_BULLETS0 + groupIndex), show))
        break
    }
  }

  function checkRocketDisctanceFuseRow()
  {
    local option = findOptionInContainers(::USEROPT_ROCKET_FUSE_DIST)
    if (!option)
      return
    local unit = ::getAircraftByName(::aircraft_for_weapons)
    showOptionRow(option,
      !!unit && unit.getAvailableSecondaryWeapons().hasRocketDistanceFuse)
  }

  function checkBombActivationTimeRow()
  {
    local option = findOptionInContainers(::USEROPT_BOMB_ACTIVATION_TIME)
    if (!option)
      return
    local unit = ::getAircraftByName(::aircraft_for_weapons)
    showOptionRow(option,
      !!unit && unit.getAvailableSecondaryWeapons().hasBombs)
  }

  function setLastBulletsCache(unit)
  {
    lastBulletsCache = []
    for (local groupIndex = 0; groupIndex < unit.unitType.bulletSetsQuantity; groupIndex++) {
      local bulletOptId = ::USEROPT_BULLETS0 + groupIndex
      local bulletOpt = ::get_option(bulletOptId)
      local bulletValue = bulletOpt?.value
      if (bulletValue)
      {
        local bulletName = bulletOpt.values?[bulletValue]
        if (bulletName != null)
          lastBulletsCache.append({
            groupIndex = groupIndex,
            bulletName = bulletName
          })
      }
    }
  }

  function setUnitLastBulletsFromCache()
  {
    if (lastBulletsCache?.len())
      foreach (inst in lastBulletsCache)
        setUnitLastBullets(unit, inst.groupIndex, inst.bulletName)
  }

  function onUserModificationsUpdate(obj) {
    local option = get_option_by_id(obj?.id)
    if (!option)
      return

    if (option.value != obj.getValue()) {
      guiScene.performDelayed(this, function() {
        ::set_option(option.type, obj.getValue())
        updateOption(option.type)
      })
    }

    local unit = ::getAircraftByName(::aircraft_for_weapons)
    if (!unit)
      return

    if (!obj.getValue()) {//default mod option selected
      lastWeaponCache = getLastWeapon(unit.name)
      setLastBulletsCache(unit)
      local defaultWeap = unit.getDefaultWeapon()
      setLastWeapon(unit.name, defaultWeap)

      local defaultBulletIdx = 0
      for (local groupIndex = 0; groupIndex < unit.unitType.bulletSetsQuantity; groupIndex++) {
        local bulletOptId = ::USEROPT_BULLETS0 + groupIndex
        local bulletOpt = ::get_option(bulletOptId)
        local bulletValue = bulletOpt?.value
        if (bulletValue == null || bulletValue == defaultBulletIdx)
          continue
        local bulletName = bulletOpt.values?[defaultBulletIdx]
        if (bulletName != null) {
            setUnitLastBullets(unit, groupIndex, bulletName)
        }
      }
    }
    else//current mod option selected
    {
      if (lastWeaponCache)
        setLastWeapon(unit.name, lastWeaponCache)
      setUnitLastBulletsFromCache()
    }

    ::enable_bullets_modifications(::aircraft_for_weapons)
    ::enable_current_modifications(::aircraft_for_weapons)
  }

  function checkVehicleModificationRow() {
    local option = findOptionInContainers(::USEROPT_MODIFICATIONS)
    if (option && !option.value) {
      local unit = ::getAircraftByName(::aircraft_for_weapons)

      local referenceWeap = unit.getDefaultWeapon() == getLastWeapon(unit.name)

      if (referenceWeap) {
        local defaultBulletIdx = 0
        for (local groupIndex = 0; groupIndex < unit.unitType.bulletSetsQuantity; groupIndex++) {
          local bulletValue = ::get_option(::USEROPT_BULLETS0 + groupIndex)?.value ?? defaultBulletIdx
          if (bulletValue != defaultBulletIdx) {
            referenceWeap = false
            break
          }
        }
      }

      if (!referenceWeap) {
        guiScene.performDelayed(this, function() {
          ::set_option(option.type, 1)
          updateOption(option.type)
        })
      }
    }
  }

  function checkDepthChargeActivationTimeRow()
  {
    local option = findOptionInContainers(::USEROPT_DEPTHCHARGE_ACTIVATION_TIME)
    if (!option)
      return

    local unit = ::getAircraftByName(::aircraft_for_weapons)
    showOptionRow(option, unit?.isDepthChargeAvailable?()
      && unit.getAvailableSecondaryWeapons().hasDepthCharges)
  }

  function checkMineDepthRow()
  {
    local option = findOptionInContainers(::USEROPT_MINE_DEPTH)
    if (!option)
      return

    local unit = ::getAircraftByName(::aircraft_for_weapons)
    showOptionRow(option, unit?.isMinesAvailable?()
      && unit.getAvailableSecondaryWeapons().hasMines)
  }

  function onEventUnitWeaponChanged(p)
  {
    checkRocketDisctanceFuseRow()
    checkBombActivationTimeRow()
    checkVehicleModificationRow()
    checkDepthChargeActivationTimeRow()
    checkMineDepthRow()
  }

  function onEventBulletsGroupsChanged(p) {
    checkVehicleModificationRow()
  }

  function onEventQueueChangeState(p) {
    local opt = findOptionInContainers(::USEROPT_PS4_CROSSPLAY)
    if (opt == null)
      return

    enableOptionRow(opt, !::checkIsInQueue())
    delayedRestoreFocus()
  }

  function onTripleAerobaticsSmokeSelected(obj)
  {
    local option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    updateTripleAerobaticsSmokeOptions();
  }

  function updateTripleAerobaticsSmokeOptions()
  {
    local aerobaticsSmokeOptions = find_options_in_containers([
      ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    ])

    if (!aerobaticsSmokeOptions.len())
      return

    local show = (::get_option_aerobatics_smoke_type() > ::MAX_AEROBATICS_SMOKE_INDEX * 2);
    foreach(option in aerobaticsSmokeOptions)
      showOptionRow(option, show)
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

    obj.show(show)
    obj.inactive = show && option.controlType != optionControlType.HEADER ? null : "yes"
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
        updateOption(USEROPT_TANK_ALT_CROSSHAIR)
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

  function onDifficultyChange(obj)
  {
    updateVerticalTargetingOption()
  }

  function updateVerticalTargetingOption()
  {
    local optList = find_options_in_containers([::USEROPT_GUN_VERTICAL_TARGETING])
    if (!optList.len())
      return
    local diffName = getOptValue(::USEROPT_DIFFICULTY, false)
    if (diffName == null) //no such option in current options list
      return

    foreach(option in optList)
      showOptionRow(option, diffName != ::g_difficulty.ARCADE.name)
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
}

class ::gui_handlers.GenericOptionsModal extends ::gui_handlers.GenericOptions
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/options/navOptionsBack.blk"
  multipleInstances = true

  currentFocusItem = MAIN_FOCUS_ITEM_IDX + 1

  applyAtClose = true

  navigationHandlerWeak = null
  headersToOptionsList = {}

  function initScreen()
  {
    base.initScreen()

    initNavigation()
    initFocusArray()
  }

  function initNavigation()
  {
    local handler = ::handlersManager.loadHandler(
      ::gui_handlers.navigationPanel,
      { scene = scene.findObject("control_navigation")
        onSelectCb = ::Callback(doNavigateToSection, this)
        panelWidth        = "0.35@sf, ph"
        // Align to helpers_mode and table first row
        headerHeight      = "0.05@sf + @sf/@pf"
        headerOffsetX     = "0.015@sf"
        headerOffsetY     = "0.015@sf"
        collapseShortcut  = "LB"
        navShortcutGroup  = ::get_option(::USEROPT_GAMEPAD_CURSOR_CONTROLLER).value ? null : "RS"
      })
    registerSubHandler(navigationHandlerWeak)
    navigationHandlerWeak = handler.weakref()
  }

  function getMainFocusObj()
  {
    return "filter_edit_box"
  }

  function getMainFocusObj2()
  {
    return currentContainerName
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
    if ( ! ::check_obj(rowObj))
      return

    rowObj.scrollToView(true)
    objTbl.setValue(::getNearestSelectableChildIndex(objTbl, index, 1))
  }

  function resetNavigation()
  {
    if(navigationHandlerWeak)
      navigationHandlerWeak.setNavItems([])
  }

  function onTblSelect(obj)
  {
    checkCurrentNavigationSection()
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

    local trId = objTbl.getChild(idx).id
    return ::u.search(getCurrentOptionsList(), @(option) option.getTrId() == trId)
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

class ::gui_handlers.GroupOptionsModal extends ::gui_handlers.GenericOptionsModal
{
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/options/navOptions.blk"

  optGroups = null
  curGroup = -1
  echoTest = false;

  filterText = ""
  optionsVisibleBeforeSearch = []

  function initScreen()
  {
    if (!optGroups)
      base.goBack()

    base.initScreen()

    local view = { tabs = [] }
    local curOption = 0
    foreach(idx, gr in optGroups)
    {
      view.tabs.append({
        id = gr.name
        visualDisable = gr.name == "voicechat" && !crossplayModule.isCrossNetworkChatEnabled()
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

    if( ! filterText.len())
    {
      foreach(optionData in optionsVisibleBeforeSearch)
        base.showOptionRow(optionData.option, true)
      optionsVisibleBeforeSearch.clear()
      return
    }

    if( ! optionsVisibleBeforeSearch.len() && optGroups[curGroup].options.len())
      refreshVisibleOptionsList()

    local searchResultOptions = []
    foreach(optionData in optionsVisibleBeforeSearch)
    {
      local show = optionData.searchTitle.indexof(filterText) != null
      base.showOptionRow(optionData.option, show)

      if(show)
        searchResultOptions.append(optionData.option)
    }

    foreach(option in searchResultOptions)
    {
      if(option.controlType == optionControlType.HEADER)
      {
        // show options under header
        foreach(header, optionsList in headersToOptionsList)
        {
          if(header.id != option.id)
            continue
          foreach(optionUnderHeader in headersToOptionsList[header])
            if(::u.search(optionsVisibleBeforeSearch,
                @(o) o.option.id == optionUnderHeader.id) != null)
              base.showOptionRow(optionUnderHeader, true)
          break
        }
      }
      else
      {
        // show options header
        local header = getOptionHeader(option)
        if(header)
          base.showOptionRow(header, true)
      }
    }
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
    base.doNavigateToSection(navItem)
  }

  function showOptionRow(id, show)
  {
    resetSearch()
    base.showOptionRow(id, show)
  }

  function refreshVisibleOptionsList()
  {
    optionsVisibleBeforeSearch.clear()
    foreach(option in getCurrentOptionsList())
    {
      local optionTr = getObj(option.getTrId())
      if(::checkObj(optionTr) && optionTr.isVisible())
        optionsVisibleBeforeSearch.append({
          option = option,
          searchTitle = ::g_string.utf8ToLower(option.getTitle())
        })
    }
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
      likeBtn.enable(facebookLogged && !alreadyLiked && !::is_platform_ps4)
      likeBtn.show(!::is_platform_ps4)
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

    local needShowOptions = crossplayModule.isCrossNetworkChatEnabled()
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
    ::sysopt.fillGuiOptions(scene.findObject("optionslist"), this)
  }

  function onSystemOptionChanged(obj)
  {
    ::sysopt.onGuiOptionChanged(obj)
  }

  function onSystemOptionsRestartClient(obj)
  {
    ::sysopt.onRestartClient()
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
    local container = ::create_options_container(currentContainerName, config.options, true, true, columnsRatio,
                        true, true, optionsConfig)
    optionsContainers = [container.descr]

    guiScene.setUpdatesEnabled(false, false)
    optionIdToObjCache.clear()
    guiScene.replaceContentFromText(scene.findObject(objName), container.tbl, container.tbl.len(), this)
    onHintUpdate()
    setNavigationItems()
    guiScene.setUpdatesEnabled(true, true)
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
    ::gui_start_modal_wnd(::gui_handlers.AddRadioModalHandler, { owner=this })
  }

  function onDialogEditRadio()
  {
    local radio = ::get_internet_radio_options()
    if (!radio)
      return updateInternerRadioButtons()
    local station = radio?.station ?? ""
    ::gui_start_modal_wnd(::gui_handlers.AddRadioModalHandler, { owner = this, editStationName = station })
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
    ::reset_tutorial_skip()
    ::broadcastEvent("ResetSkipedNotifications")

    //To notify player about success, it is only for player,
    // to be sure, that operation is done.
    ::g_popups.add("", ::loc("mainmenu/btnRevealNotifications/onSuccess"))
  }
}

class ::gui_handlers.AddRadioModalHandler extends ::gui_handlers.BaseGuiHandlerWT
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/popup/addRadio.blk"

  focusArray = [
    "newradio_name"
    "newradio_url"
  ]
  currentFocusItem = 0
  editStationName = ""

  function initScreen()
  {
    restoreFocus()
    scene.findObject("newradio_name").select()
    ::gui_handlers.GroupOptionsModal.updateInternerRadioButtons.call(this)
    local nameRadio = ::loc("options/internet_radio_" + ((editStationName == "") ? "add" : "edit"))
    local titleRadio = scene.findObject("internet_radio_title")
    titleRadio.setValue(nameRadio)
    local btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.setValue(nameRadio)
    if (editStationName != "")
    {
      local editName = scene.findObject("newradio_name")
      editName.setValue(editStationName)
      local editUrl = scene.findObject("newradio_url")
      local url = ::get_internet_radio_path(editStationName)
      editUrl.setValue(url)
    }
  }

  function onChanged()
  {
    local msg = getMsgByEditbox("url")
    if (msg == "")
      msg = getMsgByEditbox("name")
    local btnAddRadio = scene.findObject("btn_add_radio")
    btnAddRadio.enable((msg != "") ? false : true)
    btnAddRadio.tooltip = msg
  }

  function getMsgByEditbox(name)
  {
    local isEmpty = ::is_chat_message_empty(scene.findObject("newradio_"+name).getValue())
    return isEmpty ? ::loc("options/no_"+name+"_radio") : ""
  }

  function onFocusUrl()
  {
    local guiScene = ::get_gui_scene()
    guiScene["newradio_url"].select()
  }

  function onAddRadio()
  {
    local value = scene.findObject("newradio_name").getValue()
    if (::is_chat_message_empty(value))
      return

    local name = clearBorderSymbols(value, [" "])
    local url = scene.findObject("newradio_url").getValue()
    if(url != "")
      url = clearBorderSymbols(url, [" "])

    if (name == "")
      return msgBox("warning",
          ::loc("options/no_name_radio"),
          [["ok", function() {}]], "ok")
    if (url == "")
      return msgBox("warning",
          ::loc("options/no_url_radio"),
          [["ok", function() {}]], "ok")

    local listRadio = ::get_internet_radio_stations()
    if (editStationName != "")
    {
      ::edit_internet_radio_station(editStationName, name, url)
    } else {
      foreach (radio in listRadio)
      {
        if (radio == name)
          return msgBox("warning",
            ::loc("options/msg_name_exists_radio"),
            [["ok", function() {}]], "ok")
        if (radio == url)
          return msgBox("warning",
            ::loc("options/msg_url_exists_radio"),
            [["ok", function() {}]], "ok")
      }
      ::add_internet_radio_station(name, url);
    }
    goBack()
    ::broadcastEvent("UpdateListRadio", {})
  }
}

