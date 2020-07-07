local { getLastWeapon } = require("scripts/weaponry/weaponryInfo.nut")
local { AMMO, getAmmoMaxAmount } = require("scripts/weaponry/ammoInfo.nut")
local { getBulletsSetData,
        isBulletGroupActive,
        getBulletsGroupCount,
        getBulletsInfoForPrimaryGuns } = require("scripts/weaponry/bulletsInfo.nut")

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

    initFocusArray()

    local focusObj = getMainFocusObj2()
    focusObj.select()
    checkCurrentFocusItem(focusObj)
  }

  function getMainFocusObj()
  {
    return weaponsSelectorWeak && weaponsSelectorWeak.getMainFocusObj()
  }

  function getMainFocusObj2()
  {
    return scene.findObject("testflight_options")
  }

  function updateWeaponsSelector()
  {
    if (weaponsSelectorWeak)
    {
      weaponsSelectorWeak.setUnit(unit)
      delayedRestoreFocus()
      return
    }

    local weaponryObj = scene.findObject("unit_weapons_selector")
    local handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler,
                                       { scene = weaponryObj
                                         unit = unit
                                         parentHandlerWeak = this
                                         canChangeBulletsAmount = false
                                         isForcedAvailable = ::isUnitSpecial(unit)
                                       })

    weaponsSelectorWeak = handler.weakref()
    registerSubHandler(handler)
    delayedRestoreFocus()
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
    if (::isAircraft(unit) || unit?.isHelicopter?())
    {
      options.append([::USEROPT_LIMITED_FUEL, "spinner"])
      options.append([::USEROPT_LIMITED_AMMO, "spinner"])
    }

    local skin_options = [
      [::USEROPT_SKIN, "spinner"]
    ]
    if (::has_feature("UserSkins"))
      skin_options.append([::USEROPT_USER_SKIN, "spinner"])

    local aircraft_options = [
      [::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
      [::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
      [::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
      [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
      [::USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
      [::USEROPT_FLARES_SERIES, "spinner"],
      [::USEROPT_FLARES_SERIES_PERIODS, "spinner"],
      [::USEROPT_FLARES_PERIODS, "spinner"],
    ]

    local common_options = [
      [::USEROPT_MODIFICATIONS, "spinner"],
      [::USEROPT_TIME, "spinner"],
      [::USEROPT_WEATHER, "spinner"],
    ]

    local ship_options = [
      [::USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner"],
      [::USEROPT_MINE_DEPTH, "spinner"],
      [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
    ]

    options.extend(skin_options)
    if (::isAircraft(unit) || unit?.isHelicopter?())
      options.extend(aircraft_options)

    if (::isShip(unit))
      options.extend(ship_options)

    options.extend(common_options)
    return options
  }

  function updateAircraft()
  {
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

    local container = create_options_container("testflight_options", options, true, true, 0.5)
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
    enable_bullets_modifications(::aircraft_for_weapons)
    enable_current_modifications(::aircraft_for_weapons)

    ::missionBuilderVehicleConfigForBlk = {
        selectedSkin  = skinValue,
        difficulty    = difValue,
        isLimitedFuel = limitedFuel.value,
        isLimitedAmmo = limitedAmmo.value,
        fuelAmount    = (fuelValue.tofloat()/1000000.0),
    }

    if (unit.unitType.canUseSeveralBulletsForGun)
      updateBulletCountOptions(unit)
  }

  function updateBulletCountOptions(updUnit)
  {
    //prepare data to calc amounts
    local groupsCount = getBulletsGroupCount(updUnit, false)
    local bulletsInfo = getBulletsInfoForPrimaryGuns(updUnit)
    local gunsData = []
    for(local i = 0; i < groupsCount; i++)
    {
      local bInfo = ::getTblValue(i, bulletsInfo, null)
      gunsData.append({
        gunsAmount = ::getTblValue("guns", bInfo, 0)
        catridge = ::getTblValue("catridge", bInfo, 0)
        leftCatridges = ::getTblValue("total", bInfo, 0)
        leftGroups = 0
      })
    }

    local bulletSetsQuantity = updUnit.unitType.bulletSetsQuantity
    local bulDataList = []
    for (local groupIdx = 0; groupIdx < bulletSetsQuantity; groupIdx++)
    {
      local isActive = isBulletGroupActive(updUnit, groupIdx)

      local gunIdx = ::get_linked_gun_index(groupIdx, groupsCount, bulletSetsQuantity)
      local modName = ::get_last_bullets(updUnit.name, groupIdx)
      local maxToRespawn = 0

      if (isActive)
      {
        local bulletsSet = getBulletsSetData(updUnit, modName)
        maxToRespawn = ::getTblValue("maxToRespawn", bulletsSet, 0)
        if (maxToRespawn <= 0)
          maxToRespawn = getAmmoMaxAmount(updUnit, modName, AMMO.PRIMARY)

        gunsData[gunIdx].leftGroups++
      }

      bulDataList.append({
        groupIdx = groupIdx
        gunIdx = gunIdx
        modName = modName
        isActive = isActive
        maxAmount = maxToRespawn
        amountToSet = 0
      })
    }

    //calc bullets amount
    bulDataList.sort(function(a, b) {
      if (a.maxAmount != b.maxAmount)
        if (!a.maxAmount || !b.maxAmount)
          return a.maxAmount ? -1 : 1
        else
          return a.maxAmount - b.maxAmount
      return 0
    })
    foreach(bulData in bulDataList)
    {
      if (!bulData.isActive)
        continue

      local gun = gunsData[bulData.gunIdx]
      local catridgesToSet = (gun.leftCatridges / (gun.leftGroups || 1)).tointeger()
      if (bulData.maxAmount)
      {
        local catridgesMax = (bulData.maxAmount / gun.gunsAmount).tointeger() || 1
        catridgesToSet = ::min(catridgesToSet, catridgesMax)
      }
      gun.leftCatridges -= catridgesToSet
      gun.leftGroups--
      bulData.amountToSet = catridgesToSet * gun.gunsAmount
    }

    //save bullets and count
    bulDataList.sort(function(a, b) {
      if (a.isActive != b.isActive)
        return a.isActive ? -1 : 1
      return a.groupIdx - b.groupIdx
    })
    foreach(bulIdx, bulData in bulDataList)
    {
      local modName = bulData.isActive ? bulData.modName : ""
      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_gui_option(::USEROPT_BULLETS0 + bulIdx, modName)
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, bulData.amountToSet)
    }
    for (local bulIdx = bulletSetsQuantity; bulIdx < ::BULLETS_SETS_QUANTITY; bulIdx++)
    {
      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, "")
      ::set_gui_option(::USEROPT_BULLETS0 + bulIdx, "")
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, 0)
    }
  }

  function onDifficultyChange(obj)
  {
    base.onDifficultyChange(obj)
    updateSceneDifficulty()

    ::set_option(::USEROPT_DIFFICULTY, obj.getValue(), findOptionInContainers(::USEROPT_DIFFICULTY))
    updateOption(::USEROPT_LOAD_FUEL_AMOUNT)
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
}