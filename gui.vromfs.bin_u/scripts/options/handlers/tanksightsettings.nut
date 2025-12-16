from "%scripts/dagui_library.nut" import *
let { gui_handlers } = require("%sqDagui/framework/gui_handlers.nut")
let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")
let { tankSightOptionsMap, tankSightOptionsSections, getSightOptionValueIdx, initTankSightOptions,
  updateTankSightCrosshairOpts } = require("%scripts/options/tankSightOptions.nut")
let unitOptions = require("%scripts/options/tankSightUnitOptions.nut")
let { set_tank_sight_setting, set_tank_sight_highlight_obj, load_tank_sight_settings, get_tank_sight_settings,
  save_tank_sight_settings, get_tank_sight_presets, apply_tank_sight_preset, switch_tank_sight_settings_mode,
  TSM_SIMPLE, TSM_LIGHT, TSM_NIGHT_VISION, TSM_THERMAL, TSI_CROSSHAIR, on_exit_from_tank_sight_settings,
  reset_tank_sight_settings, save_user_tank_sight_preset, get_tank_alt_crosshair, delete_user_tank_sight_preset } = require("tankSightSettings")
let { create_option_combobox } = require("%scripts/options/optionsCtors.nut")
let updateExtWatched = require("%scripts/global/updateExtWatched.nut")
let openEditBoxDialog = require("%scripts/wndLib/editBoxHandler.nut")
let { doesLocTextExist } = require("dagor.localize")
let { eventbus_subscribe } = require("eventbus")
let { broadcastEvent } = require("%sqStdLibs/helpers/subscriptions.nut")
let { getUnitName } = require("%scripts/unit/unitInfo.nut")
let { destroyModalInfo } = require("%scripts/modalInfo/modalInfo.nut")

const SELECT_PRESET_COMBOBOX_ID = "select_preset_combobox"

let createSelectControl = @(settingId, options, idx = 0)
  create_option_combobox(settingId, options, idx, "onChangeSightOption", false)

let getOptionsSectionObjId = @(tankSightObjType) $"tso_options_{tankSightObjType}"
let getOptionControlObjId = @(sightOptionType) $"sight_option_{sightOptionType}"
let getTankSightObjType = @(sectionId) sectionId.split("_").top().tointeger()

let modeToBgImageModePostfix = {
  [TSM_SIMPLE] = "day",
  [TSM_NIGHT_VISION] = "nightvision",
  [TSM_LIGHT] = "night",
  [TSM_THERMAL] = "thermal"
}

let customPresetOption = { value = "", text = "#tankSight/customPreset", isPredefinedPreset = true }
let getPresetsOptions = @() [customPresetOption]
  .extend(
    get_tank_sight_presets()
      .reduce(function(presets, isPredefinedPreset, presetName) {
        let text =  isPredefinedPreset && doesLocTextExist($"tankSight/{presetName}")
          ? loc($"tankSight/{presetName}")
          : presetName
        return presets.append({
          text
          isPredefinedPreset
          value = presetName
          sortId = text.tolower()
        })
      }, [])
      .sort(@(p1, p2) p1.isPredefinedPreset <=> p2.isPredefinedPreset
        || p1.sortId <=> p2.sortId)
  )

