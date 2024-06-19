from "%scripts/dagui_library.nut" import *
from "%scripts/dagui_natives.nut" import set_allowed_controls_mask

let { getWeaponryByPresetInfo } = require("%scripts/weaponry/weaponryPresetsParams.nut")
let { getLastWeapon } = require("%scripts/weaponry/weaponryInfo.nut")
let { showConsoleButtons } = require("%scripts/options/consoleMode.nut")
let { handyman } = require("%sqStdLibs/helpers/handyman.nut")
let { get_all_weapons, set_secondary_weapon, get_countermeasures_data, COUNTER_MEASURE_MODE_FLARE_CHAFF,
 COUNTER_MEASURE_MODE_FLARE, COUNTER_MEASURE_MODE_CHAFF, has_secondary_weapons, set_countermeasures_mode} = require("weaponSelector")
let { eventbus_subscribe } = require("eventbus")
let { handlersManager} = require("%scripts/baseGuiHandlerManagerWT.nut")
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { openGenericTooltip, closeGenericTooltip } = require("%scripts/utils/genericTooltip.nut")
let { getMfmHandler } = require("%scripts/wheelmenu/multifuncMenuTools.nut")

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
  presets = null
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

  constructor(unit, nestObj) {
    this.nestObj = nestObj
    this.guiScene = nestObj.getScene()
    this.unit = unit
    this.presets = getWeaponryByPresetInfo(unit)?.presets
    let chosenPresetName = getLastWeapon(unit.name)
    let chosenPresetIdx = this.presets.findindex(@(w) w.name == chosenPresetName) ?? 0
    this.presets[chosenPresetIdx].tiersView.reverse()
    this.selectPreset(this.presets[chosenPresetIdx])
    this.nestObj.show(false)
  }

  function selectPreset(preset) {
    this.chosenPreset = preset
    this.slotIdToTiersId = {}
    foreach (t in this.chosenPreset.tiersView) {
      let tier = t?.weaponry.tiers[t.tierId]
      if (tier != null && tier?.slot != null)
        this.slotIdToTiersId[tier.slot.tostring()] <- t.tierId
    }

    let presetsMarkup = this.getPresetsMarkup(this.chosenPreset)
    let shType = ::g_shortcut_type.getShortcutTypeByShortcutId("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    let shortCut = shType.getFirstInput("ID_OPEN_VISUAL_WEAPON_SELECTOR")
    presetsMarkup.closeBtnLabel <- shortCut.getTextShort()
    presetsMarkup.ltcDoLabel <- "".concat(loc("HUD/FLARES_SHORT"), "/", loc("HUD/CHAFFS_SHORT"))
    let data = handyman.renderCached(this.sceneTplName, presetsMarkup)
    this.guiScene.replaceContentFromText(this.nestObj, data, data.len(), this)

    this.updateButtonsIndexByWeaponName()
  }

  function getPresetsMarkup(preset) {
    let tiersView = preset.tiersView.map(@(t) {
      tierId        = t.tierId
      img           = t?.img ?? ""
      tierTooltipId = !showConsoleButtons.value ? t?.tierTooltipId : null
      isActive      = t?.img || t?.weaponry
    })
    return {tiersView}
  }

  function onToggleSelectorState(_params) {
    if (!this.isValid()) {
      return
    }
    if (this.isInOpenedState)
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

  function open() {
    if (!this.isValid() || this.unit == null
      || !has_secondary_weapons() || getMfmHandler()?.isActive)
      return

    this.nestObj.show(true)
    this.isInOpenedState = true
    let wndControlsAllowMaskWhenActive = CtrlsInGui.CTRL_ALLOW_WHEEL_MENU
                                   | CtrlsInGui.CTRL_ALLOW_VEHICLE_KEYBOARD
                                   | CtrlsInGui.CTRL_ALLOW_MP_STATISTICS

    set_allowed_controls_mask(wndControlsAllowMaskWhenActive)
    broadcastEvent("ChangedShowActionBar")
    this.updatePresetData()
    this.updateCounterMeasures()
  }

  function close() {
    this.hoveredWeaponBtn = null
    this.isInOpenedState = false
    handlersManager.restoreAllowControlMask()
    broadcastEvent("ChangedShowActionBar")
    if (!this.isValid()) {
      return
    }
    this.nestObj.show(false)
  }

  function onCancel(_obj) {
    this.close()
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
      let weaponCell = this.nestObj.findObject($"tier_{i}")
      if (weaponCell != null) {
        weaponCell.isBordered = selectedIds.contains(i) ? "yes" : "no"
        weaponCell.isSelected = selectedIds.contains(i) ? "yes" : "no"
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
    foreach (id in this.counterMeasuresIds) {
      let counermeasureBtn = countermeasuresContainer.findObject($"countermeasure_{id}")
      if (counermeasureBtn == null)
        continue
      counermeasureBtn.isSelected = counermeasureBtn.id == btn_id ? "yes" : "no"
      counermeasureBtn.isBordered = counermeasureBtn.id == btn_id ? "yes" : "no"
    }
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
  if (selectorHandler == null || !selectorHandler.isInOpenedState)
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