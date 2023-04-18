from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")

let { HmdVisible } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible } = require("%rGui/radarState.nut")
let { BlkFileName } = require("planeState/planeToolsState.nut")

let hmdShelZoom = require("planeHmds/hmdShelZoom.nut")
let hmdVtas = require("planeHmds/hmdVtas.nut")

let hmdSetting = Computed(function() {
  let res = {
    isShelZoom = false,
    isVtas = false
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isShelZoom = blk.getBool("hmdShelZoom", false),
    isVtas = blk.getBool("hmdVtas", false)
  }
})

let planeHmd = @(width, height) function() {

  let { isShelZoom, isVtas } = hmdSetting.value
  return {
    watch = [hmdSetting, HmdVisible, HmdSensorVisible]
    children = HmdVisible.value || HmdSensorVisible.value ? [
      (isShelZoom ? hmdShelZoom(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null)
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