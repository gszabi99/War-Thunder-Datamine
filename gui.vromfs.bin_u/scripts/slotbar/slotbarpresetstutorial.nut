from "%scripts/dagui_library.nut" import *
//-file:undefined-const
//-file:undefined-variable
//checked for explicitness
#no-root-fallback
#implicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

::SlotbarPresetsTutorial <- class
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
    let currentPresetIndex = getTblValue(currentCountry, ::slotbarPresets.selected, -1)
    validPresetIndex = getPresetIndex(preset)
    if (currentPresetIndex == validPresetIndex)
      if (isNewUnitTypeToBattleTutorial)
        return startOpenGameModeSelectStep()
      else
        return startUnitSelectStep()
    presetsList = currentHandler.getSlotbarPresetsList()
    if (presetsList == null)
      return false
    let presetObj = presetsList.getListChildByPresetIdx(validPresetIndex)
    local steps
    if (presetObj && presetObj.isVisible()) // Preset is in slotbar presets list.
    {
      currentStepsName = "selectPreset"
      steps = [{
        obj = [presetObj]
        text = createMessageWhithUnitType()
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = Callback(onSlotbarPresetSelect, this)
        keepEnv = true
      }]
    }
    else
    {
      let presetsButtonObj = presetsList.getPresetsButtonObj()
      if (presetsButtonObj == null)
        return false
      currentStepsName = "openSlotbarPresetWnd"
      steps = [{
        obj = [presetsButtonObj]
        text = loc("slotbarPresetsTutorial/openWindow")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = Callback(onChooseSlotbarPresetWnd_Open, this)
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
    let listObj = presetsList.getListObj()
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
    let itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
    let presetObj = itemsListObj.getChild(chooseSlotbarPresetIndex)
    if (!checkObj(presetObj))
      return
    let applyButtonObj = chooseSlotbarPresetHandler.scene.findObject("btn_preset_load")
    if (!checkObj(applyButtonObj))
      return
    let steps = [{
      obj = [presetObj]
      text = createMessageWhithUnitType()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onChooseSlotbarPresetWnd_Select, this)
      keepEnv = true
    } {
      obj = [applyButtonObj]
      text = loc("slotbarPresetsTutorial/pressApplyButton")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onChooseSlotbarPresetWnd_Apply, this)
      keepEnv = true
    }]
    currentStepsName = "applySlotbarPresetWnd"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
  }

  function onChooseSlotbarPresetWnd_Select()
  {
    if (checkCurrentTutorialCanceled(false))
      return
    let itemsListObj = chooseSlotbarPresetHandler.scene.findObject("items_list")
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
    let slotbar = topMenuHandler.value.getSlotbar()
    if (slotbar)
      slotbar.forceUpdate()

    if (!startUnitSelectStep() && !startOpenGameModeSelectStep())
      startPressToBattleButtonStep()
  }

  function onStartPress()
  {
    if (checkCurrentTutorialCanceled())
      return
    currentHandler.onStart()
    currentStepsName = "tutorialEnd"
    sendLastStepsNameToBigQuery()
    if (onComplete != null)
      onComplete({ result = "success" })
  }

  function createMessageWhithUnitType(partLocId = "selectPreset")
  {
    let types = ::game_mode_manager.getRequiredUnitTypes(tutorialGameMode)
    let unitType = unitTypes.getByEsUnitType(::u.max(types))
    let unitTypeLocId = "options/chooseUnitsType/" + unitType.lowerName
    return loc("slotbarPresetsTutorial/" + partLocId, { unitType = loc(unitTypeLocId) })
  }

  function createMessage_pressToBattleButton()
  {
    return loc("slotbarPresetsTutorial/pressToBattleButton",
      { gameModeName = tutorialGameMode.text })
  }

  function getPresetIndex(prst)
  {
    let presets = getTblValue(currentCountry, ::slotbarPresets.presets, null)
    return ::find_in_array(presets, prst, -1)
  }

  /**
   * This subtutorial for selecting allowed unit within selected preset.
   * Returns false if tutorial was skipped for some reason.
   */
  function startUnitSelectStep()
  {
    let slotbarHandler = currentHandler.getSlotbar()
    if (!slotbarHandler)
      return false
    if (::game_mode_manager.isUnitAllowedForGameMode(showedUnit.value))
      return false
    let currentPreset = ::slotbarPresets.getCurrentPreset(currentCountry)
    if (currentPreset == null)
      return false
    let index = getAllowedUnitIndexByPreset(currentPreset)
    let crews = getTblValue("crews", currentPreset, null)
    let crewId = getTblValue(index, crews, -1)
    if (crewId == -1)
      return false
    let crew = ::get_crew_by_id(crewId)
    if (!crew)
      return false

    crewIdInCountry = crew.idInCountry
    let steps = [{
      obj = ::get_slot_obj(slotbarHandler.scene, crew.idCountry, crew.idInCountry)
      text = loc("slotbarPresetsTutorial/selectUnit")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onUnitSelect, this)
      keepEnv = true
    }]
    currentStepsName = "selectUnit"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
    return true
  }

  function onUnitSelect()
  {
    if (checkCurrentTutorialCanceled())
      return
    let slotbar = currentHandler.getSlotbar()
    slotbar.selectCrew(crewIdInCountry)
    if (!startOpenGameModeSelectStep())
      startPressToBattleButtonStep()
  }

  /**
   * Returns -1 if no such unit found.
   */
  function getAllowedUnitIndexByPreset(prst)
  {
    let units = prst?.units
    if (units == null)
      return -1
    for (local i = 0; i < units.len(); ++i)
    {
      let unit = ::getAircraftByName(units[i])
      if (::game_mode_manager.isUnitAllowedForGameMode(unit))
        return i
    }
    return -1
  }

  function startPressToBattleButtonStep()
  {
    if (checkCurrentTutorialCanceled())
      return
    let objs = [
      topMenuHandler.value.scene.findObject("to_battle_button"),
      topMenuHandler.value.getObj("to_battle_console_image")
    ]
    let steps = [{
      obj = [objs]
      text = createMessage_pressToBattleButton()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onStartPress, this)
    }]
    currentStepsName = "pressToBattleButton"
    currentTutorial = ::gui_modal_tutor(steps, currentHandler, true)
  }

  function startOpenGameModeSelectStep()
  {
    if (!isNewUnitTypeToBattleTutorial)
      return false
    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == tutorialGameMode)
      return false
    let gameModeChangeButtonObj = currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return false
    let steps = [{
      obj = [gameModeChangeButtonObj]
      text = loc("slotbarPresetsTutorial/openGameModeSelect")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onOpenGameModeSelect, this)
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
    let gameModeChangeButtonObj = currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return
    ::add_event_listener("GamercardDrawerOpened", onEventGamercardDrawerOpened, this)
    currentHandler.openGameModeSelect()
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
    let gameModeSelectHandler = currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = ::game_mode_manager.getGameModeItemId(tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
      return

    let steps = [{
      obj = [gameModeObj]
      text = createMessageWhithUnitType("selectGameMode")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(onSelectGameMode, this)
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
    let gameModeSelectHandler = currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = ::game_mode_manager.getGameModeItemId(tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
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
    let canceled = getTblValue("canceled", currentTutorial, false)
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
