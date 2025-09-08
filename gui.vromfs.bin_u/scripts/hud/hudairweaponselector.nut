from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import is_cursor_visible_in_gui

let { g_shortcut_type } = require("%scripts/controls/shortcutType.nut")
let { setAllowedControlsMask } = require("controlsMask")
let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_all_weapons, can_set_weapon, set_secondary_weapon, get_countermeasures_data, COUNTER_MEASURE_MODE_FLARE_CHAFF, get_current_weapon_preset,
 COUNTER_MEASURE_MODE_FLARE, COUNTER_MEASURE_MODE_CHAFF, has_secondary_weapons, set_countermeasures_mode, set_secondary_weapons_selector,
 get_periodic_countermeasure_enabled
} = require("weaponSelector")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent, subscribe_handler } = require("%sqStdLibs/helpers/subscriptions.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { getMfmHandler } = require("%scripts/wheelmenu/multifuncMenuTools.nut")
let { isXInputDevice, emulateShortcut } = require("controls")
let { getPlayerCurUnit } = require("%scripts/slotbar/playerCurUnit.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let { getShortcutById } = require("%scripts/controls/shortcutsList/shortcutsList.nut")
let g_listener_priority = require("%scripts/g_listener_priority.nut")
let { deferOnce } = require("dagor.workcycle")
let { saveLocalAccountSettings, loadLocalAccountSettings } = require("%scripts/clientState/localProfile.nut")
let { isShortcutMapped } = require("%scripts/controls/shortcutsUtils.nut")
let { getShortcuts } = require("%scripts/controls/controlsCompatibility.nut")
let { bhvHintForceUpdateValuePID } = require("%scripts/viewUtils/bhvHint.nut")

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
  countermeasuresShortcutId = "ID_FLARES"
  isReinitDelayed = false
  isPinned = false
  cachedCounterMeasuresData = null
  cachedWeaponsData = null
  updateWeaponsDelay = UPDATE_WEAPONS_DELAY
  isPeriodicFlaresEnabled = false
  weaponSlotToTiersId = null
  nextWeaponsTiers = null
  gunsInPresetCount = 0


  constructor(unit, nestObj) {
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
    if (unit == null || !has_secondary_weapons()) {
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
    this.weaponSlotToTiersId = []

    foreach (idx, t in this.chosenPreset.tiersView) {
      let tier = t?.weaponry.tiers[t.tierId]
      if (t?.weaponry != null)
        this.weaponSlotToTiersId.append(-1)
      if (this.unit.hasWeaponSlots) {
        if (tier != null && tier?.slot != null)
          this.slotIdToTiersId[tier.slot] <- t.tierId
        continue
      }
      this.slotIdToTiersId[idx] <- t.tierId
    }

    let weaponsCount = this.weaponSlotToTiersId.len()
    if (!this.unit.hasWeaponSlots && weaponsCount > 0) {
      let hasMiddleWeapon = weaponsCount % 2
      local isLeft = false
      local findedWeapons = -1
      this.gunsInPresetCount = 0
      let middleCellIdx = (this.chosenPreset.tiersView.len()/2).tointeger()
      foreach (t in this.chosenPreset.tiersView) {
        if (t?.weaponry == null)
          continue
        findedWeapons++
        if (t?.weaponry.isGun)
          this.gunsInPresetCount++
        if (hasMiddleWeapon && this.weaponSlotToTiersId[findedWeapons] == -1) {
          this.weaponSlotToTiersId[findedWeapons] = t.tierId
          continue
        }
        let weaponIndex = isLeft
          ? middleCellIdx + ((findedWeapons - hasMiddleWeapon)/2).tointeger() + 1
          : middleCellIdx - ((findedWeapons - hasMiddleWeapon)/2).tointeger() - 1
        isLeft = !isLeft
        this.weaponSlotToTiersId[findedWeapons] = this.slotIdToTiersId[weaponIndex]
      }
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
      tierTooltipId = !showConsoleButtons.get() ? t?.tierTooltipId : null
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
      gamepadShortcat = isXinput ? "".concat("{{", shortcutText, "}}") : null, isPinned = this.isSelectorPinned() ? "yes" : "no"}
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
    this.updatePinView()
    this.updateUnitAndPreset()
    if (this.unit == null || this.chosenPreset == null
      || (!this.unit.hasWeaponSlots && ((this.weaponSlotToTiersId.len() - this.gunsInPresetCount) <= 0)))
      return

    this.nestObj.show(true)
    let updateTimer = this.nestObj.findObject("visual_selector_timer")
    updateTimer.setUserData(this)
    this.isInOpenedState = true
    isSelectorClosed = false
    set_secondary_weapons_selector(true)

    updateExtWatched({ isVisualWeaponSelectorVisible = true })
    if (!this.isSelectorPinned())
      this.setBlockControlMask()
    this.updatePeriodicFlaresBtn()
    this.updatePresetData()
    broadcastEvent("ChangedShowActionBar")
    this.updateButtons()
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

  function onCancel(_obj = null) {
    this.close()
    this.checkAndSaveCachedState()
  }

  function onDummyCloseBtn(_obj) {
    if (isXInputDevice() && this.isSortcutMapped("ID_OPEN_VISUAL_WEAPON_SELECTOR"))
      return
    this.onCancel()
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
    }

    local count = 0
    local maxCount = 0
    local weaponName = null
    foreach (stat in this.lastTiersStats) {
      let tierId = stat.tierId
      if (selectedIds.contains(tierId)) {
        count += stat.count
        maxCount += stat.maxCount
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

  function getTierByIndex(index) {
    return this.weaponSlotToTiersId?[index] ?? -1
  }

  function updateTierStatsNoSlots(data) {
    let {weapons = [], blocksCount = 0, selected = []} = data
    let slotsCount = this.weaponSlotToTiersId.len() - this.gunsInPresetCount
    if (blocksCount <= 0 || weapons.len() == 0 || slotsCount == 0)
      return
    let blockSize = weapons.len() / blocksCount
    this.lastTiersStats = {}
    local presetWeaponFinded = false
    local skippedWeapons = -this.gunsInPresetCount
    for (local i = 0; i < blocksCount; i++) {
      let weaponIdx = weapons[i * blockSize + 3]
      if (weaponIdx < 0) {
        if (!presetWeaponFinded)
          skippedWeapons++
        continue
      }
      presetWeaponFinded = true
      let weaponSlot = (weaponIdx - skippedWeapons) % slotsCount
      let tierId = this.getTierByIndex(weaponSlot)
      if (this.lastTiersStats?[weaponSlot] == null) {
        this.lastTiersStats[weaponSlot] <- {
          tierId
          count = 0
          maxCount = 0
          weaponIdx
        }
      }
      let tierStats = this.lastTiersStats[weaponSlot]
      tierStats.count = tierStats.count + weapons[i * blockSize + 1]
      tierStats.maxCount = tierStats.maxCount + weapons[i * blockSize + 2]
    }
    let handle = this
    this.selectedTiers =
      selected.map(@(t) handle.getTierByIndex((t - skippedWeapons) % slotsCount) ?? -1)
  }

  function updateTierStats(data) {
    this.lastTiersStats = []
    let {weapons = [], blocksCount = 0, selected = [], nextWeapon = -1, isNextWeaponSeparate = true} = data
    if (blocksCount <= 0 || weapons.len() == 0)
      return

    let blockSize = weapons.len() / blocksCount
    for (local i = 0; i < blocksCount; i++) {
      this.lastTiersStats.append({
        tierId = this.slotIdToTiersId?[weapons[i * blockSize]] ?? -1
        count = weapons[i * blockSize + 1]
        maxCount = weapons[i * blockSize + 2]
        weaponIdx = weapons[i * blockSize + 3]
      })
    }
    let slotIdToTiersId = this.slotIdToTiersId
    this.selectedTiers = selected.map(@(t) slotIdToTiersId?[t] ?? -1)
    local nextWeaponTier = this.slotIdToTiersId?[nextWeapon] ?? -1
    this.nextWeaponsTiers = [nextWeaponTier]
    if (!isNextWeaponSeparate) {
      let tiers = this.chosenPreset.tiersView
      let tiersCount = tiers.len()
      this.nextWeaponsTiers.append(tiersCount - nextWeaponTier - 1)
    }
  }

  function updatePresetData(data = null) {
    data = data ?? get_all_weapons()
    this.nextWeaponsTiers = []
    this.cachedWeaponsData = data
    if (this.unit.hasWeaponSlots)
      this.updateTierStats(data)
    else
      this.updateTierStatsNoSlots(data)

    foreach (stat in this.lastTiersStats) {
      let weaponCell = this.nestObj.findObject($"tier_{stat.tierId}")
      if (weaponCell == null)
        continue
      if (weaponCell.weaponIdx != "-1" && !can_set_weapon(stat.weaponIdx))
        continue
      weaponCell.weaponIdx = $"{stat.weaponIdx}"
      weaponCell.isNextWeapon = this.nextWeaponsTiers.indexof(stat.tierId) != null  ? "yes" : "no"
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

    this.updatePresetData()
    if (this.isSelectorPinned())
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

    local count = 0
    local maxCount = 0
    foreach (stat in this.lastTiersStats)
      if (buttonsIndexes.contains(stat.tierId)) {
        count += stat.count
        maxCount += stat.maxCount
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
        if (forceUpdateLabels || this.isSelectorPinned()) {
          let labelObj = counermeasureBtn.findObject("label")
          labelObj.setValue(this.isSelectorPinned() ? amountText : labelObj.nameText)
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
    }
  }


  function onJoystickApplySelection() {
    if (this.hoveredWeaponBtn != null) {
      this.onSecondaryWeaponClick(this.hoveredWeaponBtn)
      return
    }
    if (this.hoveredCounterMeasureBtn != null) {
      this.onCounterMeasureClick(this.hoveredCounterMeasureBtn)
      return
    }
  }


  function pinToScreen(needPeen) {
    if (this.isPinned == needPeen)
      return
    this.isPinned = needPeen
    this.updatePinView()
  }

  function updatePinView() {
    let needPeen = this.isSelectorPinned()
    let isPinned = this.nestObj.findObject("air_weapon_selector").isPinned == "yes"
    if (needPeen == isPinned)
      return
    let pinBtn = this.nestObj.findObject("pin_btn")
    pinBtn.tooltip = loc(needPeen ? "tooltip/unpinWeaponSelector" : "tooltip/pinWeaponSelector")
    this.nestObj.findObject("air_weapon_selector").isPinned = needPeen ? "yes" : "no"
    if (!this.isOpened)
      return

    if (needPeen)
      handlersManager.restoreAllowControlMask()
    else
      this.setBlockControlMask()
  }

  function isSelectorPinned() {
    return this.isPinned || isXInputDevice()
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

  function onPeriodicFlaresBtn(btn) {
    emulateShortcut(this.unit.isHelicopter() ? "ID_TOGGLE_PERIODIC_FLARES_HELICOPTER" : "ID_TOGGLE_PERIODIC_FLARES")
    this.updatePeriodicFlaresBtn(btn)
  }

  function updatePeriodicFlaresBtn(btn = null) {
    let isEnabled = get_periodic_countermeasure_enabled()
    if (this.isPeriodicFlaresEnabled == isEnabled)
      return
    this.isPeriodicFlaresEnabled = isEnabled
    btn = btn ?? this.nestObj.findObject("periodic_flares_btn")
    btn.isSelected = this.isPeriodicFlaresEnabled
      ? "yes"
      : "no"
  }

  function onVisualSelectorTimer(_obj, dt) {
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
    foreach (idx, val in old.selected)
      if (current.selected[idx] != val)
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

    this.updatePeriodicFlaresBtn()
  }

  function updateButtons() {
    let isMapped = this.isSortcutMapped("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    let isMappedForGamepad = isMapped && this.isSortcutMappedForGamepad("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    let isXInput = isXInputDevice()
    let isSwitchWeaponGamepadShortcutMapped = isXInput && this.isSortcutMappedForGamepad("ID_SWITCH_SHOOTING_CYCLE_SECONDARY")

    showObjectsByTable(this.nestObj, {
      close_btn_gamepad = isXInput && isMappedForGamepad
      close_btn_gamepad_icon = isXInput && isMappedForGamepad
      close_btn_gamepad_b = isXInput && !isMapped
      close_btn = !isXInput || (isMapped && !isMappedForGamepad)
      gamepad_switch_weapon_btn = isSwitchWeaponGamepadShortcutMapped
    })

    if (isXInput && isMappedForGamepad) {
      let closeBtn = this.nestObj.findObject("close_btn_gamepad")
      closeBtn.setIntProp(bhvHintForceUpdateValuePID, 1)
      closeBtn.setValue("{{ID_OPEN_VISUAL_WEAPON_SELECTOR}}")
    }

    if (isSwitchWeaponGamepadShortcutMapped) {
      let switchWeaponBtn = this.nestObj.findObject("gamepad_switch_weapon_btn")
      switchWeaponBtn.setIntProp(bhvHintForceUpdateValuePID, 1)
      switchWeaponBtn.setValue("{{ID_SWITCH_SHOOTING_CYCLE_SECONDARY}}")
    }

    if (!isXInput || (isMapped && !isMappedForGamepad)) {
      let shType = g_shortcut_type.getShortcutTypeByShortcutId("ID_OPEN_VISUAL_WEAPON_SELECTOR")
      let shortCut = shType.getFirstInput("ID_OPEN_VISUAL_WEAPON_SELECTOR")
      this.nestObj.findObject("close_btn").setValue(shortCut.getTextShort())
    }
  }

  function isSortcutMappedForGamepad(shortcutId) {
    let shType = g_shortcut_type.getShortcutTypeByShortcutId(shortcutId)
    let scInput = shType.getFirstInput(shortcutId)
    let isMappedForGamepad = scInput.hasImage() && scInput.getDeviceId() != STD_KEYBOARD_DEVICE_ID
    return isMappedForGamepad
  }

  function isSortcutMapped(shortcutId) {
    let shortcut = getShortcuts([shortcutId])
    return isShortcutMapped(shortcut[0])
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
    if (!this?.nestObj.isValid())
      return

    if (!this.isSelectorPinned()) {
      this.close()
      return
    }

    if (this.isOpened()) {
      this.updatePeriodicFlaresBtn()
      this.updateUnitAndPreset()
      this.updateButtons()
      this.updatePinView()
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