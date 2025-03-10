from "%scripts/dagui_library.nut" import *
from "%scripts/controls/rawShortcuts.nut" import SHORTCUT

let u = require("%sqStdLibs/helpers/u.nut")
let { loadLocalByAccount, saveLocalByAccount
} = require("%scripts/clientState/localProfileDeprecated.nut")
let subscriptions = require("%sqStdLibs/helpers/subscriptions.nut")
let { topMenuHandler } = require("%scripts/mainmenu/topMenuStates.nut")
let tutorAction = require("%scripts/tutorials/tutorialActions.nut")
let unitTypes = require("%scripts/unit/unitTypesList.nut")
let { showedUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let { sendBqEvent } = require("%scripts/bqQueue/bqQueue.nut")
let { getSlotObj } = require("%scripts/slotbar/slotbarView.nut")
let { getCrewById } = require("%scripts/slotbar/slotbarState.nut")
let { getCurrentGameModeId, setCurrentGameModeById, getCurrentGameMode,
  getRequiredUnitTypes, getGameModeItemId, isUnitAllowedForGameMode
} = require("%scripts/gameModes/gameModeManagerState.nut")
let { gui_modal_tutor } = require("%scripts/guiTutorial.nut")
let { gui_choose_slotbar_preset } = require("%scripts/slotbar/slotbarPresetsWnd.nut")

let SlotbarPresetsTutorial = class {
  
  static MAX_TUTORIALS = 3

  



  static MAX_PLAYS_FOR_GAME_MODE = 5

  



  static MIN_PLAYS_GAME_FOR_NEW_UNIT_TYPE = 5

  
  currentCountry = null
  currentHandler = null
  onComplete = null
  preset = null 

  currentGameModeId = null
  tutorialGameMode = null

  isNewUnitTypeToBattleTutorial = null

  
  presetsList = null
  validPresetIndex = -1

  
  chooseSlotbarPresetHandler = null
  chooseSlotbarPresetIndex = -1

  
  crewIdInCountry = -1 

  currentTutorial = null

  currentStepsName = null
  


  function startTutorial() {
    this.currentStepsName = "startTutorial"
    this.currentGameModeId = getCurrentGameModeId()
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
    if (presetObj && presetObj.isVisible()) { 
      this.currentStepsName = "selectPreset"
      steps = [{
        obj = [presetObj]
        text = this.createMessageWhithUnitType()
        actionType = tutorAction.OBJ_CLICK
        shortcut = SHORTCUT.GAMEPAD_X
        cb = Callback(this.onSlotbarPresetSelect, this)
        keepEnv = true
      }]
    }
    else {
      let presetsButtonObj = this.presetsList.getPresetsButtonObj()
      if (presetsButtonObj == null)
        return false
      this.currentStepsName = "openSlotbarPresetWnd"
      steps = [{
        obj = [presetsButtonObj]
        text = loc("slotbarPresetsTutorial/openWindow")
        actionType = tutorAction.OBJ_CLICK
        shortcut = SHORTCUT.GAMEPAD_X
        cb = Callback(this.onChooseSlotbarPresetWnd_Open, this)
        keepEnv = true
      }]
    }
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)

    
    saveLocalByAccount("tutor/slotbar_presets_tutorial_counter", this.getCounter() + 1)

    return true
  }

  function onSlotbarPresetSelect() {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.add_event_listener("SlotbarPresetLoaded", this.onEventSlotbarPresetLoaded, this)
    let listObj = this.presetsList.getListObj()
    if (listObj != null)
      listObj.setValue(this.validPresetIndex)
  }

  function onChooseSlotbarPresetWnd_Open() {
    if (this.checkCurrentTutorialCanceled())
      return
    this.chooseSlotbarPresetHandler = gui_choose_slotbar_preset(this.currentHandler)
    this.chooseSlotbarPresetIndex = u.find_in_array(::slotbarPresets.presets[this.currentCountry], this.preset)
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
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onChooseSlotbarPresetWnd_Select, this)
      keepEnv = true
    } {
      obj = [applyButtonObj]
      text = loc("slotbarPresetsTutorial/pressApplyButton")
      actionType = tutorAction.OBJ_CLICK
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onChooseSlotbarPresetWnd_Apply, this)
      keepEnv = true
    }]
    this.currentStepsName = "applySlotbarPresetWnd"
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)
  }

  function onChooseSlotbarPresetWnd_Select() {
    if (this.checkCurrentTutorialCanceled(false))
      return
    let itemsListObj = this.chooseSlotbarPresetHandler.scene.findObject("items_list")
    itemsListObj.setValue(this.chooseSlotbarPresetIndex)
    this.chooseSlotbarPresetHandler.onItemSelect(null)
  }

  function onChooseSlotbarPresetWnd_Apply() {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.add_event_listener("SlotbarPresetLoaded", this.onEventSlotbarPresetLoaded, this)
    this.chooseSlotbarPresetHandler.onBtnPresetLoad(null)
  }

  function onEventSlotbarPresetLoaded(_params) {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("SlotbarPresetLoaded", this)

    
    
    setCurrentGameModeById(this.currentGameModeId)

    
    
    let slotbar = topMenuHandler.value.getSlotbar()
    if (slotbar)
      slotbar.forceUpdate()

    if (!this.startUnitSelectStep() && !this.startOpenGameModeSelectStep())
      this.startPressToBattleButtonStep()
  }

  function onStartPress() {
    if (this.checkCurrentTutorialCanceled())
      return
    this.currentHandler.onStart()
    this.currentStepsName = "tutorialEnd"
    this.sendLastStepsNameToBigQuery()
    if (this.onComplete != null)
      this.onComplete({ result = "success" })
  }

  function createMessageWhithUnitType(partLocId = "selectPreset") {
    let types = getRequiredUnitTypes(this.tutorialGameMode)
    let unitType = unitTypes.getByEsUnitType(u.max(types))
    let unitTypeLocId =$"options/chooseUnitsType/{unitType.lowerName}"
    return loc($"slotbarPresetsTutorial/{partLocId}", { unitType = loc(unitTypeLocId) })
  }

  function createMessage_pressToBattleButton() {
    return loc("slotbarPresetsTutorial/pressToBattleButton",
      { gameModeName = this.tutorialGameMode.text })
  }

  function getPresetIndex(prst) {
    let presets = getTblValue(this.currentCountry, ::slotbarPresets.presets, null)
    return u.find_in_array(presets, prst, -1)
  }

  



  function startUnitSelectStep() {
    let slotbarHandler = this.currentHandler.getSlotbar()
    if (!slotbarHandler)
      return false
    if (isUnitAllowedForGameMode(showedUnit.value))
      return false
    let currentPreset = ::slotbarPresets.getCurrentPreset(this.currentCountry)
    if (currentPreset == null)
      return false
    let index = this.getAllowedUnitIndexByPreset(currentPreset)
    let crews = getTblValue("crews", currentPreset, null)
    let crewId = getTblValue(index, crews, -1)
    if (crewId == -1)
      return false
    let crew = getCrewById(crewId)
    if (!crew)
      return false

    this.crewIdInCountry = crew.idInCountry
    let steps = [{
      obj = getSlotObj(slotbarHandler.scene, crew.idCountry, crew.idInCountry)
      text = loc("slotbarPresetsTutorial/selectUnit")
      actionType = tutorAction.OBJ_CLICK
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onUnitSelect, this)
      keepEnv = true
    }]
    this.currentStepsName = "selectUnit"
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)
    return true
  }

  function onUnitSelect() {
    if (this.checkCurrentTutorialCanceled())
      return
    let slotbar = this.currentHandler.getSlotbar()
    slotbar.selectCrew(this.crewIdInCountry)
    if (!this.startOpenGameModeSelectStep())
      this.startPressToBattleButtonStep()
  }

  


  function getAllowedUnitIndexByPreset(prst) {
    let units = prst?.units
    if (units == null)
      return -1
    for (local i = 0; i < units.len(); ++i) {
      let unit = getAircraftByName(units[i])
      if (isUnitAllowedForGameMode(unit))
        return i
    }
    return -1
  }

  function startPressToBattleButtonStep() {
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
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onStartPress, this)
    }]
    this.currentStepsName = "pressToBattleButton"
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)
  }

  function startOpenGameModeSelectStep() {
    if (!this.isNewUnitTypeToBattleTutorial)
      return false
    let currentGameMode = getCurrentGameMode()
    if (currentGameMode == this.tutorialGameMode)
      return false
    let gameModeChangeButtonObj = this.currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return false
    let steps = [{
      obj = [gameModeChangeButtonObj]
      text = loc("slotbarPresetsTutorial/openGameModeSelect")
      actionType = tutorAction.OBJ_CLICK
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onOpenGameModeSelect, this)
      keepEnv = true
    }]
    this.currentStepsName = "openGameModeSelect"
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)
    return true
  }

  function onOpenGameModeSelect() {
    if (this.checkCurrentTutorialCanceled())
      return
    let gameModeChangeButtonObj = this.currentHandler?.gameModeChangeButtonObj
    if (!checkObj(gameModeChangeButtonObj))
      return
    subscriptions.add_event_listener("GamercardDrawerOpened", this.onEventGamercardDrawerOpened, this)
    this.currentHandler.openGameModeSelect()
  }

  function onEventGamercardDrawerOpened(_params) {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("GamercardDrawerOpened", this)

    this.startSelectGameModeStep()
  }

  function startSelectGameModeStep() {
    if (this.checkCurrentTutorialCanceled())
      return
    let gameModeSelectHandler = this.currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = getGameModeItemId(this.tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
      return

    let steps = [{
      obj = [gameModeObj]
      text = this.createMessageWhithUnitType("selectGameMode")
      actionType = tutorAction.OBJ_CLICK
      shortcut = SHORTCUT.GAMEPAD_X
      cb = Callback(this.onSelectGameMode, this)
      keepEnv = true
    }]
    this.currentStepsName = "selectGameMode"
    this.currentTutorial = gui_modal_tutor(steps, this.currentHandler, true)
  }

  function onSelectGameMode() {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.add_event_listener("CurrentGameModeIdChanged", this.onEventCurrentGameModeIdChanged, this)
    let gameModeSelectHandler = this.currentHandler?.gameModeSelectHandler
    if (!gameModeSelectHandler)
      return
    let gameModeItemId = getGameModeItemId(this.tutorialGameMode.id)
    let gameModeObj = gameModeSelectHandler.scene.findObject(gameModeItemId)
    if (!checkObj(gameModeObj))
      return
    gameModeSelectHandler.onGameModeSelect(gameModeObj)
  }

  function onEventCurrentGameModeIdChanged(_params) {
    if (this.checkCurrentTutorialCanceled())
      return
    subscriptions.removeEventListenersByEnv("CurrentGameModeIdChanged", this)

    this.startPressToBattleButtonStep()
  }

  






  function checkCurrentTutorialCanceled(removeCurrentTutorial = true) {
    let canceled = getTblValue("canceled", this.currentTutorial, false)
    if (removeCurrentTutorial)
      this.currentTutorial = null
    if (canceled) {
      this.sendLastStepsNameToBigQuery()
      if (this.onComplete != null)
        this.onComplete({ result = "canceled" })
      return true
    }
    return false
  }

  static function getCounter() {
    return loadLocalByAccount("tutor/slotbar_presets_tutorial_counter", 0)
  }

  function sendLastStepsNameToBigQuery() {
    if (this.isNewUnitTypeToBattleTutorial)
      sendBqEvent("CLIENT_GAMEPLAY_1", "new_unit_type_to_battle_tutorial_lastStepsName", { currentStepsName = this.currentStepsName })
  }
}

return SlotbarPresetsTutorial