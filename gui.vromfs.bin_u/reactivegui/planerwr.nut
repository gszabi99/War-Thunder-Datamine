import "%sqStdLibs/helpers/u.nut" as u
import "%rGui/planeRwrs/rwrAnApr25.nut" as rwrAnApr25
import "%rGui/planeRwrs/rwrAnAps109.nut" as rwrAnAps109
import "%rGui/planeRwrs/rwrAnAlr45.nut" as rwrAnAlr45
import "%rGui/planeRwrs/rwrAnAlr46.nut" as rwrAnAlr46
import "%rGui/planeRwrs/rwrAnAlr46MfdF5Th.nut" as rwrAnAlr46MfdF5Th
import "%rGui/planeRwrs/rwrAnAlr56.nut" as rwrAnAlr56
import "%rGui/planeRwrs/rwrTews.nut" as rwrTews
import "%rGui/planeRwrs/rwrTewsMfd.nut" as rwrTewsMfd
import "%rGui/planeRwrs/rwrAnAlr67.nut" as rwrAnAlr67
import "%rGui/planeRwrs/rwrAnAlr67Mfd.nut" as rwrAnAlr67Mfd
import "%rGui/planeRwrs/rwrAri23333.nut" as rwrAri23333
import "%rGui/planeRwrs/rwrAri18228.nut" as rwrAri18228
import "%rGui/planeRwrs/rwrAri18241.nut" as rwrAri18241
import "%rGui/planeRwrs/rwrAnApr39.nut" as rwrAnApr39
import "%rGui/planeRwrs/rwrAnApr39Mfd.nut" as rwrAnApr39Mfd
import "%rGui/planeRwrs/rwrAnApr39MfdAh1Z.nut" as rwrAnApr39MfdAh1Z
import "%rGui/planeRwrs/rwrAnApr39Apr42.nut" as rwrAnApr39Apr42
import "%rGui/planeRwrs/rwrServal.nut" as rwrServal
import "%rGui/planeRwrs/rwrSpectra.nut" as rwrSpectra
import "%rGui/planeRwrs/rwrAr830.nut" as rwrAr830
import "%rGui/planeRwrs/rwrL150Mig.nut" as rwrL150Mig
import "%rGui/planeRwrs/rwrL150Su30.nut" as rwrL150Su30
import "%rGui/planeRwrs/rwrDass.nut" as rwrDass
import "%rGui/planeRwrs/rwrL150Ka52.nut" as rwrL150Ka52
from "%rGui/tws.nut" import tws
from "%rGui/planeRwrs/rwrAr830Extra.nut" import rwrAr830Extra, jas39ERwrScreen
from "%rGui/globals/ui_library.nut" import *

let rwrL150 = require("%rGui/planeRwrs/rwrL150.nut").tws

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

let rwrSetting = Watched({
    indicator = null
  })

function rwrSettingUpd(mfd_blk, rwr_type) {
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
  local defFontScale = -1.0
  local verticalScale = 1.0
  for (local i = 0; i < mfd_blk.blockCount(); ++i) {
    let displayBlk = mfd_blk.getBlock(i)
    local displayStyle = u.copy(styleDef)
    loadStyle(displayStyle, displayBlk, styleDef)
    for (local j = 0; j < displayBlk.blockCount(); ++j) {
      let pageBlk = displayBlk.getBlock(j)
      let typeStr = pageBlk.getStr("type", "")
      if (typeStr == "rwr") {
        loadStyle(style, pageBlk, displayStyle)
        defFontScale = pageBlk.getReal("fontScale", -1.0)
        verticalScale = pageBlk.getReal("verticalScale", 1.0)
        break
      }
    }
  }
  style.verticalScale <- verticalScale

  rwrSetting.set({
    indicator = rwr_type,
    style = style
    defFontScale
  })
}

function rwrDefault(posWatched, sizeWatched, colorWatched, scaleDef, backHide, fontSizeMult) {
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
  ["AN/ALR-46 MFD F-5TH"] = rwrAnAlr46MfdF5Th,
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
  ["AN/APR-39 MFD Ah-1Z"] = rwrAnApr39MfdAh1Z,
  ["AN/APR-39/APR-42"] = rwrAnApr39Apr42,
  ["Serval"] = rwrServal,
  ["Spectra"] = rwrSpectra,
  ["Ar830"] = rwrAr830,
  ["Ar830Extra"] = rwrAr830Extra,
  ["jas39ERwrScreen"] = jas39ERwrScreen,
  ["L-150"] = rwrL150,
  ["L-150 MIG"] = rwrL150Mig,
  ["L-150 Su-30"] = rwrL150Su30,
  ["DASS"] = rwrDass,
  ["L-150 Ka-52"] = rwrL150Ka52
}

let planeRwr = @(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult) function() {
  let { indicator, style = null, defFontScale = fontSizeMult } = rwrSetting.get()
  return {
    watch = rwrSetting
    children = rwrs?[indicator] != null ?
      (rwrs[indicator])(posWatched, sizeWatched, scale, style) :
      rwrDefault(posWatched, sizeWatched, colorWatched, scaleDef, backHide, defFontScale > 0.0 ? defFontScale : fontSizeMult)
  }
}

function planeRwrSwitcher(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult) {
  return {
    halign = ALIGN_LEFT
    valign = ALIGN_TOP
    size = SIZE_TO_CONTENT
    children = planeRwr(posWatched, sizeWatched, colorWatched, scaleDef, backHide, scale, fontSizeMult)
  }
}

return {
  planeRwrSwitcher
  rwrSettingUpd
}