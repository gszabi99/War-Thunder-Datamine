from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { getCurrentPreset } = require("controls")
let { startsWith } = require("%sqstd/string.nut")
let ControlsPreset = require("%scripts/controls/controlsPreset.nut")

let isPresetChanged = Watched(false)
local curPreset = null
local previewPreset = null

function getCurControlsPreset() {
  return curPreset
}

function setCurControlsPreset(preset) {
  curPreset = preset
}

function getPreviewControlsPreset() {
  return previewPreset ?? curPreset
}

function setPreviewControlsPreset(preset) {
  previewPreset = preset
}

function clearControlsPresetGuiOptions(preset) {
  let prefix = "USEROPT_"
  let userOptTypes = []
  foreach (oType, _value in preset.params)
    if (startsWith(oType, prefix))
      userOptTypes.append(oType)
  foreach (oType in userOptTypes)
    preset.params.$rawdelete(oType)
}

function getLoadedPresetBlk() {
  let presetBlk = DataBlock()
  getCurrentPreset(presetBlk)
  return presetBlk
}

function restoreCurControlPreset() {
  let preset = ControlsPreset(getLoadedPresetBlk())
  clearControlsPresetGuiOptions(preset)
  setCurControlsPreset(preset)
}
restoreCurControlPreset()

return {
  getCurControlsPreset
  setCurControlsPreset
  getPreviewControlsPreset
  setPreviewControlsPreset
  isPresetChanged
  clearControlsPresetGuiOptions
}
