from "%scripts/dagui_library.nut" import *

let DataBlock  = require("DataBlock")
let { getCurrentPreset } = require("controls")
let ControlsPreset = require("%scripts/controls/controlsPreset.nut")

function getLoadedPresetBlk() {
  let presetBlk = DataBlock()
  getCurrentPreset(presetBlk)
  return presetBlk
}

local curPreset = ControlsPreset(getLoadedPresetBlk())
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

return {
  getCurControlsPreset
  setCurControlsPreset
  getPreviewControlsPreset
  setPreviewControlsPreset
}
