from "%rGui/globals/ui_library.nut" import *

let { BlkFileName } = require("planeState/planeToolsState.nut")
let DataBlock = require("DataBlock")
let opticAtgmSight = require("opticAtgmSight.nut")
let heliStockCamera = require("planeCockpit/mfdHeliCamera.nut")
let shkval = require("planeCockpit/mfdShkval.nut")
let shkvalKa52 = require("planeCockpit/mfdShkvalKa52.nut")
let tads = require("planeCockpit/mfdTads.nut")
let platan = require("planeCockpit/mfdPlatan.nut")
let { IsMfdSightHudVisible, MfdSightPosSize } = require("airState.nut")
let hudUnitType = require("hudUnitType.nut")

let mfdCameraSetting = Computed(function() {
  let res = {
    isShkval = false
    isShkvalKa52 = false
    isTads = false
    isTadsApache = false
    isPlatan = false
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
    isShkvalKa52 = blk.getBool("mfdCamShkvalKa52", false)
    isTads = blk.getBool("mfdCamTads", false)
    isTadsApache = blk.getBool("mfdCamTadsApache", false)
    isPlatan = blk.getBool("mfdCamPlatan", false)

    lineWidthScale = blk.getReal("mfdCamLineScale", 1.0)
    fontScale = blk.getReal("mfdCamFontScale", 1.0)
  }
})

let planeMfdCamera = @(width, height) function() {
  let {isShkval, isShkvalKa52, isTads, isTadsApache, lineWidthScale, fontScale, isPlatan} = mfdCameraSetting.value
  return {
    watch = mfdCameraSetting
    children = [
      (isShkval ? shkval(width, height, lineWidthScale, fontScale) :
      (isShkvalKa52 ? shkvalKa52(width, height) :
      (isTads ? tads(width, height, false) :
      (isTadsApache ? tads(width, height, true) :
      (isPlatan ? platan(width, height) :
      (hudUnitType.isHelicopter() ? heliStockCamera : opticAtgmSight(width, height, 0, 0)))))))
    ]
  }
}

let planeMfdCameraSwitcher = @() {
  watch = [IsMfdSightHudVisible, MfdSightPosSize]
  pos = [MfdSightPosSize.value[0], MfdSightPosSize.value[1]]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IsMfdSightHudVisible.value ? [ planeMfdCamera(MfdSightPosSize.value[2], MfdSightPosSize.value[3])] : null
}

return planeMfdCameraSwitcher