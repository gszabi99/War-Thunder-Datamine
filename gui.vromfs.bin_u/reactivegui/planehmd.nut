from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")

let { HmdVisibleAAM } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible } = require("%rGui/radarState.nut")
let { BlkFileName, HmdVisible } = require("planeState/planeToolsState.nut")

let hmdShelZoom = require("planeHmds/hmdShelZoom.nut")
let hmdVtas = require("planeHmds/hmdVtas.nut")
let hmdF16c = require("planeHmds/hmdF16c.nut")

let hmdSetting = Computed(function() {
  let res = {
    isShelZoom = false,
    isVtas = false,
    isF16c = false
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isShelZoom = blk.getBool("hmdShelZoom", false),
    isVtas = blk.getBool("hmdVtas", false),
    isF16c = blk.getBool("hmdF16c", false)
  }
})

let planeHmd = @(width, height) function() {

  let { isShelZoom, isVtas, isF16c } = hmdSetting.value
  return {
    watch = [hmdSetting, HmdVisibleAAM, HmdSensorVisible, HmdVisible]
    children = HmdVisibleAAM.value || HmdSensorVisible.value || HmdVisible.value ? [
      (isShelZoom ? hmdShelZoom(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null),
      (isF16c ? hmdF16c(width, height) : null)
    ] : null
  }
}

let planeHmdSwitcher = @(width, height) {
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = [ planeHmd(width, height) ]
}

return planeHmdSwitcher