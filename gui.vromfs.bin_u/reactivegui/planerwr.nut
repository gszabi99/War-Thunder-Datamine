from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")

let { BlkFileName } = require("planeState/planeToolsState.nut")
let {tws} = require("tws.nut")

let rwrAnApr25 = require("planeRwrs/rwrAnApr25.nut")
let rwrAnAps109 = require("planeRwrs/rwrAnAps109.nut")
let rwrAnAlr45 = require("planeRwrs/rwrAnAlr45.nut")
let rwrAnAlr46 = require("planeRwrs/rwrAnAlr46.nut")
let rwrAnAlr56 = require("planeRwrs/rwrAnAlr56.nut")
let rwrTews = require("planeRwrs/rwrTews.nut")
let rwrAnAlr67 = require("planeRwrs/rwrAnAlr67.nut")
let rwrAnAlr67Mfd = require("planeRwrs/rwrAnAlr67Mfd.nut")
let rwrJApr6Mfd = require("planeRwrs/rwrJApr6Mfd.nut")
let rwrAri23333 = require("planeRwrs/rwrAri23333.nut")
let rwrAri18228 = require("planeRwrs/rwrAri18228.nut")
let rwrAnApr39 = require("planeRwrs/rwrAnApr39.nut")
let rwrAnApr39Mfd = require("planeRwrs/rwrAnApr39Mfd.nut")
let rwrAnApr39Apr42 = require("planeRwrs/rwrAnApr39Apr42.nut")
let rwrServal = require("planeRwrs/rwrServal.nut")

let rwrSetting = Computed(function() {
  let res = {
    rwrIndicator = null
  }
  if (BlkFileName.get() == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.get()}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    rwrIndicator = blk.getStr("rwrIndicator", "")
  }
})

let function rwrDefault(posWatched, sizeWatched, colorWatched, scaleDef, backHide, fontSizeMult) {
  return tws({
    colorWatched = colorWatched,
    posWatched = posWatched,
    sizeWatched = sizeWatched,
    relativCircleSize = 54,
    scale = scaleDef,
    needDrawCentralIcon = !backHide,
    fontSizeMult = fontSizeMult,
    needDrawBackground = !backHide,
    needAdditionalLights = false,
    forMfd = true
    centralCircleSizeMult = 0.7
  })
}

let rwrs = {
  ["AN/APR-25"] = rwrAnApr25,
  ["AN/APS-109"] = rwrAnAps109,
  ["AN/ALR-45"] = rwrAnAlr45,
  ["AN/ALR-46"] = rwrAnAlr46,
  ["AN/ALR-56"] = rwrAnAlr56,
  ["AN/ALR-69"] = rwrAnAlr56,
  ["TEWS"]      = rwrTews,
  ["AN/ALR-67"] = rwrAnAlr67,
  ["AN/ALR-67 MFD"] = rwrAnAlr67Mfd,
  ["J/APR-6 MFD"] = rwrJApr6Mfd,
  ["ARI-23333"] = rwrAri23333,
  ["ARI-18228"] = rwrAri18228,
  ["AN/APR-39"] = rwrAnApr39,
  ["AN/APR-39 MFD"] = rwrAnApr39Mfd,
  ["AN/APR-39/APR-42"] = rwrAnApr39Apr42,
  ["Serval"] = rwrServal
}

let planeRwr = @(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult) function() {
  let { rwrIndicator } = rwrSetting.get()
  return {
    watch = rwrSetting
    children = rwrs?[rwrIndicator] != null ?
      (rwrs[rwrIndicator])(posWatched, sizeWatched, scale, fontSizeMult) :
      rwrDefault(posWatched, sizeWatched, colorWatched, scaleDef, backHide, fontSizeMult)
  }
}

let function planeRwrSwitcher(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult) {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = SIZE_TO_CONTENT
    children = planeRwr(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult)
  }
}

return planeRwrSwitcher