import "DataBlock" as DataBlock
from "controls" import getCurrentPreset
from "%sqstd/string.nut" import startsWith
from "%scripts/dagui_library.nut" import *

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
  const prefix = "USEROPT_"
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
