local subscriptions = require("sqStdlibs/helpers/subscriptions.nut")
local { topMenuHandler } = require("scripts/mainmenu/topMenuStates.nut")
local tutorAction = require("scripts/tutorials/tutorialActions.nut")
local unitTypes = require("scripts/unit/unitTypesList.nut")

class SlotbarPresetsTutorial
{
  /** Total maximum times to show this tutorial. */
  static MAX_TUTORIALS = 3

  /**
   * Not showing tutorial for game mode if user played
   * it more than specified amount of times.
   */
  static MAX_PLAYS_FOR_GAME_MODE = 5

  /**
   * Not showing tutorial new unit type to battle
   * if user played game less this
  */
  static MIN_PLAYS_GAME_FOR_NEW_UNIT_TYPE = 5

  // These parameters must be set from outside.
  currentCountry = null
  currentHandler = null
  onComplete = null
  preset = null // Preset to select.

  currentGameModeId = null
  tutorialGameMode = null

  isNewUnitTypeToBattleTutorial = null

  // Slotbar
  presetsList = null
  validPresetIndex = -1

  // Window
  chooseSlotbarPresetHandler = null
  chooseSlotbarPresetIndex = -1

  // Unit select
  crewIdInCountry = -1 // Slotbar-index of unit to select.

  currentTutorial = null

  currentStepsName = null
  /**
   * Returns false if tutorial was skipped due to some error.
   */
  function startTutorial()
  {
    currentStepsName = "startTutorial"
    currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    if (preset == null)
      return false
    local currentPresetIndex = ::getTblValue(currentCountry, ::slotbarPresets.selected, -1)
    validPresetIndex = getPresetIndex(preset)
    if (currentPresetIndex == validPresetIndex)
      if (isNewUnitTypeToBattleTutorial)
        return startOpenGameModeSelectStep()
      else
        return startUnitSelectStep()
    presetsList = currentHandler.getSlotbarPresetsList()
    if (presetsList == null)
      return false
    local presetObj = presetsList.getListChildByPresetIdx(validPresetIndex)
    local steps
    if (presetObj && presetObj.isVisible()) // Preset is in slotbar presets list.
    {
      currentStepsName = "selectPreset"
      steps = [{
        obj = [presetObj]
        text = createMessageWhithUnitType()
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = ::Callback(onSlotbarPresetSelect, this)
        keepEnv = true
      }]
    }
    else
    {
      local presetsButtonObj = presetsList.getPresetsButtonObj()
      if (presetsButtonObj == null)
        return false
      currentStepsName = "openSlotbarPresetWnd"
      steps = [{
        obj = [presetsButtonObj]
        text = ::loc("slotbarPresetsTutorial/openWindow")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = ::Callback(onChooseSlotbarPresetWnd_Open, this)
        keepEnv = true
      }]
    }
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)

    // Increment tutorial counter.
    ::saveLocalByAccount("tutor/slotbar_presets_tutorial_counter", getCounter() + 1)

