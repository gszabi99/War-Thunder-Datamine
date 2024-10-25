from "%scripts/dagui_library.nut" import *
let { setAllowedControlsMask } = require("controlsMask")
let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_all_weapons, set_secondary_weapon, get_countermeasures_data, COUNTER_MEASURE_MODE_FLARE_CHAFF, get_current_weapon_preset,
 COUNTER_MEASURE_MODE_FLARE, COUNTER_MEASURE_MODE_CHAFF, has_secondary_weapons, set_countermeasures_mode} = require("weaponSelector")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { getMfmHandler } = require("%scripts/wheelmenu/multifuncMenuTools.nut")
let { abs } = require("math")
let { isXInputDevice } = require("controls")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { getAxisStuck, getMaxDeviatedAxisInfo, getAxisData } = require("%scripts/joystickInterface.nut")

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
  }

  function selectUnit(unit) {
    this.unit = unit
    if (unit == null || !unit.hasWeaponSlots) {
      this.close()
      return
    }
    let presetName = get_current_weapon_preset()?.presetName ?? ""
    this.selectPresetByName(presetName)
  }

  function selectPresetByName(presetName) {
    let presets = getWeaponryByPresetInfo(this.unit).presets
    if (presets.len() == 0)
      return
    let chosenPresetIdx = presets.findindex(@(w) w.name == presetName) ?? 0
    presets[chosenPresetIdx].tiersView.reverse()
    this.selectPreset(presets[chosenPresetIdx])
  }

  function selectPreset(preset) {
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
  }

  function getPresetsMarkup(preset) {
    let airWeaponSelector = this
    let tiersView = preset.tiersView.map(@(t) {
      tierId        = t.tierId
      img           = t?.img ?? ""
      tierTooltipId = !showConsoleButtons.value ? t?.tierTooltipId : null
      isActive      = airWeaponSelector.isTierActive(t)
    })
    return {tiersView}
  }

  function isTierActive(tier) {
    return tier?.img || tier?.weaponry
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
    if (hudUnit?.name != this.unit?.name) {
      this.selectUnit(hudUnit)
      return
    }

    let presetName = get_current_weapon_preset()?.presetName ?? ""
    if (this.chosenPreset?.name != presetName)
      this.selectPresetByName(presetName)
  }

  function open() {
    if (!this.isValid() || !has_secondary_weapons()
      || getMfmHandler()?.isActive)
      return
    this.updateUnitAndPreset()
    if (this.unit == null || !this.unit.hasWeaponSlots)
      return

    this.nestObj.show(true)
    let shType = ::g_shortcut_type.getShortcutTypeByShortcutId("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    let shortCut = shType.getFirstInput("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    this.nestObj.findObject("close_btn").setValue(shortCut.getTextShort())
    let joystickUpdateTimer = this.nestObj.findObject("visual_selector_axis_timer")
    joystickUpdateTimer.setUserData(isXInputDevice() ? this : null)
    this.isInOpenedState = true
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
    broadcastEvent("ChangedShowActionBar")
    this.updatePresetData()
    this.updateCounterMeasures()
    updateExtWatched({ isVisualWeaponSelectorVisible = true })
  }

  function close() {
    if (!this.isOpened())
      return
    this.hoveredWeaponBtn = null
    this.isInOpenedState = false
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
  }

  function onDestroy() {
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

    if (tier?.weaponry?.name == null)
      this.selectBtnsById(this.selectedTiers)
    else
      this.hoverWeaponsByName(tier?.weaponry?.name)
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
          weaponName = tier?.weaponry?.name
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

  function updatePresetData() {
    let data = get_all_weapons()
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
      weaponCell.weaponIdx = $"{stat.weaponIdx}"
      weaponCell.hasBullets = stat.count > 0 ? "yes" : "no"
    }

    this.selectBtnsById(this.selectedTiers)
  }

  function onSecondaryWeaponClick(obj) {
    if (obj?.hasBullets == "no")
      return
    let weaponIdx = to_integer_safe(obj.weaponIdx)
    set_secondary_weapon(weaponIdx)
    this.buttonsFloors.weapons.currentIndex = this.getTierIndex(to_integer_safe(obj.tierId))
    if (isXInputDevice())
      this.setFocusBorder(obj)
    this.updatePresetData()
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

  function updateCounterMeasures() {
    let counterMeasuresData = get_countermeasures_data()
    let countermeasuresContainer = this.nestObj.findObject("countermeasures_container")
    foreach (id in this.counterMeasuresIds) {
      let counermeasureBtn = countermeasuresContainer.findObject($"countermeasure_{id}")
      if (counermeasureBtn == null)
        continue
      if (id == COUNTER_MEASURE_MODE_CHAFF) {
        counermeasureBtn.amount = counterMeasuresData.chaffs
        counermeasureBtn.show(counterMeasuresData.chaffs > 0)
      } else if (id == COUNTER_MEASURE_MODE_FLARE) {
        counermeasureBtn.amount = counterMeasuresData.flares
        counermeasureBtn.show(counterMeasuresData.flares > 0)
      } else {
        counermeasureBtn.show(max(counterMeasuresData.flares, counterMeasuresData.chaffs) > 0)
        counermeasureBtn.amount = $"{counterMeasuresData.flares}/{counterMeasuresData.chaffs}"
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
      if (counermeasureBtn.id == btn_id) {
        this.buttonsFloors.counter_measures.currentIndex = i
        if (isXInputDevice() && this.currentBtnsFloor == this.buttonsFloors.counter_measures)
          this.setFocusBorder(counermeasureBtn)
      }
    }
  }

  function onVisualSelectorAxisInputTimer(_obj = null, _dt = null) {
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

}

function openHudAirWeaponSelector() {
  let selectorHandler = getCurrentHandler()
  if (selectorHandler == null)
    return
  selectorHandler.open()
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

eventbus_subscribe("on_multifunc_menu_request", function selector_on_multifunc_menu_request(evt) {
  if (evt.show)
    closeHudAirWeaponSelector()
})

return {
  HudAirWeaponSelector
  openHudAirWeaponSelector
  isVisualHudAirWeaponSelectorOpened
  closeHudAirWeaponSelector
}