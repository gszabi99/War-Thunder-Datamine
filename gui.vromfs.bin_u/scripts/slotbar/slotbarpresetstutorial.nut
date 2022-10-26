from "%scripts/dagui_library.nut" import *

//checked for explicitness
#no-root-fallback
#explicit-this

let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")

::SlotbarPresetsTutorial <- class {
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
    this.currentStepsName = "startTutorial"
    this.currentGameModeId = ::game_mode_manager.getCurrentGameModeId()
    if (this.preset == null)
      return false
    let currentPresetIndex = getTblValue(this.currentCountry, ::slotbarPresets.selected, -1)
    this.validPresetIndex = this.getPresetIndex(this.preset)
    if (currentPresetIndex == this.validPresetIndex)
      if (this.isNewUnitTypeToBattleTutorial)
        return this.startOpenGameModeSelectStep()
      else
        return this.startUnitSelectStep()
    this.presetsList = this.currentHandler.getSlotbarPresetsList()
    if (this.presetsList == null)
      return false
    let presetObj = this.presetsList.getListChildByPresetIdx(this.validPresetIndex)
    local steps
    if (presetObj && presetObj.isVisible()) // Preset is in slotbar presets list.
    {
      this.currentStepsName = "selectPreset"
      steps = [{
        obj = [presetObj]
        text = this.createMessageWhithUnitType()
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = Callback(this.onSlotbarPresetSelect, this)
        keepEnv = true
      }]
    }
    else
    {
      let presetsButtonObj = this.presetsList.getPresetsButtonObj()
      if (presetsButtonObj == null)
        return false
      this.currentStepsName = "openSlotbarPresetWnd"
      steps = [{
        obj = [presetsButtonObj]
        text = loc("slotbarPresetsTutorial/openWindow")
        actionType = tutorAction.OBJ_CLICK
        shortcut = ::SHORTCUT.GAMEPAD_X
        cb = Callback(this.onChooseSlotbarPresetWnd_Open, this)
        keepEnv = true
      }]
    }
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)

    // Increment tutorial counter.
    ::saveLocalByAccount("tutor/slotbar_presets_tutorial_counter", this.getCounter() + 1)

    return true
  }

  function onSlotbarPresetSelect()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", this.onEventSlotbarPresetLoaded, this)
    let listObj = this.presetsList.getListObj()
    if (listObj != null)
      listObj.setValue(this.validPresetIndex)
  }

  function onChooseSlotbarPresetWnd_Open()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    this.chooseSlotbarPresetHandler = ::gui_choose_slotbar_preset(this.currentHandler)
    this.chooseSlotbarPresetIndex = ::find_in_array(::slotbarPresets.presets[this.currentCountry], this.preset)
    if (this.chooseSlotbarPresetIndex == -1)
      return
    let itemsListObj = this.chooseSlotbarPresetHandler.scene.findObject("items_list")
    let presetObj = itemsListObj.getChild(this.chooseSlotbarPresetIndex)
    if (!checkObj(presetObj))
      return
    let applyButtonObj = this.chooseSlotbarPresetHandler.scene.findObject("btn_preset_load")
    if (!checkObj(applyButtonObj))
      return
    let steps = [{
      obj = [presetObj]
      text = this.createMessageWhithUnitType()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onChooseSlotbarPresetWnd_Select, this)
      keepEnv = true
    } {
      obj = [applyButtonObj]
      text = loc("slotbarPresetsTutorial/pressApplyButton")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onChooseSlotbarPresetWnd_Apply, this)
      keepEnv = true
    }]
    this.currentStepsName = "applySlotbarPresetWnd"
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)
  }

  function onChooseSlotbarPresetWnd_Select()
  {
    if (this.checkCurrentTutorialCanceled(false))
      return
    let itemsListObj = this.chooseSlotbarPresetHandler.scene.findObject("items_list")
    itemsListObj.setValue(this.chooseSlotbarPresetIndex)
    this.chooseSlotbarPresetHandler.onItemSelect(null)
  }

  function onChooseSlotbarPresetWnd_Apply()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    ::add_event_listener("SlotbarPresetLoaded", this.onEventSlotbarPresetLoaded, this)
    this.chooseSlotbarPresetHandler.onBtnPresetLoad(null)
  }

  function onEventSlotbarPresetLoaded(_params)
  {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("SlotbarPresetLoaded", this)

    // Switching preset causes game mode to switch as well.
    // So we need to restore it to it's previous value.
    ::game_mode_manager.setCurrentGameModeById(this.currentGameModeId)

    // This update shows player that preset was
    // actually changed behind tutorial dim.
    let slotbar = topMenuHandler.value.getSlotbar()
    if (slotbar)
      slotbar.forceUpdate()

    if (!this.startUnitSelectStep() && !this.startOpenGameModeSelectStep())
      this.startPressToBattleButtonStep()
  }

  function onStartPress()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    this.currentHandler.onStart()
    this.currentStepsName = "tutorialEnd"
    this.sendLastStepsNameToBigQuery()
    if (this.onComplete != null)
      this.onComplete({ result = "success" })
  }

  function createMessageWhithUnitType(partLocId = "selectPreset")
  {
    let types = ::game_mode_manager.getRequiredUnitTypes(this.tutorialGameMode)
    let unitType = unitTypes.getByEsUnitType(::u.max(types))
    let unitTypeLocId = "options/chooseUnitsType/" + unitType.lowerName
    return loc("slotbarPresetsTutorial/" + partLocId, { unitType = loc(unitTypeLocId) })
  }

  function createMessage_pressToBattleButton()
  {
    return loc("slotbarPresetsTutorial/pressToBattleButton",
      { gameModeName = this.tutorialGameMode.text })
  }

  function getPresetIndex(prst)
  {
    let presets = getTblValue(this.currentCountry, ::slotbarPresets.presets, null)
    return ::find_in_array(presets, prst, -1)
  }

  /**
   * This subtutorial for selecting allowed unit within selected preset.
   * Returns false if tutorial was skipped for some reason.
   */
  function startUnitSelectStep()
  {
    let slotbarHandler = this.currentHandler.getSlotbar()
    if (!slotbarHandler)
      return false
    if (::game_mode_manager.isUnitAllowedForGameMode(showedUnit.value))
      return false
    let currentPreset = ::slotbarPresets.getCurrentPreset(this.currentCountry)
    if (currentPreset == null)
      return false
    let index = this.getAllowedUnitIndexByPreset(currentPreset)
    let crews = getTblValue("crews", currentPreset, null)
    let crewId = getTblValue(index, crews, -1)
    if (crewId == -1)
      return false
    let crew = ::get_crew_by_id(crewId)
    if (!crew)
      return false

    this.crewIdInCountry = crew.idInCountry
    let steps = [{
      obj = ::get_slot_obj(slotbarHandler.scene, crew.idCountry, crew.idInCountry)
      text = loc("slotbarPresetsTutorial/selectUnit")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onUnitSelect, this)
      keepEnv = true
    }]
    this.currentStepsName = "selectUnit"
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)
    return true
  }

  function onUnitSelect()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    let slotbar = this.currentHandler.getSlotbar()
    slotbar.selectCrew(this.crewIdInCountry)
    if (!this.startOpenGameModeSelectStep())
      this.startPressToBattleButtonStep()
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
    if (this.checkCurrentTutorialCanceled())
      return
    let objs = [
      topMenuHandler.value.scene.findObject("to_battle_button"),
      topMenuHandler.value.getObj("to_battle_console_image")
    ]
    let steps = [{
      obj = [objs]
      text = this.createMessage_pressToBattleButton()
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onStartPress, this)
    }]
    this.currentStepsName = "pressToBattleButton"
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)
  }

  function startOpenGameModeSelectStep()
  {
    if (!this.isNewUnitTypeToBattleTutorial)
      return false
    let currentGameMode = ::game_mode_manager.getCurrentGameMode()
    if (currentGameMode == this.tutorialGameMode)
      return false
    let gameModeChangeButtonObj = this.currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return false
    let steps = [{
      obj = [gameModeChangeButtonObj]
      text = loc("slotbarPresetsTutorial/openGameModeSelect")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onOpenGameModeSelect, this)
      keepEnv = true
    }]
    this.currentStepsName = "openGameModeSelect"
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)
    return true
  }

  function onOpenGameModeSelect()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    let gameModeChangeButtonObj = this.currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return
    ::add_event_listener("GamercardDrawerOpened", this.onEventGamercardDrawerOpened, this)
    this.currentHandler.openGameModeSelect()
  }

  function onEventGamercardDrawerOpened(_params)
  {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("GamercardDrawerOpened", this)

    this.startSelectGameModeStep()
  }

  function startSelectGameModeStep()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    let gameModeSelectHandler = this.currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = ::game_mode_manager.getGameModeItemId(this.tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
      return

    let steps = [{
      obj = [gameModeObj]
      text = this.createMessageWhithUnitType("selectGameMode")
      actionType = tutorAction.OBJ_CLICK
      shortcut = ::SHORTCUT.GAMEPAD_X
      cb = Callback(this.onSelectGameMode, this)
      keepEnv = true
    }]
    this.currentStepsName = "selectGameMode"
    this.currentTutorial = ::gui_modal_tutor(steps, this.currentHandler, true)
  }

  function onSelectGameMode()
  {
    if (this.checkCurrentTutorialCanceled())
      return
    ::add_event_listener("CurrentGameModeIdChanged", this.onEventCurrentGameModeIdChanged, this)
    let gameModeSelectHandler = this.currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = ::game_mode_manager.getGameModeItemId(this.tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
      return
    gameModeSelectHandler.onGameModeSelect(gameModeObj)
  }

  function onEventCurrentGameModeIdChanged(_params)
  {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("CurrentGameModeIdChanged", this)

    this.startPressToBattleButtonStep()
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
    let canceled = getTblValue("canceled", this.currentTutorial, false)
    if (removeCurrentTutorial)
      this.currentTutorial = null
    if (canceled)
    {
      this.sendLastStepsNameToBigQuery()
      if (this.onComplete != null)
        this.onComplete({ result = "canceled" })
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
    if (this.isNewUnitTypeToBattleTutorial)
      ::add_big_query_record("new_unit_type_to_battle_tutorial_lastStepsName", this.currentStepsName)
  }
}
