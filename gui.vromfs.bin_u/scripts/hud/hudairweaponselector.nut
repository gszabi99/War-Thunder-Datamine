from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { setAllowedControlsMask } = require("controlsMask")
let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_all_weapons, can_set_weapon, set_secondary_weapon, get_countermeasures_data, COUNTER_MEASURE_MODE_FLARE_CHAFF, get_current_weapon_preset,
 COUNTER_MEASURE_MODE_FLARE, COUNTER_MEASURE_MODE_CHAFF, has_secondary_weapons, set_countermeasures_mode, set_secondary_weapons_selector = @(_) null
} = require("weaponSelector")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent, subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { getMfmHandler } = require("%scripts/wheelmenu/multifuncMenuTools.nut")
let { abs } = require("math")
let { isXInputDevice } = require("controls")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { getAxisStuck, getMaxDeviatedAxisInfo, getAxisData } = require("%scripts/joystickInterface.nut")
let { getShortcutById } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { deferOnce } = require("dagor.workcycle")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")

const UPDATE_WEAPONS_DELAY = 0.5
const SELECTOR_PIN_STATE_SAVE_ID = "airWeaponSelectorState"

enum SelectorState {
  NONE = 0x0
  PINNED = 0x1
  OPENED = 0x2
  OPENED_AND_PINNED = 0x3
}

local cachedSelectorState = SelectorState.NONE

local isSelectorClosed = true
let counterMeasuresViews = {
  [COUNTER_MEASURE_MODE_FLARE_CHAFF] = { view = {isFlareChaff = true, index = COUNTER_MEASURE_MODE_FLARE_CHAFF,
    label = @() "".concat(loc("HUD/FLARES_SHORT"), "/", loc("HUD/CHAFFS_SHORT"))},
    getAmount = @(data) max(data.flares, data.chaffs),
    getText = @(data) $"{data.flares}/{data.chaffs}"
  },
  [COUNTER_MEASURE_MODE_FLARE] = { view = {icon = "#ui/gameuiskin#bullet_flare", label = @() loc("HUD/FLARES_SHORT"),
    index = COUNTER_MEASURE_MODE_FLARE}, getAmount = @(data) data.flares, getText = @(data) $"{data.flares}"
  },
  [COUNTER_MEASURE_MODE_CHAFF] = { view = {icon = "#ui/gameuiskin#bullet_chaff", label = @() loc("HUD/CHAFFS_SHORT"),
    index = COUNTER_MEASURE_MODE_CHAFF}, getAmount = @(data) data.chaffs, getText = @(data) $"{data.chaffs}"
  }
}

function getCurrentHandler() {
  let airHandler = handlersManager.findHandlerClassInScene(gui_handlers.HudAir)?.airWeaponSelector
    ?? handlersManager.findHandlerClassInScene(gui_handlers.HudHeli)?.airWeaponSelector
  return !airHandler?.isValid() ? null : airHandler
}

function onToggleSelectorState(_params) {
  let airHandler = getCurrentHandler()
  if (airHandler == null)
    return

  if (airHandler.isInOpenedState)
    airHandler.close()
  else
    airHandler.open()
  airHandler.checkAndSaveCachedState()
}

eventbus_subscribe("toggleAirWeaponVisualSelector", onToggleSelectorState)

