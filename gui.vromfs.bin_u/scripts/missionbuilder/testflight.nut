let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { bombNbr, hasCountermeasures } = require("%scripts/unit/unitStatus.nut")
let { isTripleColorSmokeAvailable } = require("%scripts/options/optionsManager.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getCdBaseDifficulty } = ::require_native("guiOptions")
local { getActionBarUnitName } = ::require_native("hudActionBar")

::missionBuilderVehicleConfigForBlk <- {} //!!FIX ME: Should to remove this
::last_called_gui_testflight <- null

::gui_start_testflight <- function gui_start_testflight(params = {})
{
  ::gui_start_modal_wnd(::gui_handlers.TestFlight, params)
  ::last_called_gui_testflight = ::handlersManager.getLastBaseHandlerStartFunc()
}

::mergeToBlk <- function mergeToBlk(sourceTable, blk)  //!!FIX ME: this used only for missionBuilderVehicleConfigForBlk and better to remove this also
{
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

::gui_handlers.TestFlight <- class extends ::gui_handlers.GenericOptionsModal
{
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "%gui/navTestflight.blk"
  multipleInstances = false
  wndGameMode = ::GM_TEST_FLIGHT
  wndOptionsMode = ::OPTIONS_MODE_TRAINING
  afterCloseFunc = null
  shouldSkipUnitCheck = false

  unit = null
  needSlotbar = true

  weaponsSelectorWeak = null
  hasMissionBuilder = true

  slobarActions = ["autorefill", "aircraft", "crew", "weapons", "repair"]

  function initScreen()
  {
    unit = unit ?? showedUnit.value
    if (!unit)
      return goBack()

    ::gui_handlers.GenericOptions.initScreen.bindenv(this)()

    let btnBuilder = this.showSceneBtn("btn_builder", hasMissionBuilder)
    if (hasMissionBuilder)
      btnBuilder.setValue(::loc("mainmenu/btnBuilder"))
    this.showSceneBtn("btn_select", true)

    needSlotbar = needSlotbar && !::g_decorator.isPreviewingLiveSkin() && ::isUnitInSlotbar(unit)
    if (needSlotbar)
    {
      let frameObj = scene.findObject("wnd_frame")
      frameObj.size = "1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar"
      frameObj.pos = "50%pw-50%w, 1@battleBtnBottomOffset-h"
      frameObj.withSlotbar = "yes"
    }

    this.showSceneBtn("unit_weapons_selector", true)
    guiScene.applyPendingChanges(false)

    guiScene.setUpdatesEnabled(false, false)

    updateAircraft()

    guiScene.setUpdatesEnabled(true, true)

    if (needSlotbar)
    {
      ::switch_profile_country(unit.shopCountry) //select country for slotbar
      showedUnit(unit) //select unit for slotbar
      createSlotbar()
    }
    else
    {
      let unitNestObj = scene.findObject("unit_nest")
      if (::checkObj(unitNestObj))
      {
        let airData = ::build_aircraft_item(unit.name, unit)
        guiScene.appendWithBlk(unitNestObj, airData, this)
        ::fill_unit_item_timers(unitNestObj.findObject(unit.name), unit)
      }
    }

    ::move_mouse_on_obj(scene.findObject("btn_select"))
  }

  function updateLinkedOptions() {
    checkBulletsRows()
    updateWeaponOptions()
    updateTripleAerobaticsSmokeOptions()
  }

  function updateWeaponOptions() {
    checkRocketDisctanceFuseRow()
    checkBombActivationTimeRow()
    checkBombSeriesRow()
    checkDepthChargeActivationTimeRow()
    updateTorpedoDiveDepth()
    updateCountermeasureOptions()
  }

  function updateCountermeasureOptions() {
    checkCountermeasurePeriodsRow()
    checkCountermeasureSeriesRow()
    checkCountermeasureSeriesPeriodsRow()
  }

  function checkBulletsRows()
  {
    if (typeof(::aircraft_for_weapons) != "string")
      return
    let air = ::getAircraftByName(::aircraft_for_weapons)
    if (!air)
      return

    let bulletGroups = weaponsSelectorWeak?.bulletsManager.getBulletsGroups() ?? []
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

    let weaponryObj = scene.findObject("unit_weapons_selector")

    let handler = ::handlersManager.loadHandler(::gui_handlers.unitWeaponsHandler, {
      scene = weaponryObj
      unit = unit
      canChangeBulletsAmount = true
      isForcedAvailable = ::isUnitSpecial(unit) && !unit.isBought()
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
    if (optionsConfig == null) {
      let diffOpt = ::get_option(::USEROPT_DIFFICULTY)
      optionsConfig = { diffCode = diffOpt.diffCode[diffOpt.value]}
    }
    options = [
      [::USEROPT_DIFFICULTY, "spinner"],
    ]
    if (unit?.isAir() || unit?.isHelicopter?())
    {
      options.append([::USEROPT_LIMITED_FUEL, "spinner"])
      options.append([::USEROPT_LIMITED_AMMO, "spinner"])
    }

    let skin_options = [
      [::USEROPT_SKIN, "spinner"]
    ]
    if (::has_feature("UserSkins"))
      skin_options.append([::USEROPT_USER_SKIN, "spinner"])

    options.extend(skin_options)

    if (unit?.isAir())
      options.append(
        [::USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner"],
        [::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner"]
      )

    if (unit?.isAir() || unit?.isHelicopter?())
      options.append(
        [::USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        [::USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        [::USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [::USEROPT_BOMB_SERIES, "spinner"],
        [::USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [::USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
        [::USEROPT_COUNTERMEASURES_SERIES_PERIODS, "spinner"],
        [::USEROPT_COUNTERMEASURES_PERIODS, "spinner"],
        [::USEROPT_COUNTERMEASURES_SERIES, "spinner"]
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
      [::USEROPT_CLIME, "spinner"]
    )
    return options
  }

  function updateAircraft()
  {
    updateButtons()
    updateWeaponsSelector()

    let showOptions = isTestFlightAvailable()

    let optListObj = scene.findObject("optionslist")
    let textObj = scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions? "" : getCantFlyText(unit))

    let hObj = scene.findObject("header_name")
    if (!::checkObj(hObj))
      return

    let headerText = unit.unitType.getTestFlightText() + " " + ::loc("ui/mdash") + " " + ::getUnitName(unit.name)
    hObj.setValue(headerText)

    if (!showOptions)
      return

    updateOptionsArray()

    ::test_flight_aircraft <- unit
    ::cur_aircraft_name = unit.name
    ::aircraft_for_weapons = unit.name
    ::set_gui_option(::USEROPT_AIRCRAFT, unit.name)

    let container = create_options_container("testflight_options", options, true, 0.5, true, optionsConfig)
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

    scene.findObject("btn_builder").inactiveColor = isBuilderAvailable() ? "no" : "yes"
    scene.findObject("btn_select").inactiveColor = isTestFlightAvailable()? "no" : "yes"
  }

  function onMissionBuilder()
  {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(::GM_BUILDER)
      }))
      return

    if (!isBuilderAvailable())
    {
      saveAircraftOptions()

      if (needSlotbar) // There is a slotbar in this scene
        this.msgBox("not_available",
          ::loc(::get_cur_slotbar_unit() == null ? "events/empty_crew" : "msg/builderOnlyForAircrafts"),
          [["ok"]], "ok")
      else
        ::gui_start_modal_wnd(::gui_handlers.changeAircraftForBuilder, { shopAir = unit })
      return
    }

    applyFunc = function()
    {
      saveAircraftOptions()

      ::gui_start_builder()
      applyFunc = null
    }
    applyOptions()
  }

  function onApply(obj)
  {
    let bulletsManager = weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager || !bulletsManager.checkChosenBulletsCount())
      return

    ::broadcastEvent("BeforeStartTestFlight")

    if (::g_squad_manager.isNotAloneOnline())
      return onMissionBuilder()

    if (!isTestFlightAvailable())
      return this.msgBox("not_available", getCantFlyText(unit), [["ok", function() {} ]], "ok", { cancel_fn = function() {}})

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
          applyFunc = null
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
    let misName = getTestFlightMisName(unit.testFlight)
    let misBlk = ::get_mission_meta_info(misName)
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
        weather     = getSceneOptValue(::USEROPT_CLIME)
        environment = getSceneOptValue(::USEROPT_TIME)
      }, misBlk)

    ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misBlk)

    actionBarInfo.cacheActionDescs(getActionBarUnitName())

    ::select_training_mission(misBlk)
    guiScene.performDelayed(this, ::gui_start_flight)
  }

  function getTestFlightMisName(misName)
  {
    let lang = ::g_language.getLanguageName()
    return ::get_game_settings_blk()?.testFlight_override?[lang]?[misName] ?? misName
  }

  function saveAircraftOptions()
  {
    if (!unit)
      return

    let dif = ::get_option(::USEROPT_DIFFICULTY)
    let difValue = dif.values[dif.value]

    let skin = ::get_option(::USEROPT_SKIN)
    let skinValue = skin.values[skin.value]
    let fuelValue = getSceneOptValue(::USEROPT_LOAD_FUEL_AMOUNT)
    let limitedFuel = ::get_option(::USEROPT_LIMITED_FUEL)
    let limitedAmmo = ::get_option(::USEROPT_LIMITED_AMMO)

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

  function updateBulletCountOptions(updUnit) {
    local bulIdx = 0
    let bulletGroups = weaponsSelectorWeak ? weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach(idx, bulGroup in bulletGroups) {
      bulIdx = idx
      local name = ""
      local count = 0
      if (bulGroup.active) {
        name = bulGroup.getBulletNameForCode(bulGroup.selectedName)
        count = bulGroup.bulletsCount * bulGroup.guns
      }
      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, name)
      ::set_option(::USEROPT_BULLETS0 + bulIdx, name)
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, count)
    }
    ++bulIdx

    while(bulIdx < ::BULLETS_SETS_QUANTITY) {
      ::set_unit_option(updUnit.name, ::USEROPT_BULLETS0 + bulIdx, "")
      ::set_option(::USEROPT_BULLETS0 + bulIdx, "")
      ::set_gui_option(::USEROPT_BULLET_COUNT0 + bulIdx, 0)
      ++bulIdx
    }
  }

  function onDifficultyChange(obj)
  {
    updateVerticalTargetingOption()
    updateSceneDifficulty()

    let diffOptionCont = findOptionInContainers(::USEROPT_DIFFICULTY)
    ::set_option(::USEROPT_DIFFICULTY, obj.getValue(), diffOptionCont)
    optionsConfig.diffCode <- diffOptionCont.diffCode[obj.getValue()]
    updateOption(::USEROPT_LOAD_FUEL_AMOUNT)
    updateOption(::USEROPT_BOMB_ACTIVATION_TIME)
  }

  function updateSceneDifficulty()
  {
    if (getSlotbar())
      getSlotbar().updateDifficulty()

    let unitNestObj = unit ? scene.findObject("unit_nest") : null
    if (::checkObj(unitNestObj))
    {
      let obj = unitNestObj.findObject("rank_text")
      if (::checkObj(obj))
        obj.setValue(::get_unit_rank_text(unit, null, true, getCurrentEdiff()))
    }
  }

  function getCurrentEdiff()
  {
    let diffValue = getSceneOptValue(::USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      ::g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1)
    {
      let battleType = ::get_battle_type_by_unit(unit)
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

    let crewUnit = ::get_cur_slotbar_unit()
    if (crewUnit == unit || crewUnit == null)
    {
      updateButtons()
      return
    }

    applyFunc = ::Callback(function()
      {
        unit = crewUnit
        updateAircraft()
        applyFunc = null
      },
      this)

    applyOptions()
  }

  function onUserModificationsUpdate(obj) {
    let option = get_option_by_id(obj?.id)
    if (!option)
      return

    if (option.value != obj.getValue()) {
      guiScene.performDelayed(this, function() {
        ::set_option(option.type, obj.getValue())
        updateOption(option.type)
      })
    }

    ::enable_bullets_modifications(unit.name)
    ::enable_current_modifications(unit.name)
  }

  function onMyWeaponOptionUpdate(obj)
  {
    let option = get_option_by_id(obj?.id)
    if (!option) return

    ::set_option(option.type, obj.getValue(), option)
    if ("hints" in option)
      obj.tooltip = option.hints[ obj.getValue() ]
    else if ("hint" in option)
      obj.tooltip = ::g_string.stripTags( ::loc(option.hint, "") )
    checkBulletsRows()
    updateWeaponOptions()
  }

  function onTripleAerobaticsSmokeSelected(obj)
  {
    let option = get_option_by_id(obj?.id)
    if (!option)
      return

    ::set_option(option.type, obj.getValue(), option)
    updateTripleAerobaticsSmokeOptions()
  }

  function checkRocketDisctanceFuseRow()
  {
    let option = findOptionInContainers(::USEROPT_ROCKET_FUSE_DIST)
    if (!option)
      return

    showOptionRow(option, !!unit && unit.getAvailableSecondaryWeapons().hasRocketDistanceFuse)
  }

  function checkBombActivationTimeRow()
  {
    let option = findOptionInContainers(::USEROPT_BOMB_ACTIVATION_TIME)
    if (!option)
      return

    showOptionRow(option, !!unit && unit.getAvailableSecondaryWeapons().hasBombs)
  }

  function checkBombSeriesRow()
  {
    let option = findOptionInContainers(::USEROPT_BOMB_SERIES)
    if (!option)
      return

    showOptionRow(option, bombNbr(unit) > 1)

    updateOption(::USEROPT_BOMB_SERIES)
  }

  function checkCountermeasurePeriodsRow()
  {
    let option = ::get_option(::USEROPT_COUNTERMEASURES_PERIODS)
    if (option)
      showOptionRow(option, hasCountermeasures(unit))
  }

  function checkCountermeasureSeriesRow()
  {
    let option = ::get_option(::USEROPT_COUNTERMEASURES_SERIES)
    if (option)
      showOptionRow(option, hasCountermeasures(unit))
  }

  function checkCountermeasureSeriesPeriodsRow()
  {
    let option = ::get_option(::USEROPT_COUNTERMEASURES_SERIES_PERIODS)
    if (option)
      showOptionRow(option, hasCountermeasures(unit))
  }

  function checkDepthChargeActivationTimeRow()
  {
    let option = findOptionInContainers(::USEROPT_DEPTHCHARGE_ACTIVATION_TIME)
    if (!option)
      return

    showOptionRow(option, unit?.isDepthChargeAvailable?()
      && unit.getAvailableSecondaryWeapons().hasDepthCharges)
  }

  function updateTripleAerobaticsSmokeOptions()
  {
    let aerobaticsSmokeOptions = find_options_in_containers([
      ::USEROPT_AEROBATICS_SMOKE_LEFT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR,
      ::USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    ])

    if (!aerobaticsSmokeOptions.len())
      return

    let show = isTripleColorSmokeAvailable()
    foreach(option in aerobaticsSmokeOptions)
      showOptionRow(option, show)
  }

  function updateTorpedoDiveDepth() {
    let option = findOptionInContainers(::USEROPT_TORPEDO_DIVE_DEPTH)
    if (!option)
      return

    showOptionRow(option, !::get_option_torpedo_dive_depth_auto()
      && unit.isShipOrBoat()
      && unit.getAvailableSecondaryWeapons().hasTorpedoes)
  }

  function updateVerticalTargetingOption()
  {
    let optList = find_options_in_containers([::USEROPT_GUN_VERTICAL_TARGETING])
    if (!optList.len())
      return
    let diffName = getOptValue(::USEROPT_DIFFICULTY, false)
    if (diffName == null) //no such option in current options list
      return

    foreach(option in optList)
      showOptionRow(option, diffName != ::g_difficulty.ARCADE.name)
  }

  function onEventUnitWeaponChanged(p) {
    updateWeaponOptions()
  }

  function onEventModificationChanged(p) {
    doWhenActiveOnce("updateCountermeasureOptions")
  }

  function onEventModificationPurchased(p) {
    doWhenActiveOnce("updateCountermeasureOptions")
  }
}