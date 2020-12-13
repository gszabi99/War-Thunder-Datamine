local { getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { hasFlares, bombNbr } = require("scripts/unit/unitStatus.nut")

::missionBuilderVehicleConfigForBlk <- {} //!!FIX ME: Should to remove this
::last_called_gui_testflight <- null

::gui_start_testflight <- function gui_start_testflight(unit = null, afterCloseFunc = null, shouldSkipUnitCheck = false)
{
  ::gui_start_modal_wnd(::gui_handlers.TestFlight,
  {
    afterCloseFunc = afterCloseFunc
    unit =  unit || ::show_aircraft
    shouldSkipUnitCheck = shouldSkipUnitCheck
  })
  ::last_called_gui_testflight = ::handlersManager.getLastBaseHandlerStartFunc()
}

::mergeToBlk <- function mergeToBlk(sourceTable, blk)  //!!FIX ME: this used only for missionBuilderVehicleConfigForBlk and better to remove this also
{
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

class ::gui_handlers.TestFlight extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "gui/navTestflight.blk"
  multipleInstances = false
  wndGameMode = ::GM_TEST_FLIGHT
  wndOptionsMode = ::OPTIONS_MODE_TRAINING
  applyAtClose = false
  afterCloseFunc = null
  shouldSkipUnitCheck = false

  unit = null
  needSlotbar = false

  weaponsSelectorWeak = null
  lastBulletsCache = null
  lastWeaponCache = null

  slobarActions = ["autorefill", "aircraft", "crew", "weapons", "repair"]

  function initScreen()
  {
    if (!unit)
      return goBack()

    ::gui_handlers.GenericOptions.initScreen.bindenv(this)()

    scene.findObject("btn_builder").setValue(::loc("mainmenu/btnBuilder"))
    showSceneBtn("btn_select", true)

    needSlotbar = !::g_decorator.isPreviewingLiveSkin() && ::isUnitInSlotbar(unit)
    if (needSlotbar)
    {
      scene.findObject("wnd_frame").size = "1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar"
      scene.findObject("wnd_frame").pos = "50%pw-50%w, 1@battleBtnBottomOffset-h"
    }

    showSceneBtn("unit_weapons_selector", true)
    guiScene.applyPendingChanges(false)

    guiScene.setUpdatesEnabled(false, false)

    updateAircraft()

    guiScene.setUpdatesEnabled(true, true)

    if (needSlotbar)
    {
      ::show_aircraft = unit //select unit for slotbar
      createSlotbar()
    }
    else
    {
      local unitNestObj = scene.findObject("unit_nest")
      if (::checkObj(unitNestObj))
      {
        local airData = ::build_aircraft_item(unit.name, unit)
        guiScene.appendWithBlk(unitNestObj, airData, this)
        ::fill_unit_item_timers(unitNestObj.findObject(unit.name), unit)
      }
    }

    ::move_mouse_on_obj(scene.findObject("btn_select"))
  }

  function updateLinkedOptions() {
    checkBulletsRows()
    checkVehicleModificationRow()
    updateWeaponOptions()
  }

  function updateWeaponOptions() {
    checkRocketDisctanceFuseRow()
    checkBombActivationTimeRow()
    checkBombSeriesRow()
    checkDepthChargeActivationTimeRow()
    updateTorpedoDiveDepth()
    updateFlaresOptions()
  }

  function updateFlaresOptions() {
    checkFlaresPeriodsRow()
    checkFlaresSeriesRow()
    checkFlaresSeriesPeriodsRow()
  }

  function checkBulletsRows()
  {
    if (typeof(::aircraft_for_weapons) != "string")
      return
    local air = ::getAircraftByName(::aircraft_for_weapons)
    if (!air)
      return

    local bulletGroups = weaponsSelectorWeak?.bulletsManager.getBulletsGroups() ?? []
    foreach(idx, bulGroup in bulletGroups)
      showOptionRow(bulGroup.getOption(), bulGroup.active)
  }

  function updateWeaponsSelector()
  {
    if (weaponsSelectorWeak)
    {
      weaponsSelectorWeak.setUnit(unit)
      return
    }

    local weaponryObj = scene.findObject("unit_weapons_selector")
    local handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler,
                                       { scene = weaponryObj
                                         unit = unit
                                         canChangeBulletsAmount = true
                                         isForcedAvailable = ::isUnitSpecial(unit)
                                       })

    weaponsSelectorWeak = handler.weakref()
    registerSubHandler(handler)
  }

  function getCantFlyText(checkUnit)
  {
    return !checkUnit.unitType.isAvailable() ?
      ::loc("mainmenu/unitTypeLocked") : checkUnit.unitType.getTestFlightUnavailableText()
  }

  function updateOptionsArray()
  {
    options = [
      [::USEROPT_DIFFICULTY, "spinner"],
    ]
    if (unit?.isAir() || unit?.isHelicopter?())
    {
      options.append([::USEROPT_LIMITED_FUEL, "spinner"])
      options.append([::USEROPT_LIMITED_AMMO, "spinner"])
    }

    local skin_options = [
      [::USEROPT_SKIN, "spinner"]
    ]
    if (::has_feature("UserSkins"))
      skin_options.append([::USEROPT_USER_SKIN, "spinner"])

    options.extend(skin_options)
    if (unit?.isAir() || unit?.isHelicopter?())
      options.append(
        [::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        [::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        [::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [::USEROPT_BOMB_SERIES, "spinner"],
        [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [::USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
        [::USEROPT_FLARES_SERIES, "spinner"],
        [::USEROPT_FLARES_SERIES_PERIODS, "spinner"],
        [::USEROPT_FLARES_PERIODS, "spinner"]
      )

    if (unit?.isShipOrBoat())
    {
      options.append(
        [::USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner"],
        [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [::USEROPT_TORPEDO_DIVE_DEPTH, "spinner"]
      )
    }

    options.append(
      [::USEROPT_MODIFICATIONS, "spinner"],
      [::USEROPT_TIME, "spinner"],
      [::USEROPT_WEATHER, "spinner"]
    )
    return options
  }

  function updateAircraft()
  {
    lastBulletsCache = null
    lastWeaponCache = null

    updateButtons()
    updateWeaponsSelector()

    local showOptions = isTestFlightAvailable()

    local optListObj = scene.findObject("optionslist")
    local textObj = scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions? "" : getCantFlyText(unit))

    local hObj = scene.findObject("header_name")
    if (!::checkObj(hObj))
      return

    local headerText = unit.unitType.getTestFlightText() + " " + ::loc("ui/mdash") + " " + ::getUnitName(unit.name)
    hObj.setValue(headerText)

    if (!showOptions)
      return

    updateOptionsArray()

    ::test_flight_aircraft <- unit
    ::cur_aircraft_name = unit.name
    ::aircraft_for_weapons = unit.name
    ::set_gui_option(::USEROPT_AIRCRAFT, unit.name)

    local container = create_options_container("testflight_options", options, true, 0.5)
    guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)

    optionsContainers = [container.descr]
    updateLinkedOptions()
  }

  function isBuilderAvailable()
  {
    return ::isUnitAvailableForGM(unit, ::GM_BUILDER)
  }
  function isTestFlightAvailable()
  {
    return ::isTestFlightAvailable(unit, shouldSkipUnitCheck)
  }

  function updateButtons()
  {
    if (!::checkObj(scene))
      return

    scene.findObject("btn_builder").inactiveColor = (isBuilderAvailable() && ::isUnitInSlotbar(unit))? "no" : "yes"
    scene.findObject("btn_select").inactiveColor = isTestFlightAvailable()? "no" : "yes"
  }

  function onMissionBuilder()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    if (!::isUnitInSlotbar(unit))
    {
      saveAircraftOptions()
      ::gui_start_modal_wnd(::gui_handlers.changeAircraftForBuilder, { shopAir = unit })
      return
    }

    if (!isBuilderAvailable())
      return msgBox("not_available", ::loc("msg/builderOnlyForAircrafts"), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

    applyFunc = function()
    {
      saveAircraftOptions()

      ::gui_start_builder()
    }
    applyOptions()
  }

  function onApply(obj)
  {
    local bulletsManager = weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager || !bulletsManager.checkChosenBulletsCount())
      return

    ::broadcastEvent("BeforeStartTestFlight")

    if (::g_squad_manager.isNotAloneOnline())
      return onMissionBuilder()

    if (!isTestFlightAvailable())
      return msgBox("not_available", getCantFlyText(unit), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

    if (::isInArray(getSceneOptValue(::USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    if (unit)
      ::set_gui_option(::USEROPT_WEAPONS, getLastWeapon(unit.name))

    if (::SessionLobby.isInRoom())
      return goBack()

    ::queues.checkAndStart(
      ::Callback(function() {
        applyFunc = function()
        {
          if (::get_gui_option(::USEROPT_DIFFICULTY) == "custom")
          {
            ::gui_start_cd_options(startTestFlight, this) // See "MissionDescriptor::loadFromBlk"
            doWhenActiveOnce("updateSceneDifficulty")
          }
          else
            startTestFlight()
        }
        applyOptions()
      }, this)
      null
      "isCanNewflight"
    )
  }

  function onEventSquadStatusChanged(params)
  {
    updateButtons()
  }

  function startTestFlight()
  {
    local misName = getTestFlightMisName(unit.testFlight)
    local misBlk = ::get_mission_meta_info(misName)
    if (!misBlk)
      return ::dagor.assertf(false, "Error: wrong testflight mission " + misName)

    ::current_campaign_mission <- misName

    saveAircraftOptions()
    ::g_decorator.setCurSkinToHangar(unit.name)

    ::mergeToBlk({
        _gameMode = ::GM_TEST_FLIGHT
        name      = misName
        chapter   = "training"
        takeOffOnStart = false
        weather     = getSceneOptValue(::USEROPT_WEATHER)
        environment = getSceneOptValue(::USEROPT_TIME)
      }, misBlk)

    ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misBlk)

    ::select_training_mission(misBlk)
    guiScene.performDelayed(this, ::gui_start_flight)
  }

  function getTestFlightMisName(misName)
  {
    local lang = ::g_language.getLanguageName()
    return ::get_game_settings_blk()?.testFlight_override?[lang]?[misName] ?? misName
  }

  function saveAircraftOptions()
  {
    local dif = ::get_option(::USEROPT_DIFFICULTY)
    local difValue = dif.values[dif.value]

    local skin = ::get_option(::USEROPT_SKIN)
    local skinValue = skin.values[skin.value]
    local fuelValue = getSceneOptValue(::USEROPT_LOAD_FUEL_AMOUNT)
    local limitedFuel = ::get_option(::USEROPT_LIMITED_FUEL)
    local limitedAmmo = ::get_option(::USEROPT_LIMITED_AMMO)

    ::aircraft_for_weapons = unit.name

    updateBulletCountOptions(unit)

    ::enable_bullets_modifications(::aircraft_for_weapons)
    ::enable_current_modifications(::aircraft_for_weapons)

    ::missionBuilderVehicleConfigForBlk = {
        selectedSkin  = skinValue,
        difficulty    = difValue,
        isLimitedFuel = limitedFuel.value,
        isLimitedAmmo = limitedAmmo.value,
        fuelAmount    = (fuelValue.tofloat()/1000000.0),
    }
  }

  function updateBulletCountOptions(updUnit)
  {
    local bulIdx = 0
    local bulletGroups = weaponsSelectorWeak ? weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach(idx, bulGroup in bulletGroups)
    {
      local modName = bulGroup.active ? bulGroup.getBulletNameForCode(bulGroup.selectedName) : ""

      if (bulGroup.canChangeBulletsCount() && bulGroup.bulletsCount <= 0)
        continue

      local count = bulGroup.bulletsCount * bulGroup.guns

      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_option(::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, count)
      bulIdx++
    }
    while(bulIdx < ::BULLETS_SETS_QUANTITY)
    {
      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, "")
      ::set_option(::USEROPT_BULLETS0 + bulIdx, "")
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, 0)
      bulIdx++
    }
  }

  function onDifficultyChange(obj)
  {
    updateVerticalTargetingOption()
    updateSceneDifficulty()

    local diffOptionCont = findOptionInContainers(::USEROPT_DIFFICULTY)
    ::set_option(::USEROPT_DIFFICULTY, obj.getValue(), diffOptionCont)
    updateOption(::USEROPT_LOAD_FUEL_AMOUNT)
    ::set_option(::USEROPT_BOMB_ACTIVATION_TIME, ::get_option(
      ::USEROPT_BOMB_ACTIVATION_TIME, {diffCode = diffOptionCont.diffCode[obj.getValue()]}).value)
    updateOption(::USEROPT_BOMB_ACTIVATION_TIME)
  }

  function updateSceneDifficulty()
  {
    if (getSlotbar())
      getSlotbar().updateDifficulty()

    local unitNestObj = unit ? scene.findObject("unit_nest") : null
    if (::checkObj(unitNestObj))
    {
      local obj = unitNestObj.findObject("rank_text")
      if (::checkObj(obj))
        obj.setValue(::get_unit_rank_text(unit, null, true, getCurrentEdiff()))
    }
  }

  function getCurrentEdiff()
  {
    local diffValue = getSceneOptValue(::USEROPT_DIFFICULTY)
    local difficulty = (diffValue == "custom") ?
      ::g_difficulty.getDifficultyByDiffCode(::get_cd_base_difficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1)
    {
      local battleType = ::get_battle_type_by_unit(unit)
      return difficulty.getEdiff(battleType)
    }
    return ::get_current_ediff()
  }

  function afterModalDestroy()
  {
    if (afterCloseFunc)
      afterCloseFunc()
  }

  function onEventCrewChanged(p)
  {
    doWhenActiveOnce("setUnitFromSlotbar")
  }

  function onEventCountryChanged(p)
  {
    doWhenActiveOnce("setUnitFromSlotbar")
  }

  function setUnitFromSlotbar()
  {
    if (!needSlotbar)
      return

    local crewUnit = ::get_cur_slotbar_unit()
    if (!crewUnit || crewUnit == unit)
      return

    applyFunc = ::Callback(function()
      {
        unit = crewUnit
        updateAircraft()
      },
      this)

    applyOptions()
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

    if (!weaponsSelectorWeak)
      return

    if (!obj.getValue()) {//default mod option selected
      lastWeaponCache = weaponsSelectorWeak.getCurWeapon().name
      setLastBulletsCache()

      local defaultWeap = unit.getDefaultWeapon()
      if (defaultWeap)
        weaponsSelectorWeak.setWeapon(defaultWeap)

      local bulletGroups = weaponsSelectorWeak.bulletsManager.getBulletsGroups()
      foreach(idx, bulGroup in bulletGroups) {
        if (!bulGroup.active)
          continue

        local defBulletName = bulGroup.getBulletNameByIdx(0)
        if (bulletGroups.findvalue(@(gr) gr.selectedName == defBulletName) != null)
          continue

        weaponsSelectorWeak.bulletsManager.changeBulletsValue(bulGroup, defBulletName)
      }
    }
    else//current mod option selected
    {
      if (lastWeaponCache)
        weaponsSelectorWeak.setWeapon(lastWeaponCache)
      setUnitLastBulletsFromCache()
    }

    ::enable_bullets_modifications(unit.name)
    ::enable_current_modifications(unit.name)
  }

  function onMyWeaponOptionUpdate(obj)
  {
    local option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    if ("hints" in option)
      obj.tooltip = option.hints[ obj.getValue() ]
    else if ("hint" in option)
      obj.tooltip = ::g_string.stripTags( ::loc(option.hint, "") )
    checkBulletsRows()
    updateWeaponOptions()
  }

  function setLastBulletsCache()
  {
    local bulletGroups = weaponsSelectorWeak ? weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    lastBulletsCache = bulletGroups.filter(@(bulGroup) bulGroup.active).map(@(bulGroup) {
      groupIndex = bulGroup.groupIndex,
      bulletName = bulGroup.selectedName
    })
  }

  function setUnitLastBulletsFromCache()
  {
    if (!weaponsSelectorWeak)
      return

    if ((lastBulletsCache?.len() ?? 0) == 0)
      return

    foreach (groupInfo in lastBulletsCache)
    {
      local bulGroup = weaponsSelectorWeak.getBulletGroupByIndex(groupInfo.groupIndex)
      if (bulGroup)
        weaponsSelectorWeak.bulletsManager.changeBulletsValue(bulGroup, groupInfo.bulletName)
    }
  }

  function checkVehicleModificationRow() {
    local option = findOptionInContainers(::USEROPT_MODIFICATIONS)
    if (option && !option.value) {
      local referenceWeap = unit.getDefaultWeapon() == getLastWeapon(unit.name)

      if (referenceWeap) {
        local bulletGroups = weaponsSelectorWeak.bulletsManager.getBulletsGroups()
        foreach(idx, bulGroup in bulletGroups) {
          local defBulletName = bulGroup.getBulletNameByIdx(0)
          if (bulGroup.selectedName != defBulletName) {
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

  function checkRocketDisctanceFuseRow()
  {
    local option = findOptionInContainers(::USEROPT_ROCKET_FUSE_DIST)
    if (!option)
      return

    showOptionRow(option, !!unit && unit.getAvailableSecondaryWeapons().hasRocketDistanceFuse)
  }

  function checkBombActivationTimeRow()
  {
    local option = findOptionInContainers(::USEROPT_BOMB_ACTIVATION_TIME)
    if (!option)
      return

    showOptionRow(option, !!unit && unit.getAvailableSecondaryWeapons().hasBombs)
  }

  function checkBombSeriesRow()
  {
    local option = findOptionInContainers(::USEROPT_BOMB_SERIES)
    if (!option)
      return

    showOptionRow(option, bombNbr(unit) > 1)

    updateOption(::USEROPT_BOMB_SERIES)
  }

  function checkFlaresPeriodsRow()
  {
    local option = ::get_option(::USEROPT_FLARES_PERIODS)
    if (!option)
      return

    showOptionRow(option, hasFlares(unit))
  }

  function checkFlaresSeriesRow()
  {
    local option = ::get_option(::USEROPT_FLARES_SERIES)
    if (!option)
      return

    showOptionRow(option, hasFlares(unit))
  }

  function checkFlaresSeriesPeriodsRow()
  {
    local option = ::get_option(::USEROPT_FLARES_SERIES_PERIODS)
    if (!option)
      return

    showOptionRow(option, hasFlares(unit))
  }

  function checkDepthChargeActivationTimeRow()
  {
    local option = findOptionInContainers(::USEROPT_DEPTHCHARGE_ACTIVATION_TIME)
    if (!option)
      return

    showOptionRow(option, unit?.isDepthChargeAvailable?()
      && unit.getAvailableSecondaryWeapons().hasDepthCharges)
  }

  function updateTorpedoDiveDepth() {
    local option = findOptionInContainers(::USEROPT_TORPEDO_DIVE_DEPTH)
    if (!option)
      return

    showOptionRow(option, !get_option_torpedo_dive_depth_auto()
      && unit.isShipOrBoat()
      && unit.getAvailableSecondaryWeapons().hasTorpedoes)
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

  function onEventBulletsGroupsChanged(p) {
    checkVehicleModificationRow()
  }

  function onEventUnitWeaponChanged(p) {
    checkVehicleModificationRow()
    updateWeaponOptions()
  }

  function onEventModificationChanged(p) {
    doWhenActiveOnce("updateFlaresOptions")
  }

  function onEventModificationPurchased(p) {
    doWhenActiveOnce("updateFlaresOptions")
  }
}