let class HudAirWeaponSelector {
  sceneTplName = "%gui/hud/hudAirWeaponSelector.tpl"
  unit = null
  guiScene = null
  chosenPreset = null
  buttonsIndexByWeaponName = {}
  nestObj = null
  lastTiersStats = []
  selectedTiers = []
  hoveredWeaponBtn = null
  hoveredCounterMeasureBtn = null
  isInOpenedState = false
  counterMeasuresIds = [COUNTER_MEASURE_MODE_FLARE_CHAFF, COUNTER_MEASURE_MODE_FLARE, COUNTER_MEASURE_MODE_CHAFF]
  slotIdToTiersId = {}
  stuckAxis = null
  watchAxis = [["decal_move_x", "decal_move_y"], ["camx", "camy"]]
  lastFocusBorderObj = null
  currentJoystickDirection = null
  currentBtnsFloor = null
  countermeasuresShortcutId = "ID_FLARES"
  isReinitDelayed = false
  isPinned = false
  cachedCounterMeasuresData = null
  cachedWeaponsData = null
  updateWeaponsDelay = UPDATE_WEAPONS_DELAY

  buttonsFloors = {
    weapons = {
      onFloorSelect = "onWeaponsFloorSelect"
      onJoystick = "selectNextWeaponBtn"
      currentIndex = -1
      onJoystickClick = "onJoystickSelectWeaponBtn"
      nextFloor = "counter_measures"
      prevFloor = "counter_measures"
    }
    counter_measures = {
      onFloorSelect = "onCounterMeasuresFloorSelect"
      onJoystick = "selectNextCounerMeasureBtn"
      currentIndex = -1
      onJoystickClick = "onJoystickSelectCounterMeasureBtn"
      nextFloor = "weapons"
      prevFloor = "weapons"
    }
  }

  constructor(unit, nestObj) {
    this.stuckAxis = getAxisStuck(this.watchAxis)
    this.currentBtnsFloor = this.buttonsFloors.weapons
    this.nestObj = nestObj
    this.guiScene = nestObj.getScene()
    this.nestObj.show(false)
    this.selectUnit(unit)
    if (this.chosenPreset == null)
      return

    cachedSelectorState = loadLocalAccountSettings(SELECTOR_PIN_STATE_SAVE_ID, SelectorState.NONE)
    if (cachedSelectorState & SelectorState.PINNED)
      this.pinToScreen(true)
    subscribe_handler(this, g_listener_priority.DEFAULT_HANDLER)
    if ((cachedSelectorState & SelectorState.OPENED_AND_PINNED) == SelectorState.OPENED_AND_PINNED)
      deferOnce(@() getCurrentHandler()?.open())
  }

  function selectUnit(unit) {
    this.unit = unit
    if (unit == null || !unit.hasWeaponSlots || !has_secondary_weapons()) {
      this.close()
      return
    }
    this.countermeasuresShortcutId = this.unit.isHelicopter()
      ? "ID_FLARES_HELICOPTER"
      : "ID_FLARES"

    let presetName = get_current_weapon_preset()?.presetName ?? ""
    this.selectPresetByName(presetName)
  }

  function selectPresetByName(presetName) {
    let presets = getWeaponryByPresetInfo(this.unit).presets
    if (presets.len() == 0) {
      this.chosenPreset = null
      this.close()
      return
    }
    let chosenPresetIdx = presets.findindex(@(w) w.name == presetName) ?? 0
    presets[chosenPresetIdx].tiersView.reverse()
    this.selectPreset(presets[chosenPresetIdx])
  }

  function selectPreset(preset) {
    this.isReinitDelayed = false
    this.chosenPreset = preset
    this.slotIdToTiersId = {}
    this.lastFocusBorderObj = null
    foreach (t in this.chosenPreset.tiersView) {
      let tier = t?.weaponry.tiers[t.tierId]
      if (tier != null && tier?.slot != null)
        this.slotIdToTiersId[tier.slot.tostring()] <- t.tierId
    }

    let presetsMarkup = this.getPresetsMarkup(this.chosenPreset)
    presetsMarkup.ltcDoLabel <- "".concat(loc("HUD/FLARES_SHORT"), "/", loc("HUD/CHAFFS_SHORT"))
    let data = handyman.renderCached(this.sceneTplName, presetsMarkup)
    this.guiScene.replaceContentFromText(this.nestObj, data, data.len(), this)
    this.updateButtonsIndexByWeaponName()
    this.updatePresetData()
    this.updateCounterMeasures()
  }

  function getPresetsMarkup(preset) {
    let airWeaponSelector = this
    let tiersView = preset.tiersView.map(@(t) {
      tierId        = t.tierId
      img           = t?.img ?? ""
      tierTooltipId = !showConsoleButtons.value ? t?.tierTooltipId : null
      isActive      = airWeaponSelector.isTierActive(t)
      isGun         = (t?.weaponry.isGun ?? false) ? "yes" : "no"
    })

    let counterMeasures = []
    foreach (data in counterMeasuresViews)
      counterMeasures.append(data.view)

    
    let shType = g_shortcut_type.getShortcutTypeByShortcutId(this.countermeasuresShortcutId)
    let scInput = shType.getFirstInput(this.countermeasuresShortcutId)
    let shortcutText = scInput.getTextShort()
    let isXinput = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID

    return {tiersView, counterMeasures, shortcut = shortcutText, isXinput, haveShortcut = shortcutText != "",
      gamepadShortcat = isXinput ? "".concat("{{", shortcutText, "}}") : null, isPinned = this.isPinned ? "yes" : "no"}
  }

  function isTierActive(tier) {
    return tier?.img != null || tier?.weaponry != null
  }

  function onToggleSelectorState(_params) {
    if (!this.isValid()) {
      return
    }
    if (this.isOpened())
      this.close()
    else
      this.open()
  }

  function isOpened() {
    if (!this.isValid())
      return false
    return this.isInOpenedState
  }

  isValid = @() this.nestObj?.isValid() ?? false

  function updateUnitAndPreset() {
    let hudUnit = getPlayerCurUnit()
    if (hudUnit == null || !hudUnit.hasWeaponSlots) {
      this.close()
      return
    }

    if (hudUnit?.name != this.unit?.name) {
      this.selectUnit(hudUnit)
      return
    }

    let presetName = get_current_weapon_preset()?.presetName ?? ""
    if (this.isReinitDelayed || this.chosenPreset?.name != presetName)
      this.selectPresetByName(presetName)
  }

  function open() {
    if (!this.isValid() || !has_secondary_weapons()
      || getMfmHandler()?.isActive)
      return
    this.updateUnitAndPreset()
    if (this.unit == null || !this.unit.hasWeaponSlots || this.chosenPreset == null)
      return

    this.nestObj.show(true)
    let shType = g_shortcut_type.getShortcutTypeByShortcutId("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    let shortCut = shType.getFirstInput("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    this.nestObj.findObject("close_btn").setValue(shortCut.getTextShort())
    let updateTimer = this.nestObj.findObject("visual_selector_timer")
    updateTimer.setUserData(this)
    this.isInOpenedState = true
    isSelectorClosed = false
    set_secondary_weapons_selector(true)

    updateExtWatched({ isVisualWeaponSelectorVisible = true })
    if (!this.isPinned)
      this.setBlockControlMask()
    broadcastEvent("ChangedShowActionBar")
  }

  function close() {
    if (!this.isOpened())
      return
    this.hoveredWeaponBtn = null
    this.isInOpenedState = false
    isSelectorClosed = true
    handlersManager.restoreAllowControlMask()
    broadcastEvent("ChangedShowActionBar")
    if (!this.isValid()) {
      return
    }
    this.nestObj.show(false)
    updateExtWatched({ isVisualWeaponSelectorVisible = false })
  }

  function onCancel(_obj) {
    this.close()
    this.checkAndSaveCachedState()
  }

  function onDestroy() {
    isSelectorClosed = true
    if (this.isOpened()) {
      updateExtWatched({ isVisualWeaponSelectorVisible = false })
      handlersManager.restoreAllowControlMask()
    }
  }

  function onGenericTooltipOpen(obj) {
    openGenericTooltip(obj, this)
  }

  function onTooltipObjClose(obj) {
    closeGenericTooltip(obj, this)
  }

  function onAirWeapSelectorHover(obj) {
    this.hoveredWeaponBtn = obj
    let tierId = to_integer_safe(obj.tierId)
    let tier = this.getTierById(tierId)

    if (tier?.weaponry.name == null)
      this.selectBtnsById(this.selectedTiers)
    else
      this.hoverWeaponsByName(tier?.weaponry.name)
  }

  function onAirWeapSelectorUnhover(obj) {
    if (this.hoveredWeaponBtn == null)
      return
    if (obj?.id != "buttons_container" && this.hoveredWeaponBtn?.id != obj?.id)
      return
    this.hoveredWeaponBtn = null
    this.selectBtnsById(this.selectedTiers)
  }

  function selectBtnsById(selectedIds) {
    let tiers = this.chosenPreset.tiersView
    let tiersCount = tiers.len()

    for (local i = 0; i < tiersCount; i++) {
      let tier = this.chosenPreset.tiersView[i]
      let weaponCell = this.nestObj.findObject($"tier_{tier.tierId}")
      let isSelectedTier = selectedIds.contains(tier.tierId)
      if (weaponCell != null) {
        weaponCell.isBordered = isSelectedTier ? "yes" : "no"
        weaponCell.isSelected = isSelectedTier ? "yes" : "no"
      }
      if (this.buttonsFloors.weapons.currentIndex < 0 && isSelectedTier) {
        this.buttonsFloors.weapons.currentIndex = i
        if (isXInputDevice())
          this.setFocusBorder(weaponCell)
      }
    }

    let statsLen = this.lastTiersStats.len()
    local count = 0
    local maxCount = 0
    local weaponName = null
    for (local i = 0; i < statsLen; i++) {
      let tierId = this.lastTiersStats[i].tierId
      if (selectedIds.contains(tierId)) {
        count += this.lastTiersStats[i].count
        maxCount += this.lastTiersStats[i].maxCount
        if (weaponName == null) {
          let tier = this.getTierById(tierId)
          weaponName = tier?.weaponry.name
        }
      }
    }
    if (weaponName != null) {
      let weaponLocName = $"weapons/{weaponName}"
      this.setLabel($"{loc(weaponLocName)} x{count}/{maxCount}")
      return
    }
    this.setLabel(" ")
  }

  function updatePresetData(data = null) {
    data = data ?? get_all_weapons()
    this.cachedWeaponsData = data
    let blockLength = 4
    let weaponsCount = data.weapons.len()/blockLength

    this.lastTiersStats = []
    for (local i = 0; i < weaponsCount; i++) {
      this.lastTiersStats.append({
        tierId = this.slotIdToTiersId?[$"{data.weapons[i * blockLength]}"] ?? -1
        count = data.weapons[i * blockLength + 1]
        maxCount = data.weapons[i * blockLength + 2]
        weaponIdx = data.weapons[i * blockLength + 3]
      })
    }

    let slotIdToTiersId = this.slotIdToTiersId
    this.selectedTiers = data.selected.map(@(t) slotIdToTiersId?[$"{t}"] ?? -1)

    for (local i = 0; i < weaponsCount; i++) {
      let stat = this.lastTiersStats[i]
      let weaponCell = this.nestObj.findObject($"tier_{stat.tierId}")
      if (weaponCell == null)
        continue
      if (weaponCell.weaponIdx != "-1" && !can_set_weapon(stat.weaponIdx))
        continue
      weaponCell.weaponIdx = $"{stat.weaponIdx}"
      weaponCell.hasBullets = stat.count > 0 ? "yes" : "no"
      if ((weaponCell?.isGun ?? "no") == "no")
        weaponCell.findObject("label").setValue(stat.count > 0 ? $"{stat.count}" : "")
    }

    this.selectBtnsById(this.selectedTiers)
  }

  function onSecondaryWeaponClick(obj) {
    if ((!is_cursor_visible_in_gui() && !isXInputDevice()) || obj?.hasBullets == "no" || obj?.isGun == "yes")
      return
    let weaponIdx = to_integer_safe(obj.weaponIdx)
    set_secondary_weapon(weaponIdx)
    this.buttonsFloors.weapons.currentIndex = this.getTierIndex(to_integer_safe(obj.tierId))
    if (isXInputDevice())
      this.setFocusBorder(obj)
    this.updatePresetData()
    if (this.isPinned)
      return
    this.close()
  }

  function hoverWeaponsByName(weaponName) {
    let tiers = this.chosenPreset.tiersView
    let tiersCount = tiers.len()
    if (weaponName == null) {
      for (local i = 0; i < tiersCount; i++) {
        let tier = tiers[i]
        let obj = this.nestObj.findObject($"tier_{tier.tierId}")
        if (obj != null) {
          obj.isBordered = "no"
        }
      }
      this.setLabel(" ")
      return
    }

    if (this.buttonsIndexByWeaponName?[weaponName] == null)
      return
    let buttonsIndexes = this.buttonsIndexByWeaponName[weaponName]

    for (local i = 0; i < tiersCount; i++) {
      let tier = tiers[i]
      let isTierSelected = buttonsIndexes.contains(tier.tierId)
      let obj = this.nestObj.findObject($"tier_{tier.tierId}")
      obj.isBordered = isTierSelected ? "yes" : "no"
    }

    let statsLen = this.lastTiersStats.len()
    local count = 0
    local maxCount = 0
    for (local i = 0; i < statsLen; i++) {
      if (buttonsIndexes.contains(this.lastTiersStats[i].tierId)) {
        count += this.lastTiersStats[i].count
        maxCount += this.lastTiersStats[i].maxCount
      }
    }
    let weaponLocName = $"weapons/{weaponName}"
    this.setLabel($"{loc(weaponLocName)} x{count}/{maxCount}")
  }

  function updateButtonsIndexByWeaponName() {
    let tiers = this.chosenPreset.tiersView
    foreach (tier in tiers) {
      if (tier?.weaponry == null)
        continue

      if (this.buttonsIndexByWeaponName?[tier.weaponry.name] == null)
        this.buttonsIndexByWeaponName[tier.weaponry.name] <- [tier.tierId]
      else
        this.buttonsIndexByWeaponName[tier.weaponry.name].append(tier.tierId)
    }
  }

  function getTierById(tierId) {
    let tiers = this.chosenPreset.tiersView
    foreach (tier in tiers)
      if (tier.tierId == tierId)
        return tier
    return null
  }

  function getTierIndex(tierId) {
    let tiersCount = this.chosenPreset.tiersView.len()
    for (local i = 0; i < tiersCount; i++)
      if (this.chosenPreset.tiersView[i]?.tierId == tierId)
        return i
    return 0
  }

  function getCounterMeasureModeIndex(mode) {
    let modesCount = this.counterMeasuresIds.len()
    for (local i = 0; i < modesCount; i++) {
      if (this.counterMeasuresIds == mode)
        return i
    }
    return 0
  }

  function setLabel(text) {
    this.nestObj.findObject("weapon_tooltip").setValue(text)
  }

  function updateCounterMeasures(forceUpdateLabels = false) {
    let counterMeasuresData = get_countermeasures_data()
    this.cachedCounterMeasuresData = counterMeasuresData
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    foreach (id in this.counterMeasuresIds) {
      let counermeasureBtn = countermeasuresContainer.findObject($"countermeasure_{id}")
      if (counermeasureBtn == null)
        continue

      let amount = counterMeasuresViews?[id].getAmount(counterMeasuresData) ?? 0
      counermeasureBtn.show(amount > 0)
      if (amount > 0) {
        let amountText = counterMeasuresViews?[id].getText(counterMeasuresData)
        counermeasureBtn.amount = amountText
        if (forceUpdateLabels || this.isPinned) {
          let labelObj = counermeasureBtn.findObject("label")
          labelObj.setValue(this.isPinned ? amountText : labelObj.nameText)
        }
      }
    }

    this.selectCounterMeasureBtn($"countermeasure_{counterMeasuresData.mode}")
  }

  function onCounterMeasureHover(obj) {
    this.hoveredCounterMeasureBtn = obj
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    foreach (id in this.counterMeasuresIds) {
      let counermeasureBtn = countermeasuresContainer.findObject($"countermeasure_{id}")
      if (counermeasureBtn == null)
        continue
      counermeasureBtn.isBordered = counermeasureBtn.id == obj.id ? "yes" : "no"
      if (counermeasureBtn.id == obj.id) {
        let label = counermeasureBtn.findObject("label")
        this.setLabel($"{label.text} x{counermeasureBtn?.amount ?? 0}")
      }
    }
  }

  function onCounterMeasureUnhover(obj) {
    if (obj != null && this.hoveredCounterMeasureBtn?.id != obj?.id)
      return
    let counterMeasuresContainer = this.nestObj.findObject("countermeasures_container")
    foreach (id in this.counterMeasuresIds) {
      let counermeasureBtn = counterMeasuresContainer.findObject($"countermeasure_{id}")
      if (counermeasureBtn == null)
        continue
      counermeasureBtn.isBordered = counermeasureBtn.isSelected
    }
    this.hoveredCounterMeasureBtn = null
    this.selectBtnsById(this.selectedTiers)
  }

  function onCounterMeasureClick(obj) {
    if (!is_cursor_visible_in_gui())
      return
    this.selectCounterMeasureBtn(obj.id)
    set_countermeasures_mode(to_integer_safe(obj.counterMeasureMode))
  }

  function selectCounterMeasureBtn(btn_id) {
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    let modesCount = this.counterMeasuresIds.len()
    for (local i = 0; i < modesCount; i++) {
      let mode = this.counterMeasuresIds[i]
      let counermeasureBtn = countermeasuresContainer.findObject($"countermeasure_{mode}")
      if (counermeasureBtn == null)
        continue
      counermeasureBtn.isSelected = counermeasureBtn.id == btn_id ? "yes" : "no"
      counermeasureBtn.isBordered = counermeasureBtn.id == btn_id ? "yes" : "no"
      counermeasureBtn.findObject("shortcutContainer")?.show(counermeasureBtn.id == btn_id)
      if (counermeasureBtn.id == btn_id) {
        this.buttonsFloors.counter_measures.currentIndex = i
        if (isXInputDevice() && this.currentBtnsFloor == this.buttonsFloors.counter_measures)
          this.setFocusBorder(counermeasureBtn)
      }
    }
  }

  function onVisualSelectorAxisInputTimer() {
    if (!isXInputDevice())
      return
    let axisData = getAxisData(this.watchAxis, this.stuckAxis)
    let joystickData = getMaxDeviatedAxisInfo(axisData, 0.25)
    if (joystickData == null || joystickData.normLength == 0) {
      this.currentJoystickDirection = null
      return
    }

    let direction = abs(joystickData.x * 1000) > abs(joystickData.y * 1000)
      ? joystickData.x > 0 ? "right" : "left"
      : joystickData.y > 0 ? "up" : "down"

    if (this.currentJoystickDirection == direction)
      return
    this.currentJoystickDirection = direction
    if (direction == "up" || direction == "down") {
      this.switchJoystickButtonsFloor(direction)
      return
    }

    this[this.currentBtnsFloor.onJoystick](direction)
  }

  function switchJoystickButtonsFloor(direction) {
    this.currentBtnsFloor = direction == "up"
      ? this.buttonsFloors[this.currentBtnsFloor.nextFloor]
      : this.buttonsFloors[this.currentBtnsFloor.prevFloor]

    this[this.currentBtnsFloor.onFloorSelect]()
  }

  function onCounterMeasuresFloorSelect() {
    let floor = this.buttonsFloors.counter_measures
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    let mode = this.counterMeasuresIds?[floor.currentIndex]
    if (mode == null)
      return
    let btn = countermeasuresContainer.findObject($"countermeasure_{mode}")
    if (btn != null && btn.isVisible()) {
      this.setFocusBorder(btn)
      this.onCounterMeasureHover(btn)
    }
  }

  function onWeaponsFloorSelect() {
    let floor = this.buttonsFloors.weapons
    let tier = this.chosenPreset.tiersView?[floor.currentIndex]
    if (tier == null)
      return
    let btn = this.nestObj.findObject($"tier_{tier.tierId}")
    if (btn != null)
      this.setFocusBorder(btn)
  }

  function onJoystickApplySelection() {
    this[this.currentBtnsFloor.onJoystickClick]()
  }

  function onJoystickSelectWeaponBtn() {
    let floor = this.buttonsFloors.weapons
    let tier = this.chosenPreset.tiersView?[floor.currentIndex]
    if (tier == null)
      return
    let selectedBtn = this.nestObj.findObject($"tier_{tier.tierId}")
    this.onSecondaryWeaponClick(selectedBtn)
  }

  function onJoystickSelectCounterMeasureBtn() {
    let floor = this.buttonsFloors.counter_measures
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    let mode = this.counterMeasuresIds?[floor.currentIndex]
    if (mode == null)
      return
    let btn = countermeasuresContainer.findObject($"countermeasure_{mode}")
    this.onCounterMeasureClick(btn)
  }

  function selectNextWeaponBtn(side) {
    local btn = null
    let floor = this.buttonsFloors.weapons
    let tier = this.chosenPreset.tiersView?[floor.currentIndex]
    local newTierIndex = floor.currentIndex
    let tiersCount = this.chosenPreset.tiersView.len()

    while (true) {
      newTierIndex = newTierIndex + (side == "left" ? -1 : 1)
      if (newTierIndex < 0)
        newTierIndex = tiersCount-1
      if (newTierIndex >= tiersCount)
        newTierIndex = 0
      if (newTierIndex == floor.currentIndex)
        return
      let nextTier = this.chosenPreset.tiersView[newTierIndex]
      if (!this.isTierActive(nextTier) || tier?.weaponry.name == nextTier?.weaponry.name)
        continue

      btn = this.nestObj.findObject($"tier_{nextTier.tierId}")
      if (btn.hasBullets != "yes") {
        btn = null
        continue
      }

      floor.currentIndex = newTierIndex
      this.setFocusBorder(btn)
      this.hoverWeaponsByName(nextTier?.weaponry.name)
      return
    }
  }

  function selectNextCounerMeasureBtn(side) {
    local btn = null
    let floor = this.buttonsFloors.counter_measures
    local nextIndex = floor.currentIndex
    let modesCount = this.counterMeasuresIds.len()
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")

    while (true) {
      nextIndex = nextIndex + (side == "left" ? -1 : 1)
      if (nextIndex < 0)
        nextIndex = modesCount-1
      if (nextIndex >= modesCount)
        nextIndex = 0
      if (nextIndex == floor.currentIndex)
        return
      let nextMode = this.counterMeasuresIds[nextIndex]
      btn = countermeasuresContainer.findObject($"countermeasure_{nextMode}")
      if (btn != null && btn.isVisible()) {
        floor.currentIndex = nextIndex
        this.setFocusBorder(btn)
        this.onCounterMeasureHover(btn)
        return
      }
    }
  }

  function setFocusBorder(obj) {
    if (this.lastFocusBorderObj != null)
      this.lastFocusBorderObj["needFocusBorder"] = "no"
    this.lastFocusBorderObj = obj
    if (this.lastFocusBorderObj == null)
      return
    this.lastFocusBorderObj["needFocusBorder"] = "yes"
  }

  function pinToScreen(needPeen) {
    if (this.isPinned == needPeen)
      return
    this.isPinned = needPeen
    let pinBtn = this.nestObj.findObject("pin_btn")
    pinBtn.tooltip = loc(this.isPinned ? "tooltip/unpinWeaponSelector" : "tooltip/pinWeaponSelector")
    this.nestObj.findObject("air_weapon_selector").isPinned = this.isPinned ? "yes" : "no"
    if (!this.isOpened)
      return

    if (this.isPinned)
      handlersManager.restoreAllowControlMask()
    else
      this.setBlockControlMask()
  }

  function setBlockControlMask() {
    let wndControlsAllowMaskWhenActive = isXInputDevice()
      ? CtrlsInGui.CTRL_IN_MULTIFUNC_MENU
       | CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
       | CtrlsInGui.CTRL_ALLOW_VEHICLE_MOUSE
       | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
       | CtrlsInGui.CTRL_ALLOW_VEHICLE_JOY
       | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
      : CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
       | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
       | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS
    setAllowedControlsMask(wndControlsAllowMaskWhenActive)
  }

  function onPinBtn(_btn) {
    this.pinToScreen(!this.isPinned)
    this.checkAndSaveCachedState()
  }

  function onVisualSelectorTimer(_obj, dt) {
    this.onVisualSelectorAxisInputTimer()

    this.updateWeaponsDelay -= dt
    if (this.updateWeaponsDelay > 0)
      return
    this.updateWeaponsDelay = UPDATE_WEAPONS_DELAY
    this.updateDataByTimer()
  }

  function isWeaponsDataChanged(old, current) {
    let newCount = current.weapons.len()
    if (old?.weapons.len() != newCount)
      return true
    foreach (idx, val in old.weapons)
      if (current.weapons[idx] != val)
        return true
    return false
  }

  function isCounterMeasuresDataChanged(old, current) {
    return old?.flares != current.flares
      || old?.chaffs != current.chaffs
      || old?.mode != current.mode
  }

  function updateDataByTimer() {
    let data = get_all_weapons()
    if (this.isWeaponsDataChanged(this.cachedWeaponsData, data))
      this.updatePresetData(data)

    let counterMeasures = get_countermeasures_data()
    if (this.isCounterMeasuresDataChanged(this.cachedCounterMeasuresData, counterMeasures))
      this.updateCounterMeasures()
  }

  function checkAndSaveCachedState() {
    let newState = (isSelectorClosed ? SelectorState.NONE : SelectorState.OPENED) |
      (this.isPinned ? SelectorState.PINNED : SelectorState.NONE)

    if (newState == cachedSelectorState)
      return

    cachedSelectorState = newState
    saveLocalAccountSettings(SELECTOR_PIN_STATE_SAVE_ID, cachedSelectorState)
  }

  function onEventControlsChangedShortcuts(data) {
    let changedSchs = data?.changedShortcuts
    if (!this.chosenPreset || changedSchs == null)
      return
    let shc = getShortcutById(this.countermeasuresShortcutId)
    if (shc == null)
      return
    foreach (chandedSch in changedSchs)
      if (shc.shortcutId == chandedSch) {
        this.isReinitDelayed = true
        return
      }
  }

  function onEventControlsPresetChanged(_v) {
    this.isReinitDelayed = true
  }

  function reinitScreen() {
    if (!this.isPinned) {
      this.close()
      return
    }

    if (this.isOpened()) {
      this.updateUnitAndPreset()
      return
    }

    if ((cachedSelectorState & SelectorState.OPENED_AND_PINNED) == SelectorState.OPENED_AND_PINNED)
     this.open()
  }

}

function openHudAirWeaponSelector(byUserAction = false) {
  let selectorHandler = getCurrentHandler()
  if (selectorHandler == null || selectorHandler.isOpened())
    return
  selectorHandler.open()
  if (byUserAction)
    selectorHandler.checkAndSaveCachedState()
}

function closeHudAirWeaponSelector() {
  let selectorHandler = getCurrentHandler()
  if (selectorHandler == null)
    return
  selectorHandler.close()
}

function isVisualHudAirWeaponSelectorOpened() {
  let selectorHandler = getCurrentHandler()
  if (selectorHandler == null)
    return false
  return selectorHandler.isOpened()
}

function onCloseMultifuncMenu() {
  if ((cachedSelectorState & SelectorState.OPENED_AND_PINNED) == SelectorState.OPENED_AND_PINNED)
    deferOnce(@() openHudAirWeaponSelector())
}

eventbus_subscribe("on_multifunc_menu_request", function selector_on_multifunc_menu_request(evt) {
  if (evt.show)
    closeHudAirWeaponSelector()
  else
    onCloseMultifuncMenu()
})

eventbus_subscribe("onMultifuncMenuClosed", @(_) onCloseMultifuncMenu())

function updateSelectorData() {
  let airHandler = getCurrentHandler()
  if (airHandler == null)
    return

  if (airHandler.isOpened())
    airHandler.updatePresetData()
}

function updateCounterMeasuresData() {
  let airHandler = getCurrentHandler()
  if (airHandler == null)
    return

  if (airHandler.isOpened())
    airHandler.updateCounterMeasures()
}

eventbus_subscribe("onLaunchShell", function (_evt) {
  if (isSelectorClosed)
    return
  deferOnce(updateSelectorData)
})

eventbus_subscribe("onSwitchSecondaryWeaponCycle", function (_evt) {
  if (isSelectorClosed)
    return
  deferOnce(updateSelectorData)
})

eventbus_subscribe("onLaunchCountermeasure", function (_evt) {
  if (isSelectorClosed)
    return
  deferOnce(updateCounterMeasuresData)
})

return {
  HudAirWeaponSelector
  openHudAirWeaponSelector
  isVisualHudAirWeaponSelectorOpened
}