    return true
  }

  function onSlotbarPresetSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", onEventSlotbarPresetLoaded, this)
    local listObj = presetsList.getListObj()
    if (listObj != null)
      listObj.setValue(validPresetIndex)
  }

  function onChooseSlotbarPresetWnd_Open()
  {
    if (checkCurrentTutorialCanceled())
      return
    chooseSlotbarPresetHandler = ::gui_choose_slotbar_preset(currentHandler)
    chooseSlotbarPresetIndex = ::find_in_array(::slotbarPresets.presets[currentCountry], preset)
    if (chooseSlotbarPresetIndex == -1)
      return
    local itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
    local presetObj = itemsListObj.getChild(chooseSlotbarPresetIndex)
    if (!::checkObj(presetObj))
      return
    local applyButtonObj = chooseSlotbarPresetHandler.scene.findObject("btn_preset_load")
    if (!::checkObj(applyButtonObj))
      return
    local steps = [{
      obj = [presetObj]
      text = createMessageWhithUnitType()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onChooseSlotbarPresetWnd_Select, this)
      keepEnv = true
    } {
      obj = [applyButtonObj]
      text = ::loc("slotbarPresetsTutorial/pressApplyButton")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onChooseSlotbarPresetWnd_Apply, this)
      keepEnv = true
    }]
    currentStepsName = "applySlotbarPresetWnd"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
  }

  function onChooseSlotbarPresetWnd_Select()
  {
    if (checkCurrentTutorialCanceled(false))
      return
    local itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
    itemsListObj.setValue(chooseSlotbarPresetIndex)
    chooseSlotbarPresetHandler.onItemSelect(null)
  }

  function onChooseSlotbarPresetWnd_Apply()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", onEventSlotbarPresetLoaded, this)
    chooseSlotbarPresetHandler.onBtnPresetLoad(null)
  }

  function onEventSlotbarPresetLoaded(params)
  {
    if (checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("SlotbarPresetLoaded", this)

    // Switching preset causes game mode to switch as well.
    // So we need to restore it to it's previous value.
    ::game_mode_manager.setCurrentGameModeById(currentGameModeId)

    // This update shows player that preset was
    // actually changed behind tutorial dim.
    local slotbar = topMenuHandler.value.getSlotbar()
    if (slotbar)
      slotbar.forceUpdate()

    if (!startUnitSelectStep() && !startOpenGameModeSelectStep())
      startPressToBattleButtonStep()
  }

  function onStartPress()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::instant_domination_handler.onStart()
    currentStepsName = "tutorialEnd"
    sendLastStepsNameToBigQuery()
    if (onComplete != null)
      onComplete({ result = "success" })
  }

  function createMessageWhithUnitType(partLocId = "selectPreset")
  {
    local types = ::game_mode_manager.getRequiredUnitTypes(tutorialGameMode)
    local unitType = unitTypes.getByEsUnitType(::u.max(types))
    local unitTypeLocId = "options/chooseUnitsType/" + unitType.lowerName
    return ::loc("slotbarPresetsTutorial/" + partLocId, { unitType = ::loc(unitTypeLocId) })
  }

  function createMessage_pressToBattleButton()
  {
    return ::loc("slotbarPresetsTutorial/pressToBattleButton",
      { gameModeName = tutorialGameMode.text })
  }

  function getPresetIndex(prst)
  {
    local presets = ::getTblValue(currentCountry, ::slotbarPresets.presets, null)
    return ::find_in_array(presets, prst, -1)
  }

  /**
   * This subtutorial for selecting allowed unit within selected preset.
   * Returns false if tutorial was skipped for some reason.
   */
  function startUnitSelectStep()
  {
    local slotbarHandler = currentHandler.getSlotbar()
    if (!slotbarHandler)
      return false
    if (::game_mode_manager.isUnitAllowedForGameMode(::show_aircraft))
      return false
    local currentPreset = ::slotbarPresets.getCurrentPreset(currentCountry)
    if (currentPreset == null)
      return false
    local index = getAllowedUnitIndexByPreset(currentPreset)
    local crews = ::getTblValue("crews", currentPreset, null)
    local crewId = ::getTblValue(index, crews, -1)
    if (crewId == -1)
      return false
    local crew = ::get_crew_by_id(crewId)
    if (!crew)
      return false

    crewIdInCountry = crew.idInCountry
    local steps = [{
      obj = ::get_slot_obj(slotbarHandler.scene, crew.idCountry, crew.idInCountry)
      text = ::loc("slotbarPresetsTutorial/selectUnit")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onUnitSelect, this)
      keepEnv = true
    }]
    currentStepsName = "selectUnit"
    currentTutorial = ::gui_modal_tutor(steps, ::instant_domination_handler, true)
    return true
  }

  function onUnitSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    local slotbar = currentHandler.getSlotbar()
    slotbar.selectCrew(crewIdInCountry)
    if (!startOpenGameModeSelectStep())
      startPressToBattleButtonStep()
  }

  /**
   * Returns -1 if no such unit found.
   */
  function getAllowedUnitIndexByPreset(prst)
  {
    local units = prst?.units
    if (units == null)
      return -1
    for (local i = 0; i < units.len(); ++i)
    {
      local unit = ::getAircraftByName(units[i])
      if (::game_mode_manager.isUnitAllowedForGameMode(unit))
        return i
    }
    return -1
  }

  function startPressToBattleButtonStep()
  {
    if (checkCurrentTutorialCanceled())
      return
    local objs = [
      topMenuHandler.value.scene.findObject("to_battle_button"),
      topMenuHandler.value.getObj("to_battle_console_image")
    ]
    local steps = [{
      obj = [objs]
      text = createMessage_pressToBattleButton()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onStartPress, this)
    }]
    currentStepsName = "pressToBattleButton"
    currentTutorial = ::gui_modal_tutor(steps, ::instant_domination_handler, true)
  }

  function startOpenGameModeSelectStep()
  {
    if (!isNewUnitTypeToBattleTutorial)
      return false
    local currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == tutorialGameMode)
      return false
    local gameModeChangeButtonObj = currentHandler?.gameModeChangeButtonObj
    if (!::check_obj(gameModeChangeButtonObj))
      return false
    local steps = [{
      obj = [gameModeChangeButtonObj]
      text = ::loc("slotbarPresetsTutorial/openGameModeSelect")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onOpenGameModeSelect, this)
      keepEnv = true
    }]
    currentStepsName = "openGameModeSelect"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
    return true
  }

  function onOpenGameModeSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    local gameModeChangeButtonObj = currentHandler?.gameModeChangeButtonObj
    if (!::check_obj(gameModeChangeButtonObj))
      return
    ::add_event_listener("GamercardDrawerOpened", onEventGamercardDrawerOpened, this)
    currentHandler.onOpenGameModeSelect(gameModeChangeButtonObj)
  }

  function onEventGamercardDrawerOpened(params)
  {
    if (checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("GamercardDrawerOpened", this)

    startSelectGameModeStep()
  }

  function startSelectGameModeStep()
  {
    if (checkCurrentTutorialCanceled())
      return
    local gameModeSelectHandler = currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    local gameModeItemId = ::game_mode_manager.getGameModeItemId(tutorialGameMode.id)
    local gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!::check_obj(gameModeObj))
      return

    local steps = [{
      obj = [gameModeObj]
      text = createMessageWhithUnitType("selectGameMode")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = ::Callback(onSelectGameMode, this)
      keepEnv = true
    }]
    currentStepsName = "selectGameMode"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
  }

  function onSelectGameMode()
  {
    if (checkCurrentTutorialCanceled())
      return
    ::add_event_listener("CurrentGameModeIdChanged", onEventCurrentGameModeIdChanged, this)
    local gameModeSelectHandler = currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    local gameModeItemId = ::game_mode_manager.getGameModeItemId(tutorialGameMode.id)
    local gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!::check_obj(gameModeObj))
      return
    gameModeSelectHandler.onGameModeSelect(gameModeObj)
  }

  function onEventCurrentGameModeIdChanged(params)
  {
    if (checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("CurrentGameModeIdChanged", this)

    startPressToBattleButtonStep()
  }

  /**
   * Returns true and calls onComplete callback if
   * currentTutorial was canceled.
   * @params removeCurrentTutorial Should be 'true'
   * only for final tutorial step callbacks and 'false'
   * for intermediate states.
   */
  function checkCurrentTutorialCanceled(removeCurrentTutorial = true)
  {
    local canceled = ::getTblValue("canceled", currentTutorial, false)
    if (removeCurrentTutorial)
      currentTutorial = null
    if (canceled)
    {
      sendLastStepsNameToBigQuery()
      if (onComplete != null)
        onComplete({ result = "canceled" })
      return true
    }
    return false
  }

  static function getCounter()
  {
    return ::loadLocalByAccount("tutor/slotbar_presets_tutorial_counter", 0)
  }

  function sendLastStepsNameToBigQuery()
  {
    if (isNewUnitTypeToBattleTutorial)
      ::add_big_query_record("new_unit_type_to_battle_tutorial_lastStepsName", currentStepsName)
  }
}
