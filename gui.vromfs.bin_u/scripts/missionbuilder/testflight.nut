//-file:plus-string
from "%scripts/dagui_library.nut" import *
from "%scripts/options/optionsExtNames.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { handlerType } = require("%sqDagui/framework/handlerType.nut")
let { move_mouse_on_obj, handlersManager, loadHandler } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { bombNbr, hasCountermeasures, getCurrentPreset, hasBombDelayExplosion } = require("%scripts/unit/unitStatus.nut")
let { isTripleColorSmokeAvailable } = require("%scripts/options/optionsManager.nut")
let actionBarInfo = require("%scripts/hud/hudActionBarInfo.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { getCdBaseDifficulty, set_unit_option, set_gui_option, get_gui_option } = require("guiOptions")
let { getActionBarUnitName } = require("hudActionBar")
let { switchProfileCountry } = require("%scripts/user/playerCountry.nut")
let { select_training_mission, get_meta_mission_info_by_name } = require("guiMission")
let { isPreviewingLiveSkin, setCurSkinToHangar
} = require("%scripts/customization/skins.nut")
let { stripTags } = require("%sqstd/string.nut")
let { set_option, create_options_container } = require("%scripts/options/optionsExt.nut")
let { sendStartTestFlightToBq } = require("%scripts/missionBuilder/testFlightBQInfo.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { get_game_settings_blk } = require("blkGetters")
let { isInSessionRoom } = require("%scripts/matchingRooms/sessionLobbyState.nut")
let { getLanguageName } = require("%scripts/langUtils/language.nut")
let { buildUnitSlot, fillUnitSlotTimers, getUnitSlotRankText } = require("%scripts/slotbar/slotbarView.nut")
let { getCurSlotbarUnit, isUnitInSlotbar } = require("%scripts/slotbar/slotbarState.nut")

::missionBuilderVehicleConfigForBlk <- {} //!!FIX ME: Should to remove this
::last_called_gui_testflight <- null

::gui_start_testflight <- function gui_start_testflight(params = {}) {
  loadHandler(gui_handlers.TestFlight, params)
  ::last_called_gui_testflight = handlersManager.getLastBaseHandlerStartParams()
}

::mergeToBlk <- function mergeToBlk(sourceTable, blk) {  //!!FIX ME: this used only for missionBuilderVehicleConfigForBlk and better to remove this also
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
    this.unit = this.unit ?? showedUnit.value
    if (!this.unit)
      return this.goBack()

    gui_handlers.GenericOptions.initScreen.bindenv(this)()

    let btnBuilder = this.showSceneBtn("btn_builder", this.hasMissionBuilder)
    if (this.hasMissionBuilder)
      btnBuilder.setValue(loc("mainmenu/btnBuilder"))
    this.showSceneBtn("btn_select", true)

    this.needSlotbar = this.needSlotbar && !isPreviewingLiveSkin() && isUnitInSlotbar(this.unit)
    if (this.needSlotbar) {
      let frameObj = this.scene.findObject("wnd_frame")
      frameObj.size = "1@slotbarWidthFull, 1@maxWindowHeightWithSlotbar"
      frameObj.pos = "50%pw-50%w, 1@battleBtnBottomOffset-h"
      frameObj.withSlotbar = "yes"
    }

    this.showSceneBtn("unit_weapons_selector", true)
    this.guiScene.applyPendingChanges(false)

    this.guiScene.setUpdatesEnabled(false, false)

    this.updateAircraft()

    this.guiScene.setUpdatesEnabled(true, true)

    if (this.needSlotbar) {
      switchProfileCountry(this.unit.shopCountry) //select country for slotbar
      showedUnit(this.unit) //select unit for slotbar
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
    if (type(::aircraft_for_weapons) != "string")
      return
    let air = getAircraftByName(::aircraft_for_weapons)
    if (!air)
      return

    let bulletGroups = this.weaponsSelectorWeak?.bulletsManager.getBulletsGroups() ?? []
    foreach (_idx, bulGroup in bulletGroups)
      this.showOptionRow(bulGroup.getOption(), bulGroup.active)
  }

  function updateWeaponsSelector() {
    if (this.weaponsSelectorWeak) {
      this.weaponsSelectorWeak.setUnit(this.unit)
      return
    }

    let weaponryObj = this.scene.findObject("unit_weapons_selector")
    let isUnitUsable = this.unit.isUsable()
    let isUnitSpecial = ::isUnitSpecial(this.unit)

    let handler = loadHandler(gui_handlers.unitWeaponsHandler, {
      scene = weaponryObj
      unit = this.unit
      isForcedAvailable = isUnitSpecial && !isUnitUsable
      forceShowDefaultTorpedoes = !isUnitSpecial && !isUnitUsable
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
      let diffOpt = ::get_option(USEROPT_DIFFICULTY)
      this.optionsConfig = { diffCode = diffOpt.diffCode[diffOpt.value] }
    }
    this.options = [
      [USEROPT_DIFFICULTY, "spinner"],
    ]
    if (this.unit?.isAir() || this.unit?.isHelicopter?()) {
      this.options.append([USEROPT_LIMITED_FUEL, "spinner"])
      this.options.append([USEROPT_LIMITED_AMMO, "spinner"])
    }

    let skin_options = [
      [USEROPT_SKIN, "spinner"]
    ]
    if (hasFeature("UserSkins"))
      skin_options.append([USEROPT_USER_SKIN, "spinner"])

    this.options.extend(skin_options)

    if (this.unit?.isAir())
      this.options.append(
        [USEROPT_AEROBATICS_SMOKE_TYPE, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_LEFT_COLOR, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_RIGHT_COLOR, "spinner"],
        [USEROPT_AEROBATICS_SMOKE_TAIL_COLOR, "spinner"]
      )

    if (this.unit?.isAir() || this.unit?.isHelicopter?())
      this.options.append(
        [USEROPT_GUN_TARGET_DISTANCE, "spinner"],
        [USEROPT_GUN_VERTICAL_TARGETING, "spinner"],
        [USEROPT_BOMB_ACTIVATION_TIME, "spinner"],
        [USEROPT_BOMB_SERIES, "spinner"],
        [USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [USEROPT_LOAD_FUEL_AMOUNT, "spinner"],
        [USEROPT_COUNTERMEASURES_SERIES_PERIODS, "spinner"],
        [USEROPT_COUNTERMEASURES_PERIODS, "spinner"],
        [USEROPT_COUNTERMEASURES_SERIES, "spinner"]
      )

    if (this.unit?.isShipOrBoat()) {
      this.options.append(
        [USEROPT_DEPTHCHARGE_ACTIVATION_TIME, "spinner"],
        [USEROPT_ROCKET_FUSE_DIST, "spinner"],
        [USEROPT_TORPEDO_DIVE_DEPTH, "spinner"]
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
    this.updateWeaponsSelector()

    let showOptions = this.isTestFlightAvailable()

    let optListObj = this.scene.findObject("optionslist")
    let textObj = this.scene.findObject("no_options_textarea")
    optListObj.show(showOptions)
    textObj.setValue(showOptions ? "" : this.getCantFlyText(this.unit))

    let hObj = this.scene.findObject("header_name")
    if (!checkObj(hObj))
      return

    let headerText = this.unit.unitType.getTestFlightText() + " " + loc("ui/mdash") + " " + getUnitName(this.unit.name)
    hObj.setValue(headerText)

    if (!showOptions)
      return

    this.updateOptionsArray()

    ::update_test_flight_unit_info({unit = this.unit})
    ::cur_aircraft_name = this.unit.name
    ::aircraft_for_weapons = this.unit.name
    set_gui_option(USEROPT_AIRCRAFT, this.unit.name)

    let container = create_options_container("testflight_options", this.options, true, 0.5, true, this.optionsConfig)
    this.guiScene.replaceContentFromText(optListObj, container.tbl, container.tbl.len(), this)

    this.optionsContainers = [container.descr]
    this.updateLinkedOptions()
  }

  function isBuilderAvailable() {
    return ::isUnitAvailableForGM(this.unit, GM_BUILDER)
  }
  function isTestFlightAvailable() {
    return ::isTestFlightAvailable(this.unit, this.shouldSkipUnitCheck)
  }

  function updateButtons() {
    if (!checkObj(this.scene))
      return

    this.scene.findObject("btn_builder").inactiveColor = this.isBuilderAvailable() ? "no" : "yes"
    this.scene.findObject("btn_select").inactiveColor = this.isTestFlightAvailable() ? "no" : "yes"
  }

  function onMissionBuilder() {
    if (!::g_squad_utils.canJoinFlightMsgBox({
        isLeaderCanJoin = ::enable_coop_in_QMB
        maxSquadSize = ::get_max_players_for_gamemode(GM_BUILDER)
      }))
      return

    if (!this.isBuilderAvailable()) {
      this.saveAircraftOptions()

      if (this.needSlotbar) // There is a slotbar in this scene
        this.msgBox("not_available",
          loc(getCurSlotbarUnit() == null ? "events/empty_crew" : "msg/builderOnlyForAircrafts"),
          [["ok"]], "ok")
      else
        loadHandler(gui_handlers.changeAircraftForBuilder, { shopAir = this.unit })
      return
    }

    this.applyFunc = function() {
      this.saveAircraftOptions()

      ::gui_start_builder()
      this.applyFunc = null
    }
    this.applyOptions()
  }

  function onApply(_obj) {
    let bulletsManager = this.weaponsSelectorWeak?.bulletsManager
    if (!bulletsManager || !bulletsManager.checkChosenBulletsCount())
      return

    broadcastEvent("BeforeStartTestFlight")

    if (::g_squad_manager.isNotAloneOnline())
      return this.onMissionBuilder()

    if (!this.isTestFlightAvailable())
      return this.msgBox("not_available", this.getCantFlyText(this.unit), [["ok", function() {} ]], "ok", { cancel_fn = function() {} })

    if (isInArray(this.getSceneOptValue(USEROPT_DIFFICULTY), ["hardcore", "custom"]))
      if (!::check_diff_pkg(::g_difficulty.SIMULATOR.diffCode))
        return

    if (this.unit)
      set_gui_option(USEROPT_WEAPONS, getLastWeapon(this.unit.name))

    if (isInSessionRoom.get())
      return this.goBack()

    ::queues.checkAndStart(
      Callback(function() {
        this.applyFunc = function() {
          if (get_gui_option(USEROPT_DIFFICULTY) == "custom") {
            ::gui_start_cd_options(this.startTestFlight, this) // See "MissionDescriptor::loadFromBlk"
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
    let misName = this.getTestFlightMisName(this.unit.testFlight)
    let misBlk = get_meta_mission_info_by_name(misName)
    if (!misBlk)
      return assert(false, "Error: wrong testflight mission " + misName)

    ::current_campaign_mission = misName

    this.saveAircraftOptions()
    setCurSkinToHangar(this.unit.name)

    ::mergeToBlk({
        _gameMode = GM_TEST_FLIGHT
        name      = misName
        chapter   = "training"
        takeOffOnStart = false
        weather     = this.getSceneOptValue(USEROPT_CLIME)
        environment = this.getSceneOptValue(USEROPT_TIME)
      }, misBlk)

    ::mergeToBlk(::missionBuilderVehicleConfigForBlk, misBlk)

    actionBarInfo.cacheActionDescs(getActionBarUnitName())

    select_training_mission(misBlk)
    this.guiScene.performDelayed(this, ::gui_start_flight)

    sendStartTestFlightToBq(this.unit.name)
  }

  function getTestFlightMisName(misName) {
    let lang = getLanguageName()
    return get_game_settings_blk()?.testFlight_override?[lang]?[misName] ?? misName
  }

  function saveAircraftOptions() {
    if (!this.unit)
      return

    let dif = ::get_option(USEROPT_DIFFICULTY)
    let difValue = dif.values[dif.value]

    let skin = ::get_option(USEROPT_SKIN)
    let skinValue = skin.values[skin.value]
    let fuelValue = this.getSceneOptValue(USEROPT_LOAD_FUEL_AMOUNT)
    let limitedFuel = ::get_option(USEROPT_LIMITED_FUEL)
    let limitedAmmo = ::get_option(USEROPT_LIMITED_AMMO)

    ::aircraft_for_weapons = this.unit.name

    this.updateBulletCountOptions(this.unit)

    ::enable_bullets_modifications(::aircraft_for_weapons)
    ::enable_current_modifications(::aircraft_for_weapons)

    ::missionBuilderVehicleConfigForBlk = {
        selectedSkin  = skinValue,
        difficulty    = difValue,
        isLimitedFuel = limitedFuel.value,
        isLimitedAmmo = limitedAmmo.value,
        fuelAmount    = (fuelValue.tofloat() / 1000000.0),
    }
  }

  function updateBulletCountOptions(updUnit) {
    local bulIdx = 0
    let bulletGroups = this.weaponsSelectorWeak ? this.weaponsSelectorWeak.bulletsManager.getBulletsGroups() : []
    foreach (idx, bulGroup in bulletGroups) {
      bulIdx = idx
      local name = ""
      local count = 0
      if (bulGroup.active) {
        name = bulGroup.getBulletNameForCode(bulGroup.selectedName)
        count = bulGroup.bulletsCount * bulGroup.guns
      }
      set_unit_option(updUnit.name, USEROPT_BULLETS0 + bulIdx, name)
      set_option(USEROPT_BULLETS0 + bulIdx, name)
      set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, count)
    }
    ++bulIdx

    while (bulIdx < BULLETS_SETS_QUANTITY) {
      set_unit_option(updUnit.name, USEROPT_BULLETS0 + bulIdx, "")
      set_option(USEROPT_BULLETS0 + bulIdx, "")
      set_gui_option(USEROPT_BULLET_COUNT0 + bulIdx, 0)
      ++bulIdx
    }
  }

  function onDifficultyChange(obj) {
    this.updateVerticalTargetingOption()
    this.updateSceneDifficulty()

    let diffOptionCont = this.findOptionInContainers(USEROPT_DIFFICULTY)
    set_option(USEROPT_DIFFICULTY, obj.getValue(), diffOptionCont)
    this.optionsConfig.diffCode <- diffOptionCont.diffCode[obj.getValue()]
    this.updateOption(USEROPT_LOAD_FUEL_AMOUNT)
    this.updateOption(USEROPT_BOMB_ACTIVATION_TIME)
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
      ::g_difficulty.getDifficultyByDiffCode(getCdBaseDifficulty()) :
      ::g_difficulty.getDifficultyByName(diffValue)
    if (difficulty.diffCode != -1) {
      let battleType = ::get_battle_type_by_unit(this.unit)
      return difficulty.getEdiff(battleType)
    }
    return ::get_current_ediff()
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

    if (option.value != obj.getValue()) {
      this.guiScene.performDelayed(this, function() {
        set_option(option.type, obj.getValue())
        this.updateOption(option.type)
      })
    }

    ::enable_bullets_modifications(this.unit.name)
    ::enable_current_modifications(this.unit.name)
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
    let option = ::get_option(USEROPT_COUNTERMEASURES_PERIODS)
    if (option)
      this.showOptionRow(option, hasCountermeasures(this.unit))
  }

  function checkCountermeasureSeriesRow() {
    let option = ::get_option(USEROPT_COUNTERMEASURES_SERIES)
    if (option)
      this.showOptionRow(option, hasCountermeasures(this.unit))
  }

  function checkCountermeasureSeriesPeriodsRow() {
    let option = ::get_option(USEROPT_COUNTERMEASURES_SERIES_PERIODS)
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

    this.showOptionRow(option, !::get_option_torpedo_dive_depth_auto()
      && this.unit.isShipOrBoat()
      && (getCurrentPreset(this.unit)?.torpedo ?? false))
  }

  function updateVerticalTargetingOption() {
    let optList = this.find_options_in_containers([USEROPT_GUN_VERTICAL_TARGETING])
    if (!optList.len())
      return
    let diffName = this.getOptValue(USEROPT_DIFFICULTY, false)
    if (diffName == null) //no such option in current options list
      return

    foreach (option in optList)
      this.showOptionRow(option, diffName != ::g_difficulty.ARCADE.name)
  }

  function onEventUnitWeaponChanged(_p) {
    this.updateWeaponOptions()
  }

  function onEventModificationChanged(_p) {
    this.doWhenActiveOnce("updateCountermeasureOptions")
  }

  function onEventModificationPurchased(_p) {
    this.doWhenActiveOnce("updateCountermeasureOptions")
  }
}