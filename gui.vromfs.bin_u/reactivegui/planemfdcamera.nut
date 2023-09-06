from "%rGui/globals/ui_library.nut" import *

let { BlkFileName } = require("planeState/planeToolsState.nut")
let DataBlock = require("DataBlock")
let opticAtgmSight = require("opticAtgmSight.nut")
let heliStockCamera = require("planeCockpit/mfdHeliCamera.nut")
let shkval = require("planeCockpit/mfdShkval.nut")
let { IsMfdSightHudVisible, MfdSightPosSize } = require("airState.nut")
let hudUnitType = require("hudUnitType.nut")

let mfdCameraSetting = Computed(function() {
  let res = {
    isShkval = false
    isHelicopter = false
    lineWidthScale = 1.0
    fontScale = 1.0
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isShkval = blk.getBool("mfdCamShkval", false)
    isHelicopter = blk.getBool("mfdCamShkval", false)
    lineWidthScale = blk.getReal("mfdCamLineScale", 1.0)
    fontScale = blk.getReal("mfdCamFontScale", 1.0)
  }
})

let planeMfdCamera = @(width, height) function() {
  let {isShkval, lineWidthScale, fontScale} = mfdCameraSetting.value
  return {
    watch = mfdCameraSetting
    children = [
      (isShkval ? shkval(width, height, lineWidthScale, fontScale) :
      (hudUnitType.isHelicopter() ? heliStockCamera : opticAtgmSight(width, height, 0, 0)))
    ]
  }
}

let planeMfdCameraSwitcher = @() {
  watch = IsMfdSightHudVisible
  pos = [MfdSightPosSize[0], MfdSightPosSize[1]]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IsMfdSightHudVisible.value ? [ planeMfdCamera(MfdSightPosSize[2], MfdSightPosSize[3])] : null
}

return planeMfdCameraSwitcher