from "%scripts/sqDagui/framework/gui_handlers.nut" import register_gui_handler
from "%scripts/baseGuiHandlerWT.nut" import BaseGuiHandlerWT
from "%sqStdLibs/helpers/handyman.nut" import handyman
from "%scripts/sqDagui/framework/handlerType.nut" import handlerType
from "%scripts/slotbar/slotbarPresets/slotbarPresetsUtils.nut" import getPresetsSettings, setPresetsSetting
from "dagor.localize" import doesLocTextExist
from "%scripts/dagui_library.nut" import *
from "%scripts/viewUtils/daguiFonts.nut" import getStringWidthPx

let { handlersManager } = require("%scripts/baseGuiHandlerManagerWT.nut")

function getDependedSettings() {
  return getPresetsSettings().reduce(function(res, value) {
    if (value?.depended == true)
      res.append(value.id)
    return res
  }, [])
}

let SlotbarPresetSettings = class (BaseGuiHandlerWT) {
  wndType = handlerType.MODAL
  sceneBlkName = "%gui/slotbar/slotbarPresets/slotbarPresetsSettings.blk"

  initialButton = null
  ownerWeak = null
  settingsListObj = null

  function initScreen() {
    if (this.ownerWeak)
      this.ownerWeak = this.ownerWeak.weakref()
    this.settingsListObj = this.scene.findObject("settingsList")
    this.fillSettings()
    this.updateObjectsPositions()
  }

  function fillSettings() {
    let checkbox = getPresetsSettings().map(function(value) {
      let { id, selected = false } = value
      let tooltipLocKey = $"presets/filter/{id}/tooltip"
      return {
        id
        text = loc($"presets/filter/{id}")
        tooltip = doesLocTextExist(tooltipLocKey) ? loc(tooltipLocKey) : ""
        value = selected
        funcName = "onSettingsSwitch"
        specialParams = "rightToLeft:t='yes'"
      }
    })

    this.updateWndWidth(checkbox.map(@(v) v.text))

    let data = handyman.renderCached("%gui/commonParts/checkbox.tpl", { checkbox })
    this.guiScene.replaceContentFromText(this.settingsListObj, data, data.len(), this)
    this.updateEnabledSettings()
  }

  function updateWndWidth(texts) {
    let textWidth = getStringWidthPx(texts, "fontSmall", this.guiScene)
    let wndWidth = textWidth + to_pixels("1@checkboxSize + 6@blockInterval") 
    this.scene.findObject("wndFrame")["width"] = wndWidth.tostring()
  }

  function updateObjectsPositions() {
    let initialButtonPos = this.initialButton.getPosRC()
    let initialButtonSize = this.initialButton.getSize()

    let btnCloseObj = this.scene.findObject("btnClose")
    btnCloseObj["pos"] = $"{initialButtonPos[0]}, {initialButtonPos[1]}"
    btnCloseObj["size"] = $"{initialButtonSize[0]}, {initialButtonSize[1]}"

    let wndFrameObj = this.scene.findObject("wndFrame")
    let wndFrameObjSize = wndFrameObj.getSize()
    let interval = to_pixels("2@blockInterval")
    wndFrameObj["pos"] = $"{initialButtonPos[0]}, {initialButtonPos[1] - wndFrameObjSize[1] - interval}"
  }

  function getCheckbox(id) {
    return this.settingsListObj.findObject(id)
  }

  function isCheckboxSelected(id) {
    return this.getCheckbox(id).getValue()
  }

  function updateEnabledSettings() {
    let isAutoAbbreviationOn = this.isCheckboxSelected("enable_auto_abbreviation")
    this.getCheckbox("modes_abbreviation").enable(!isAutoAbbreviationOn && this.isCheckboxSelected("show_modes"))
    this.getCheckbox("show_modes").enable(!isAutoAbbreviationOn)
    this.getCheckbox("show_ratings").enable(!isAutoAbbreviationOn)
    this.getCheckbox("show_titles").enable(!isAutoAbbreviationOn)

    if (isAutoAbbreviationOn)
      return

    let dependedSettings = getDependedSettings()
    local countSelected = 0
    local selectedObjId = -1
    for (local i = 0; i < dependedSettings.len(); i++) {
      let settingId = dependedSettings[i]
      this.getCheckbox(settingId).enable(true)
      if (this.isCheckboxSelected(settingId)) {
        countSelected++
        selectedObjId = settingId
      }
    }
    if (countSelected == 1)
      this.getCheckbox(selectedObjId).enable(false)
  }

  function onSettingsSwitch(obj) {
    setPresetsSetting(obj.id, obj.getValue())
    this.updateEnabledSettings()
  }
}
register_gui_handler("SlotbarPresetSettings", SlotbarPresetSettings)

return freeze({
  openSlotbarPresetSettings = @(initialButton, owner)
    handlersManager.loadHandler(SlotbarPresetSettings, {initialButton, ownerWeak = owner })
})