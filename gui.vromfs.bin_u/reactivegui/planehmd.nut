from "%rGui/globals/ui_library.nut" import *

let DataBlock = require("DataBlock")
let { setHeadMountedSystemPanelId } = require("hudState")

let { HmdVisibleAAM, HmdFovMult } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible } = require("%rGui/radarState.nut")
let { BlkFileName, HmdVisible, HmdBlockIls, HmdBrightnessMult } = require("planeState/planeToolsState.nut")
let { PNL_ID_HMD, PNL_ID_INVALID } = require("%rGui/globals/panelIds.nut")

let hmdShelZoom = require("planeHmds/hmdShelZoom.nut")
let hmdVtas = require("planeHmds/hmdVtas.nut")
let hmdF16c = require("planeHmds/hmdF16c.nut")
let hmdAH64 = require("planeHmds/hmdAh64.nut")
let hmdJas39 = require("planeHmds/hmdJas39.nut")
let hmdA10c = require("planeHmds/hmdA10c.nut")
let hmdTopOwl = require("planeHmds/hmdTopOwl.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { IPoint2, Point2, Point3 } = require("dagor.math")

let hmdSetting = Computed(function() {
  let res = {
    isShelZoom = false,
    isVtas = false,
    isF16c = false,
    isAh64 = false,
    isJas39 = false,
    isMetric = false,
    isA10c = false,
    isTopOwl = false
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
    isF16c = blk.getBool("hmdF16c", false),
    isAh64 = blk.getBool("hmdAH64", false),
    isMetric = blk.getBool("isMetricHmd", false),
    isJas39 = blk.getBool("hmdJas39", false),
    isA10c = blk.getBool("hmdA10c", false),
    isTopOwl = blk.getBool("hmdTopOwl", false)
  }
})

let isVisible = Computed(@() (HmdVisibleAAM.value || HmdSensorVisible.value || HmdVisible.value) && !HmdBlockIls.value)
let planeHmd = @(width, height) function() {
  let { isShelZoom, isVtas, isF16c, isAh64, isMetric, isJas39, isA10c, isTopOwl } = hmdSetting.value
  return {
    watch = [hmdSetting, isVisible]
    children = isVisible.value ? [
      (isShelZoom ? hmdShelZoom(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null),
      (isF16c ? hmdF16c(width, height, isMetric) : null),
      (isAh64 ? hmdAH64(width, height) : null),
      (isJas39 ? hmdJas39(width, height, isMetric) : null),
      (isA10c ? hmdA10c(width, height) : null),
      (isTopOwl ? hmdTopOwl(width, height) : null)
    ] : null
  }
}

let pnlDistanceMeters = 100.0
let pnlWidthPx = hdpx(1920)
let pnlHeightPx = hdpx(1080)
let pnlAspectRatio = pnlWidthPx / pnlHeightPx
let pnlHeightMeters = 80.0
let pnlWidthMeters = pnlHeightMeters * pnlAspectRatio
let vrHmdLayout = @(){
  watch = HmdBrightnessMult
  worldAnchor   = PANEL_ANCHOR_HEAD
  worldGeometry = PANEL_GEOMETRY_RECTANGLE
  worldOffset   = Point3(0.0, 0.0, pnlDistanceMeters)
  worldSize     = Point2(pnlWidthMeters, pnlHeightMeters)
  canvasSize    = IPoint2(pnlWidthPx, pnlHeightPx)

  worldCanBePointedAt = false
  worldBrightness = 200 * HmdBrightnessMult.get()
  worldRenderFeatures = PANEL_RENDER_ALWAYS_ON_TOP

  size    = SIZE_TO_CONTENT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = HmdBrightnessMult.get() > 0.0 ? planeHmd(pnlWidthPx, pnlHeightPx) : null
}

let screenAspectRatio = sw(100) / sh(100)
let screenHmdLayout = @() {
  watch = [HmdFovMult, HmdBrightnessMult]
  worldAnchor   = PANEL_ANCHOR_HEAD
  worldGeometry = PANEL_GEOMETRY_RECTANGLE
  worldOffset   = Point3(0.0, 0.0, 100 * HmdFovMult.value)
  worldSize     = Point2(100 * screenAspectRatio, 100)
  canvasSize    = IPoint2(sw(100), sh(100))

  worldCanBePointedAt = false
  worldBrightness = 200. * HmdBrightnessMult.get()
  worldRenderFeatures = PANEL_RENDER_ALWAYS_ON_TOP

  size   = SIZE_TO_CONTENT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = HmdBrightnessMult.get() > 0.0 ? planeHmd(sw(100), sh(100)) : null
}

let planeHmdElement = {
  size = flex()
  onAttach = function() {
    setHeadMountedSystemPanelId(PNL_ID_HMD)
    gui_scene.addPanel(PNL_ID_HMD, isInVr ? vrHmdLayout : screenHmdLayout)
  }
  onDetach = function() {
    setHeadMountedSystemPanelId(PNL_ID_INVALID)
    gui_scene.removePanel(PNL_ID_HMD)
  }
}

let root = @() {
  watch = isVisible
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = isVisible.value ? planeHmdElement : null
}

return root