local class TankSightSettings (gui_handlers.BaseGuiHandlerWT) {
  sceneTplName = "%gui/options/tankSightSettings.tpl"
  widgetsList = [ { widgetId = DargWidgets.TANK_SIGHT_SETTINGS } ]

  isSightPreviewMode = false
  isSettingsApplying = false
  sightMode = persist("tankSightSettingsMode", @() { value = TSM_SIMPLE })
  tankSightPresets = []

  getSceneTplView = @() {
    presetSettings = tankSightOptionsSections.map(@(section, idx) {
      title = section.title
      id = getOptionsSectionObjId(section.id)
      initiallyExpand = idx == 0
      controls = section.options.map(@(opt) {
        markup = createSelectControl(
          getOptionControlObjId(opt), tankSightOptionsMap[opt].options, tankSightOptionsMap[opt].idx)
      })
    })

    unitSettings = unitOptions.types.map(@(t) {
      id = t.id
      markup = t.getControlMarkup()
    })

    presetsComboboxMarkup = this.getPresetsComboboxMarkup()
  }

  resetCurPresetOption = @() !this.isSettingsApplying
    ? this.scene.findObject(SELECT_PRESET_COMBOBOX_ID).setValue(0)
    : null

  getPresetsComboboxMarkup = @(idx = 0) create_option_combobox(SELECT_PRESET_COMBOBOX_ID, this.tankSightPresets, idx, "onChangePreset", false)

  updateIsPreviewExtWatched = @() updateExtWatched({ tankSightIsPreviewMode = this.isSightPreviewMode })

  function initScreen() {
    unitOptions.init(this, this.scene)
    set_tank_sight_highlight_obj(tankSightOptionsSections[0].id)
    this.updateSightMode()
    this.updateCrosshairOptions()
    this.updatePresetsOptions()
    this.applySettingsForSelectedUnit()
    this.updateIsPreviewExtWatched()
  }

  function onDestroy() {
    on_exit_from_tank_sight_settings()
  }

  function onChangeUnitOption(obj) {
    if (!obj?.isValid())
      return
    unitOptions[obj.id].onChange(this, this.scene, obj)
    this.updateCrosshairOptions()
    this.applySettingsForSelectedUnit()
    this.resetCurPresetOption()
  }

  function onChangePreset(obj) {
    let { value, isPredefinedPreset } = this.tankSightPresets[obj.getValue()]
    this.scene.findObject("delete_user_preset_btn").show(!isPredefinedPreset)

    if ( value == "" || this.isSettingsApplying)
      return

    apply_tank_sight_preset(value)
    let curSettings = get_tank_sight_settings()
    this.updateTankSightsOptions(curSettings)
  }

  function onSaveCustomPreset() {
    let presetNames = this.tankSightPresets.map(@(p) p.value)
    openEditBoxDialog({
      title = loc("tankSight/savePreset")
      label = loc("tankSight/enterPresetName")
      editboxWarningTooltip = loc("tankSight/presetAlreadyExists")
      okFunc = function(presetName) {
        save_user_tank_sight_preset(presetName)
        this.updatePresetsOptions(presetName)
      }
      checkWarningFunc = @(presetName) !presetNames.contains(presetName)
      checkButtonFunc = @(presetName) !presetNames.contains(presetName)
      performChecksOnChange = true
      charMask = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890_"
      maxLen = 50
      owner = this
    })
  }

  function updatePresetsOptions(presetToSet = customPresetOption.value) {
    this.tankSightPresets = getPresetsOptions()
    let idx = this.tankSightPresets.findindex(@(p) p.value == presetToSet) ?? 0
    let { isPredefinedPreset } = this.tankSightPresets[idx]
    let markup = this.getPresetsComboboxMarkup(idx)
    this.guiScene.replaceContentFromText(this.scene.findObject(SELECT_PRESET_COMBOBOX_ID), markup, markup.len(), this)
    this.scene.findObject("delete_user_preset_btn").show(!isPredefinedPreset)
  }

  function updateCrosshairOptions() {
    updateTankSightCrosshairOpts()
    let opts = tankSightOptionsMap[TSI_CROSSHAIR]
    let id = getOptionControlObjId(TSI_CROSSHAIR)
    let control = this.scene.findObject(id)
    let markup = createSelectControl(id, opts.options, opts.idx)
    this.guiScene.replaceContentFromText(control, markup, markup.len(), this)
  }

  function applySettingsForSelectedUnit() {
    let settings
      = load_tank_sight_settings(unitOptions.UNIT.value, unitOptions.COUNTRY.value, unitOptions.RANK.value)
    this.updateTankSightsOptions(settings)
  }

  function updateTankSightsOptions(settings) {
    this.isSettingsApplying = true
    this.guiScene.setUpdatesEnabled(false, false)
    foreach (optType, optValue in settings) {
      let controlObj = this.scene.findObject(getOptionControlObjId(optType))
      let valueIdx = getSightOptionValueIdx(optType, optValue)

      if (!controlObj?.isValid())
        continue

      if (valueIdx == null) {
        this.trySetUnknownSightOption(controlObj, optType, optValue)
        continue
      }

      controlObj.setValue(valueIdx)
    }

    this.guiScene.setUpdatesEnabled(true, true)
    this.isSettingsApplying = false
  }

  function trySetUnknownSightOption(controlObj, optType, optValue) {
    let { handleUnknownValue = null } = tankSightOptionsMap[optType]
    if (!handleUnknownValue)
      return
    let { shouldUpdateView = false, newIdx } = handleUnknownValue(optValue)
    if (!shouldUpdateView) {
      controlObj.setValue(newIdx)
      return
    }

    let { options } = tankSightOptionsMap[optType]
    let controlMarkup = createSelectControl(controlObj.id, options, newIdx)
    this.guiScene.replaceContentFromText(controlObj, controlMarkup, controlMarkup.len(), this)
  }

  function onSave() {
    save_tank_sight_settings(unitOptions.UNIT.value, unitOptions.COUNTRY.value, unitOptions.RANK.value)

    if (unitOptions.UNIT.value != "")
      return

    let nonDefaultSightUnits = unitOptions.UNIT.options
      .map(@(opt) opt.value)
      .filter(@(uName) get_tank_alt_crosshair(uName) != "")
      .map(@(uName) getUnitName(uName))

    if (nonDefaultSightUnits.len() > 0)
      scene_msg_box(
        "non_default_sight_notification", null,
        loc("tankSight/nonDefaultSightNotification", { nonDefUnits = ", ".join(nonDefaultSightUnits) }),
        [["ok", @() null ]], "ok"
      )
  }

  function onReset() {
    reset_tank_sight_settings()
    this.resetCurPresetOption()
    this.updateTankSightsOptions(get_tank_sight_settings())
  }

  function onOptionsTitleClick(obj) {
    let parentObj = obj?.getParent()
    if (!parentObj?.isValid())
      return
    let val =  parentObj.expanded == "yes" ? "no" : "yes"
    parentObj.expanded = val
    if (val == "yes") {
      let sightObjType = getTankSightObjType(parentObj.id)
      set_tank_sight_highlight_obj(sightObjType)

      let { scene } = this
      tankSightOptionsSections
        .map(@(section) getOptionsSectionObjId(section.id))
        .filter(@(id) id != parentObj.id)
        .each(@(id) scene.findObject(id).expanded = "no")
    }
  }

  function onChangeSightOption(obj) {
    let param = getTankSightObjType(obj.id)
    let { value = null } = tankSightOptionsMap?[param].options[obj.getValue()]
    if (value == null)
      return
    set_tank_sight_setting({param, value})
    this.resetCurPresetOption()
  }

  function onToggleSightPreviewMode() {
    this.isSightPreviewMode = !this.isSightPreviewMode

    let toggleBtnText = this.isSightPreviewMode ? loc("tankSight/showSettings") : loc("mainmenu/btnPreview")
    let toggleBtnObj = this.scene.findObject("btn_toggle_preview")

    toggleBtnObj.setValue(toggleBtnText)
    this.updateObjectsVisibilities()
    this.updateIsPreviewExtWatched()
  }

  function onToggleNightVisionMode() {
    this.sightMode.value = this.sightMode.value == TSM_NIGHT_VISION
      ? TSM_SIMPLE
      : TSM_NIGHT_VISION
    this.updateSightMode()
  }

  function onToggleLightingMode() {
    this.sightMode.value = this.sightMode.value == TSM_LIGHT
      ? TSM_SIMPLE
      : TSM_LIGHT
    this.updateSightMode()
  }

  function onToggleThermalMode() {
    this.sightMode.value = this.sightMode.value == TSM_THERMAL
      ? TSM_SIMPLE
      : TSM_THERMAL
    this.updateSightMode()
  }

  function onDeleteUserPreset() {
    let curPresetIdx = this.scene.findObject(SELECT_PRESET_COMBOBOX_ID).getValue()
    let curPresetName = this.tankSightPresets[curPresetIdx].value
    let okCb = Callback(function() {
      delete_user_tank_sight_preset(curPresetName)
      this.updatePresetsOptions()
    }, this)
    scene_msg_box(
      "delete_user_sight_preset", null,
      loc("tankSight/confirmUserPresetDeletion", { name = curPresetName }),
      [ ["ok", okCb ], ["cancel" @() null] ],
      "cancel"
    )
  }

  function updateSightMode() {
    let isNv = this.sightMode.value == TSM_NIGHT_VISION
    let isThermal = this.sightMode.value == TSM_THERMAL
    let nvBtnToggleText = isNv
      ? loc("tankSight/dayVisionPreview")
      : loc("hotkeys/ID_TANK_NIGHT_VISION")
    let lightBtnToggleText = this.sightMode.value == TSM_LIGHT
      ? loc("tankSight/dayVisionPreview")
      : loc("hotkeys/ID_TOGGLE_GM_CROSSHAIR_LIGHTING")
    let thermalBtnToggleText = isThermal
      ? loc("tankSight/dayVisionPreview")
      : loc("hotkeys/thermalVersionPreview")

    switch_tank_sight_settings_mode(this.sightMode.value)
    updateExtWatched({ tankSightBgImageModePostfix = modeToBgImageModePostfix[this.sightMode.value] })
    this.scene.findObject("btn_toggle_lighting").setValue(lightBtnToggleText)
    this.scene.findObject("btn_toggle_nv").setValue(nvBtnToggleText)
    this.scene.findObject("btn_toggle_thermal").setValue(thermalBtnToggleText)
  }

  function updateObjectsVisibilities() {
    showObjectsByTable(this.scene, {
      settings_pane = !this.isSightPreviewMode
      select_unit_pane = !this.isSightPreviewMode
    })
  }

  function onEventTankSightObjectClick(tso) {
    set_tank_sight_highlight_obj(tso)

    let { scene } = this
    tankSightOptionsSections
      .filter(@(section) section.id != tso)
      .map(@(section) getOptionsSectionObjId(section.id))
      .each(@(id) scene.findObject(id).expanded = "no")

    let sectionObjToExpand = scene.findObject((getOptionsSectionObjId(tso)))
    if (sectionObjToExpand?.isValid())
      sectionObjToExpand.expanded = "yes"
  }

  onBeforeSelectComboboxValue = @() destroyModalInfo()
}

eventbus_subscribe("TankSightObjectClick", @(tso) broadcastEvent("TankSightObjectClick", tso))

gui_handlers.TankSightSettings <- TankSightSettings

return function() {
  initTankSightOptions()
  handlersManager.loadHandler(TankSightSettings)
}