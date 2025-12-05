from "%scripts/dagui_natives.nut" import enable_bullets_modifications
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
from "radarOptions" import get_radar_mode_names, set_option_radar_name, get_radar_scan_pattern_names, set_option_radar_scan_pattern_name, get_radar_range_values
from "%scripts/options/optionsConsts.nut" import AIR_SPAWN_POINT

let { g_difficulty } = require("%scripts/difficulty.nut")
let { getGlobalModule } = require("%scripts/global_modules.nut")
let g_squad_manager = getGlobalModule("g_squad_manager")
let { isUnitSpecial } = require("%appGlobals/ranks_common_shared.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getLastWeapon, getTorpedoAutoUpdateDepthByDiff } = require("%scripts/weaponry/weaponryInfo.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { loadHandler, handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { move_mouse_on_obj } = require("%sqDagui/daguiUtil.nut")
let { getCurrentPreset, bombNbr, hasCountermeasures, hasBombDelayExplosion } = require("%scripts/unit/unitWeaponryInfo.nut")
let { isTripleColorSmokeAvailable } = require("%scripts/options/optionsManager.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getCdBaseDifficulty, set_gui_option, get_gui_option } = require("guiOptions")
let { getActionBarUnitName } = require("hudActionBar")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { select_training_mission, get_meta_mission_info_by_name } = require("guiMission")
let { isPreviewingLiveSkin, setCurSkinToHangar
} = require("%scripts/customization/skins.nut")
let { stripTags } = require("%sqstd/string.nut")
let { set_option, get_option, create_options_container } = require("%scripts/options/optionsExt.nut")
let { sendStartTestFlightToBq } = require("%scripts/missionBuilder/testFlightBQInfo.nut")
let { getUnitName, getBattleTypeByUnit } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk, get_unittags_blk } = require("blkGetters")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { buildUnitSlot, fillUnitSlotTimers, getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { getCurSlotbarUnit } = require("%scripts/slotbar/slotbarState.nut")
let { isUnitInSlotbar, isUnitAvailableForGM } = require("%scripts/unit/unitInSlotbarStatus.nut")
let { guiStartBuilder, guiStartFlight, guiStartCdOptions
} = require("%scripts/missions/startMissionsList.nut")
let { currentCampaignMission } = require("%scripts/missions/missionsStates.nut")
let { getCurrentGameModeEdiff } = require("%scripts/gameModes/gameModeManagerState.nut")
let { hasInWishlist, isWishlistFull } = require("%scripts/wishlist/wishlistManager.nut")
let { addToWishlist } = require("%scripts/wishlist/addWishWnd.nut")
let DataBlock = require("DataBlock")
let { unitNameForWeapons } = require("%scripts/weaponry/unitForWeapons.nut")
let { enable_current_modifications, updateBulletCountOptions } = require("%scripts/weaponry/weaponryActions.nut")
let { checkQueueAndStart } = require("%scripts/queue/queueManager.nut")
let { getMaxPlayersForGamemode } = require("%scripts/missions/missionsUtils.nut")
let { checkDiffPkg } = require("%scripts/clientState/contentPacks.nut")
let { canJoinFlightMsgBox } = require("%scripts/squads/squadUtils.nut")
let { isTestFlightAvailable } = require("%scripts/unit/unitStatus.nut")
let { missionBuilderVehicleConfigForBlk } = require("%scripts/missionBuilder/testFlightState.nut")

function mergeToBlk(sourceTable, blk) {
  foreach (idx, val in sourceTable)
    blk[idx] = val
}

gui_handlers.TestFlight <- class (gui_handlers.GenericOptionsModal) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/options/genericOptionsModal.blk"
  sceneNavBlkName = "%gui/navTestflight.blk"
  multipleInstances = false
  wndGameMode = GM_TEST_FLIGHT
  wndOptionsMode = OPTIONS_MODE_TRAINING
  afterCloseFunc = null
  shouldSkipUnitCheck = false

  unit = null
  needSlotbar = true

  weaponsSelectorWeak = null
  hasMissionBuilder = true

  slobarActions = ["autorefill", "aircraft", "crew", "weapons", "repair"]

  function initScreen() {
    this.unit = this.unit ?? showedUnit.get()
    if (!this.unit)
      return this.goBack()

    gui_handlers.GenericOptions.initScreen.bindenv(this)()

    let btnBuilder = showObjById("btn_builder", this.hasMissionBuilder, this.scene)
    if (this.hasMissionBuilder)
      btnBuilder.setValue(loc("mainmenu/btnBuilder"))
    showObjById("btn_select", true, this.scene)
    this.updateWishlistButton()
    this.needSlotbar = this.needSlotbar && !isPreviewingLiveSkin() && isUnitInSlotbar(this.unit)
    if (this.needSlotbar) {
      let frameObj = this.scene.findObject("wnd_frame")
      frameObj.size = "1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar"
      frameObj.pos = "50%pw-50%w, 1@battleBtnBottomOffset-h"
      frameObj.withSlotbar = "yes"
    }

    showObjById("unit_weapons_selector", true, this.scene)
    this.guiScene.applyPendingChanges(false)

    this.guiScene.setUpdatesEnabled(false, false)

    this.updateAircraft()

    this.guiScene.setUpdatesEnabled(true, true)

    if (this.needSlotbar) {
      switchProfileCountry(this.unit.shopCountry) 
      showedUnit.set(this.unit) 
      this.createSlotbar()
    }
    else {
      let unitNestObj = this.scene.findObject("unit_nest")
      if (checkObj(unitNestObj)) {
        let airData = buildUnitSlot(this.unit.name, this.unit)
        this.guiScene.appendWithBlk(unitNestObj, airData, this)
        fillUnitSlotTimers(unitNestObj.findObject(this.unit.name), this.unit)
      }
    }

    move_mouse_on_obj(this.scene.findObject("btn_select"))
  }

  function onChangeTorpedoDiveDepth(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
  }

  function onChangeRadarModeSelectedUnit(obj) {
    set_option_radar_name(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get()), obj.getValue())

    this.updateOption(USEROPT_RADAR_SCAN_PATTERN_SELECTED_UNIT_SELECT)
    this.updateOption(USEROPT_RADAR_SCAN_RANGE_SELECTED_UNIT_SELECT)
  }

  function onChangeRadarScanRangeSelectedUnit(obj) {
    set_option_radar_scan_pattern_name(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get()), obj.getValue())

    this.updateOption(USEROPT_RADAR_SCAN_RANGE_SELECTED_UNIT_SELECT)
  }

  function updateLinkedOptions() {
    this.checkBulletsRows()
    this.updateWeaponOptions()
    this.updateTripleAerobaticsSmokeOptions()
  }

  function updateWeaponOptions() {
    this.checkRocketDisctanceFuseRow()
    this.checkBombActivationTimeRow()
    this.checkBombSeriesRow()
    this.checkDepthChargeActivationTimeRow()
    this.updateTorpedoDiveDepth()
    this.updateCountermeasureOptions()
  }

  function updateCountermeasureOptions() {
    this.checkCountermeasurePeriodsRow()
    this.checkCountermeasureSeriesRow()
    this.checkCountermeasureSeriesPeriodsRow()
  }

  function checkBulletsRows() {
    let unitName = unitNameForWeapons.get() ?? ""
    if (unitName == "")
      return
    let air = getAircraftByName(unitName)
    if (!air)
      return

    let bulletGroups = this.weaponsSelectorWeak?.getBulletsGroups() ?? []
    foreach (_idx, bulGroup in bulletGroups)
      this.showOptionRow(bulGroup.getOption(), bulGroup.active)
  }

  function updateWeaponsSelector(isForceUpdate = false) {
    if (this.weaponsSelectorWeak) {
      this.weaponsSelectorWeak.setUnit(this.unit, isForceUpdate)
      return
    }

    let weaponryObj = this.scene.findObject("unit_weapons_selector")
    let isUnitUsable = this.unit.isUsable()
    let isUntSpecial = isUnitSpecial(this.unit)

    let handler = loadHandler(gui_handlers.unitWeaponsHandler, {
      scene = weaponryObj
      unit = this.unit
      isForcedAvailable = isUntSpecial && !isUnitUsable
      forceShowDefaultTorpedoes = !isUntSpecial && !isUnitUsable
      getCurrentEdiff = Callback(@() this.getCurrentEdiff(), this)
    })

    this.weaponsSelectorWeak = handler.weakref()
    this.registerSubHandler(handler)
  }

  function getCantFlyText(checkUnit) {
    return !checkUnit.unitType.isAvailable() ?
      loc("mainmenu/unitTypeLocked") : checkUnit.unitType.getTestFlightUnavailableText()
  }

  function updateOptionsArray() {
    if (this.optionsConfig == null) {
      let diffOpt = get_option(USEROPT_DIFFICULTY)
      this.optionsConfig = { diffCode = diffOpt.diffCode[diffOpt.value] }
    }
    this.options = [
      [USEROPT_DIFFICULTY, "spinner"],
    ]

    let isAir = this.unit?.isAir()
    let isHelicopter = this.unit?.isHelicopter()
    if ((isAir || isHelicopter) && this.unit.testFlight == "") {
      this.options.append([USEROPT_TEST_FLIGHT_NAME, "spinner"], [USEROPT_AIR_SPAWN_POINT, "spinner"])
      if (isAir)
        this.options.append([USEROPT_TARGET_RANK, "spinner"])
    }

    if (isAir || isHelicopter) {
      this.options.append([USEROPT_LIMITED_FUEL, "spinner"])
      this.options.append([USEROPT_LIMITED_AMMO, "spinner"])
    }

    let skin_options = [
      [USEROPT_SKIN, "spinner"]
    ]
    if (hasFeature("UserSkins"))
      skin_options.append([USEROPT_USER_SKIN, "spinner"])

    this.options.extend(skin_options)

    if (isAir)
      this.options.append(
        [USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner"]
      )

    if (isAir || isHelicopter)
      this.options.append(
        [USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        [USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        [USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [USEROPT_BOMB_SERIES, "spinner"],
        [USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
        [USEROPT_FUEL_AMOUNT_CUSTOM, "slider"],
        [USEROPT_COUNTERMEASURES_SERIES_PERIODS, "spinner"],
        [USEROPT_COUNTERMEASURES_PERIODS, "spinner"],
        [USEROPT_COUNTERMEASURES_SERIES, "spinner"],
      )

    if (this.unit?.isShipOrBoat() || isAir) {
      this.options.append(
        [USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner"],
        [USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [USEROPT_TORPEDO_DIVE_DEPTH, "spinner"]
      )
    }

    let radarModesCount = get_radar_mode_names(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get())).len()

    if (hasFeature("allowRadarModeOptions") && radarModesCount > 0
      && (radarModesCount > 1
        || get_radar_scan_pattern_names(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get())).len() > 1
        || get_radar_range_values(unitNameForWeapons.get(), getLastWeapon(unitNameForWeapons.get())).len() > 1)) {
      this.options.append(
        [USEROPT_RADAR_MODE_SELECTED_UNIT_SELECT, "spinner"],
        [USEROPT_RADAR_SCAN_PATTERN_SELECTED_UNIT_SELECT, "spinner"],
        [USEROPT_RADAR_SCAN_RANGE_SELECTED_UNIT_SELECT, "spinner"]
      )
    }

    this.options.append(
      [USEROPT_MODIFICATIONS, "spinner"],
      [USEROPT_TIME, "spinner"],
      [USEROPT_CLIME, "spinner"]
    )
    return this.options
  }

  function updateAircraft() {
    this.updateButtons()

    let showOptions = this.isTestFlightAvailableImpl()

    let optListObj = this.scene.findObject("optionslist")
    let textObj = this.scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions ? "" : this.getCantFlyText(this.unit))

    let hObj = this.scene.findObject("header_name")
    if (!checkObj(hObj))
      return

    let headerText = " ".concat(this.unit.unitType.getTestFlightText(), loc("ui/mdash"), getUnitName(this.unit.name))
    hObj.setValue(headerText)

    if (!showOptions)
      return

    unitNameForWeapons.set(this.unit.name)
    this.updateOptionsArray()

    set_gui_option(USEROPT_AIRCRAFT, this.unit.name)

    let container = create_options_container("testflight_options", this.options, true, 0.5, true, this.optionsConfig)
    this.guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)

    this.optionsContainers = [container.descr]
    this.updateLinkedOptions()
    this.setDifficultyOption()
    this.updateWeaponsSelector()
  }

  function isBuilderAvailable() {
    return isUnitAvailableForGM(this.unit, GM_BUILDER)
  }

  function isTestFlightAvailableImpl() {
    return isTestFlightAvailable(this.unit, this.shouldSkipUnitCheck)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    this.scene.findObject("btn_builder").inactiveColor = this.isBuilderAvailable() ? "no" : "yes"
    this.scene.findObject("btn_select").inactiveColor = this.isTestFlightAvailableImpl() ? "no" : "yes"
  }

  function onMissionBuilder() {
    if (!canJoinFlightMsgBox({
        maxSquadSize = getMaxPlayersForGamemode(GM_BUILDER)
      }))
      return

    if (!this.isBuilderAvailable()) {
      this.saveAircraftOptions()

      if (this.needSlotbar) 
        this.msgBox("not_available",
          loc(getCurSlotbarUnit() == null ? "events/empty_crew" : "msg/builderOnlyForAircrafts"),
          [["ok"]], "ok")
      else
        loadHandler(gui_handlers.changeAircraftForBuilder, { shopAir = this.unit })
      return
    }

    this.applyFunc = function() {
      this.saveAircraftOptions()

      guiStartBuilder()
      this.applyFunc = null
    }
    this.applyOptions()
  }

  function onApply(_obj) {
    if (!!this.weaponsSelectorWeak && !this.weaponsSelectorWeak?.checkChosenBulletsCount())
      return

    broadcastEvent("BeforeStartTestFlight")

    if (g_squad_manager.isNotAloneOnline())
      return this.onMissionBuilder()

    if (!this.isTestFlightAvailableImpl())
      return this.msgBox("not_available", this.getCantFlyText(this.unit), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })

    if (isInArray(this.getSceneOptValue(USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!checkDiffPkg(g_difficulty.SIMULATOR.diffCode))
        return

    if (this.unit)
      set_gui_option(USEROPT_WEAPONS, getLastWeapon(this.unit.name))

    if (isInSessionRoom.get())
      return this.goBack()

    checkQueueAndStart(
      Callback(function() {
        this.applyFunc = function() {
          if (get_gui_option(USEROPT_DIFFICULTY) == "custom") {
            guiStartCdOptions(this.startTestFlight, this) 
            this.doWhenActiveOnce("updateSceneDifficulty")
          }
          else
            this.startTestFlight()
          this.applyFunc = null
        }
        this.applyOptions()
      }, this)
      null
      "isCanNewflight"
    )
  }

  function onEventSquadStatusChanged(_params) {
    this.updateButtons()
  }

  function startTestFlight() {
    local testFlightName = this.unit.testFlight
    let isAir = this.unit.isAir()
    let isHelicopter = this.unit.isHelicopter()
    let isUniversalTestFlight = (isAir || isHelicopter) && testFlightName == ""
    if (isUniversalTestFlight) {
      let testFlightNameOpt = get_option(USEROPT_TEST_FLIGHT_NAME)
      testFlightName = testFlightNameOpt.values[testFlightNameOpt.value]
    }
    let misName = this.getTestFlightMisName(testFlightName)
    let misBlkBase = get_meta_mission_info_by_name(misName)
    if (!misBlkBase)
      return assert(false,$"Error: wrong testflight mission {misName}")

    currentCampaignMission.set(misName)

    this.saveAircraftOptions()
    setCurSkinToHangar(this.unit.name)

    let misBlk = DataBlock()
    misBlk.setFrom(misBlkBase)
    mergeToBlk({
        _gameMode = GM_TEST_FLIGHT
        name      = misName
        chapter   = "training"
        takeOffOnStart = false
        weather     = this.getSceneOptValue(USEROPT_CLIME)
        environment = this.getSceneOptValue(USEROPT_TIME)
      }, misBlk)

    if (isUniversalTestFlight) {
      let airSpawnOpt = get_option(USEROPT_AIR_SPAWN_POINT)
      let airSpawnValue = airSpawnOpt.values[airSpawnOpt.value]
      misBlk.is_airfield_spawn = airSpawnValue == AIR_SPAWN_POINT.AIRFIELD
      misBlk.is_ship_spawn = airSpawnValue == AIR_SPAWN_POINT.CARRIER
      misBlk.is_water_spawn = airSpawnValue == AIR_SPAWN_POINT.ON_WATER
      misBlk.air_spawn_point = airSpawnValue

      if (isAir) {
        let targetRankIndex = get_gui_option(USEROPT_TARGET_RANK)
        misBlk.target_rank_index = targetRankIndex + 1
      }
      let testFlightShip = get_unittags_blk()?[this.unit.name].testFlightShip ?? ""
      if (testFlightShip != "")
        misBlk.aircraft_ship_name = testFlightShip
    }

    mergeToBlk(missionBuilderVehicleConfigForBlk, misBlk)

    select_training_mission(misBlk)
    actionBarInfo.cacheActionDescs(getActionBarUnitName())

    this.guiScene.performDelayed(this, guiStartFlight)

    sendStartTestFlightToBq(this.unit.name)
  }

  function getTestFlightMisName(misName) {
    let lang = getLanguageName()
    return get_game_settings_blk()?.testFlight_override?[lang]?[misName] ?? misName
  }

  function saveAircraftOptions() {
    if (!this.unit)
      return

    let dif = get_option(USEROPT_DIFFICULTY)
    let difValue = dif.values[dif.value]

    let skin = get_option(USEROPT_SKIN)
    let skinValue = skin.values[skin.value]
    let isAirOrHelicopter = this.unit.isAir() || this.unit.isHelicopter()

    let fuelValue = !isAirOrHelicopter ? 0
      : this.getSceneOptValue(USEROPT_LOAD_FUEL_AMOUNT)
    let isLimitedFuel = !isAirOrHelicopter ? false
      : get_option(USEROPT_LIMITED_FUEL).value
    let isLimitedAmmo = !isAirOrHelicopter ? false
      : get_option(USEROPT_LIMITED_AMMO).value

    let unitName = this.unit.name
    unitNameForWeapons.set(unitName)

    let bulletGroups = this.weaponsSelectorWeak?.getBulletsGroups() ?? []
    updateBulletCountOptions(this.unit, bulletGroups)

    enable_bullets_modifications(unitName)
    enable_current_modifications(unitName)

    missionBuilderVehicleConfigForBlk.__update({
        selectedSkin = skinValue
        difficulty = difValue
        isLimitedFuel
        isLimitedAmmo
        fuelAmount = (fuelValue.tofloat() / 1000000.0)
    })
  }

  function updateFuelAmount() {
    this.updateOption(USEROPT_LOAD_FUEL_AMOUNT)

    this.updateOption(USEROPT_FUEL_AMOUNT_CUSTOM)
    let fuelSliderObj = this.scene.findObject("adjustable_fuel_quantity")
    this.updateOptionValueTextByObj(fuelSliderObj)
  }

  function setDifficultyOption(diffOptValue = null) {
    let diffOptionCont = this.findOptionInContainers(USEROPT_DIFFICULTY)
    let diffOptValueToSet = diffOptValue ?? diffOptionCont.value

    set_option(USEROPT_DIFFICULTY, diffOptValueToSet, diffOptionCont)
    this.optionsConfig.diffCode <- diffOptionCont.diffCode[diffOptValueToSet]
  }

  function onDifficultyChange(obj) {
    this.updateVerticalTargetingOption()
    this.updateSceneDifficulty()

    this.setDifficultyOption(obj.getValue())

    this.updateOption(USEROPT_TORPEDO_DIVE_DEPTH)
    this.updateTorpedoDiveDepth()

    this.updateFuelAmount()
    this.updateOption(USEROPT_BOMB_ACTIVATION_TIME)
    this.updateWeaponsSelector(true)
  }

  function updateSceneDifficulty() {
    if (this.getSlotbar())
      this.getSlotbar().updateDifficulty()

    let unitNestObj = this.unit ? this.scene.findObject("unit_nest") : null
    if (checkObj(unitNestObj)) {
      let obj = unitNestObj.findObject("rank_text")
      if (checkObj(obj))
        obj.setValue(getUnitSlotRankText(this.unit, null, true, this.getCurrentEdiff()))
    }
  }

  function getCurrentEdiff() {
    let diffValue = this.getSceneOptValue(USEROPT_DIFFICULTY)
    let difficulty = (diffValue == "custom") ?
      g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1) {
      let battleType = getBattleTypeByUnit(this.unit)
      return difficulty.getEdiff(battleType)
    }
    return getCurrentGameModeEdiff()
  }

  function afterModalDestroy() {
    if (this.afterCloseFunc)
      this.afterCloseFunc()
  }

  function onEventCrewChanged(_p) {
    this.doWhenActiveOnce("setUnitFromSlotbar")
  }

  function onEventCountryChanged(_p) {
    this.doWhenActiveOnce("setUnitFromSlotbar")
  }

  function setUnitFromSlotbar() {
    if (!this.needSlotbar)
      return

    let crewUnit = getCurSlotbarUnit()
    if (crewUnit == this.unit || crewUnit == null) {
      this.updateButtons()
      return
    }

    this.applyFunc = Callback(function() {
        this.unit = crewUnit
        this.updateAircraft()
        this.applyFunc = null
      },
      this)

    this.applyOptions()
  }

  function onUserModificationsUpdate(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    if (option.value == obj.getValue())
      return

    this.guiScene.performDelayed(this, function() {
      set_option(option.type, obj.getValue())
      this.updateOption(option.type)
      enable_bullets_modifications(this.unit.name)
      enable_current_modifications(this.unit.name)
      broadcastEvent("UnitWeaponChanged", { unitName = this.unit.name })
      broadcastEvent("ModificationChanged")
    })
  }

  function onMyWeaponOptionUpdate(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
    if ("hints" in option)
      obj.tooltip = option.hints[ obj.getValue() ]
    else if ("hint" in option)
      obj.tooltip = stripTags(loc(option.hint, ""))
    this.checkBulletsRows()
    this.updateWeaponOptions()
  }

  function onTripleAerobaticsSmokeSelected(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
    this.updateTripleAerobaticsSmokeOptions()
  }

  function onTestFlightNameChange(obj) {
    let option = this.get_option_by_id(obj?.id)
    if (!option)
      return

    set_option(option.type, obj.getValue(), option)
    this.updateOption(USEROPT_AIR_SPAWN_POINT)
  }

  function checkRocketDisctanceFuseRow() {
    let option = this.findOptionInContainers(USEROPT_ROCKET_FUSE_DIST)
    if (!option)
      return

    this.showOptionRow(option, !!this.unit && (getCurrentPreset(this.unit)?.hasRocketDistanceFuse ?? false))
  }

  function checkBombActivationTimeRow() {
    let option = this.findOptionInContainers(USEROPT_BOMB_ACTIVATION_TIME)
    if (!option)
      return

    this.showOptionRow(option, hasBombDelayExplosion(this.unit))
  }

  function checkBombSeriesRow() {
    let option = this.findOptionInContainers(USEROPT_BOMB_SERIES)
    if (!option)
      return

    this.showOptionRow(option, bombNbr(this.unit) > 1)

    this.updateOption(USEROPT_BOMB_SERIES)
  }

  function checkCountermeasurePeriodsRow() {
    let option = get_option(USEROPT_COUNTERMEASURES_PERIODS)
    if (option)
      this.showOptionRow(option, hasCountermeasures(this.unit))
  }

  function checkCountermeasureSeriesRow() {
    let option = get_option(USEROPT_COUNTERMEASURES_SERIES)
    if (option)
      this.showOptionRow(option, hasCountermeasures(this.unit))
  }

  function checkCountermeasureSeriesPeriodsRow() {
    let option = get_option(USEROPT_COUNTERMEASURES_SERIES_PERIODS)
    if (option)
      this.showOptionRow(option, hasCountermeasures(this.unit))
  }

  function checkDepthChargeActivationTimeRow() {
    let option = this.findOptionInContainers(USEROPT_DEPTHCHARGE_ACTIVATION_TIME)
    if (!option)
      return

    this.showOptionRow(option, this.unit?.isDepthChargeAvailable?()
      && (getCurrentPreset(this.unit)?.hasDepthCharge ?? false))
  }

  function updateTripleAerobaticsSmokeOptions() {
    let aerobaticsSmokeOptions = this.find_options_in_containers([
      USEROPT_AEROBATICS_SMOKE_LEFT_COLOR,
      USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR,
      USEROPT_AEROBATICS_SMOKE_TAIL_COLOR
    ])

    if (!aerobaticsSmokeOptions.len())
      return

    let show = isTripleColorSmokeAvailable()
    foreach (option in aerobaticsSmokeOptions)
      this.showOptionRow(option, show)
  }

  function updateTorpedoDiveDepth() {
    let option = this.findOptionInContainers(USEROPT_TORPEDO_DIVE_DEPTH)
    if (!option)
      return

    this.showOptionRow(option, !getTorpedoAutoUpdateDepthByDiff(this.getCurrentEdiff())
      && (getCurrentPreset(this.unit)?.torpedo ?? false))

    let depthOptIdx = this.optionsConfig.diffCode == g_difficulty.ARCADE.diffCode
      ? (option.values.findindex(@(v) v == option.defaultValue) ?? 0)
      : option.value
    set_option(option.type, depthOptIdx, option)
  }

  function updateVerticalTargetingOption() {
    let optList = this.find_options_in_containers([USEROPT_GUN_VERTICAL_TARGETING])
    if (!optList.len())
      return
    let diffName = this.getOptValue(USEROPT_DIFFICULTY, false)
    if (diffName == null) 
      return

    foreach (option in optList)
      this.showOptionRow(option, diffName != g_difficulty.ARCADE.name)
  }

  function onEventUnitWeaponChanged(_p) {
    this.updateWeaponOptions()
    this.updateFuelAmount()
  }

  function onEventModificationChanged(_p) {
    this.doWhenActiveOnce("updateCountermeasureOptions")
  }

  function onEventModificationPurchased(_p) {
    this.doWhenActiveOnce("updateCountermeasureOptions")
  }

  function onAddToWishlist() {
    if(isWishlistFull())
      return showInfoMsgBox(colorize("activeTextColor", loc("wishlist/wishlist_full")))

    addToWishlist(this.unit)
  }

  function updateWishlistButton() {
    showObjById("btn_add_to_wishlist", hasFeature("Wishlist") && !hasInWishlist(this.unit.name) && !this.unit.isBought(), this.scene)
    if(isWishlistFull())
      this.scene.findObject("btn_add_to_wishlist")["status"] = "red"
  }

  function onEventAddedToWishlist(_p) {
    this.updateWishlistButton()
  }

  function getHandlerRestoreData() {
    return {
      openData = {
        unit = this.unit
        afterCloseFunc = this.afterCloseFunc
        shouldSkipUnitCheck = this.shouldSkipUnitCheck
      }
    }
  }

  function saveOptionsBeforeCloseWindow() {
    this.applyOptions()
  }

  function onEventBeforeOpenWeaponryPresetsWnd(_) {
    this.saveOptionsBeforeCloseWindow()
    handlersManager.requestHandlerRestore(this)
  }
}