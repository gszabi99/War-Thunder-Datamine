from "%rGui/globals/ui_library.nut" import *

let u = require("%sqStdLibs/helpers/u.nut")

let DataBlock = require("DataBlock")

let { BlkFileName } = require("planeState/planeToolsState.nut")
let {tws} = require("tws.nut")

let rwrAnApr25 = require("planeRwrs/rwrAnApr25.nut")
let rwrAnAps109 = require("planeRwrs/rwrAnAps109.nut")
let rwrAnAlr45 = require("planeRwrs/rwrAnAlr45.nut")
let rwrAnAlr46 = require("planeRwrs/rwrAnAlr46.nut")
let rwrAnAlr56 = require("planeRwrs/rwrAnAlr56.nut")
let rwrTews = require("planeRwrs/rwrTews.nut")
let rwrTewsMfd = require("planeRwrs/rwrTewsMfd.nut")
let rwrAnAlr67 = require("planeRwrs/rwrAnAlr67.nut")
let rwrAnAlr67Mfd = require("planeRwrs/rwrAnAlr67Mfd.nut")
let rwrAri23333 = require("planeRwrs/rwrAri23333.nut")
let rwrAri18228 = require("planeRwrs/rwrAri18228.nut")
let rwrAri18241 = require("planeRwrs/rwrAri18241.nut")
let rwrAnApr39 = require("planeRwrs/rwrAnApr39.nut")
let rwrAnApr39Mfd = require("planeRwrs/rwrAnApr39Mfd.nut")
let rwrAnApr39Apr42 = require("planeRwrs/rwrAnApr39Apr42.nut")
let rwrServal = require("planeRwrs/rwrServal.nut")
let rwrSpectra = require("planeRwrs/rwrSpectra.nut")
let rwrAr830 = require("planeRwrs/rwrAr830.nut")
let rwrAr830Extra = require("planeRwrs/rwrAr830Extra.nut")
let rwrL150 = require("planeRwrs/rwrL150.nut")
let rwrL150Su30 = require("planeRwrs/rwrL150Su30.nut")
let rwrDass = require("planeRwrs/rwrDass.nut")

function loadStyleBlock(styleBlock, blk, defStyleBlock) {
  styleBlock.scale = blk.getReal("scale", defStyleBlock.scale)
  styleBlock.lineWidthScale = blk.getReal("lineWidthScale", defStyleBlock.lineWidthScale)
  styleBlock.fontScale = blk.getReal("fontScale", defStyleBlock.fontScale)
}

function loadStyle(style, blk, defStyle) {
  let gridBlk = blk.getBlockByName("grid")
  if (gridBlk != null)
    loadStyleBlock(style.grid, gridBlk, defStyle.grid)
  let objectBlk = blk.getBlockByName("object")
  if (objectBlk != null)
    loadStyleBlock(style.object, objectBlk, defStyle.object)
}

let rwrSetting = Computed(function() {
  let res = {
    indicator = null
  }
  if (BlkFileName.get() == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.get()}.blk"
  if (!blk.tryLoad(fileName))
    return res

  local styleDef = {
    grid = {
      scale = 1.0
      lineWidthScale = 1.0
      fontScale = 1.0
    }
    object = {
      scale = 1.0
      lineWidthScale = 1.0
      fontScale = 1.0
    }
  }
  local style = u.copy(styleDef)
  let cockpitBlk = blk.getBlockByName("cockpit")
  if (cockpitBlk != null) {
    let mfdBlk = cockpitBlk.getBlockByName("multifunctionDisplays")
    if (mfdBlk != null)
      for (local i = 0; i < mfdBlk.blockCount(); ++i) {
        let displayBlk = mfdBlk.getBlock(i)
        local displayStyle = u.copy(styleDef)
        loadStyle(displayStyle, displayBlk, styleDef)
        for (local j = 0; j < displayBlk.blockCount(); ++j) {
          let pageBlk = displayBlk.getBlock(j)
          let typeStr = pageBlk.getStr("type", "")
          if (typeStr == "rwr") {
            loadStyle(style, pageBlk, displayStyle)
            break
          }
        }
      }
  }

  return {
    indicator = blk.getStr("rwrIndicator", ""),
    style = style
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
  ["TEWS MFD"]  = rwrTewsMfd,
  ["AN/ALR-67"] = rwrAnAlr67,
  ["AN/ALR-67 MFD"] = rwrAnAlr67Mfd,
  ["ARI-23333"] = rwrAri23333,
  ["ARI-18228"] = rwrAri18228,
  ["ARI-18241"] = rwrAri18241,
  ["AN/APR-39"] = rwrAnApr39,
  ["AN/APR-39 MFD"] = rwrAnApr39Mfd,
  ["AN/APR-39/APR-42"] = rwrAnApr39Apr42,
  ["Serval"] = rwrServal,
  ["Spectra"] = rwrSpectra,
  ["Ar830"] = rwrAr830,
  ["Ar830Extra"] = rwrAr830Extra,
  ["L-150"] = rwrL150,
  ["L-150 Su-30"] = rwrL150Su30,
  ["DASS"] = rwrDass
}

let planeRwr = @(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult) function() {
  let { indicator, style = null } = rwrSetting.get()
  return {
    watch = rwrSetting
    children = rwrs?[indicator] != null ?
      (rwrs[indicator])(posWatched, sizeWatched, scale, style) :
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