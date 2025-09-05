from "%rGui/globals/ui_library.nut" import *

let { setHeadMountedSystemPanelId } = require("hudState")
let { createScriptComponent } = require("%rGui/utils/builders.nut")

let { HmdVisibleAAM, HmdFovMult } = require("%rGui/rocketAamAimState.nut")
let { HmdSensorVisible } = require("%rGui/radarState.nut")
let { HmdVisible, HmdBlockIls, HmdBrightnessMult } = require("%rGui/planeState/planeToolsState.nut")
let { PNL_ID_HMD, PNL_ID_INVALID } = require("%rGui/globals/panelIds.nut")

let hmdShelZoom = require("%rGui/planeHmds/hmdShelZoom.nut")
let hmdVtas = require("%rGui/planeHmds/hmdVtas.nut")
let hmdF16c = require("%rGui/planeHmds/hmdF16c.nut")
let hmdAH64 = require("%rGui/planeHmds/hmdAh64.nut")
let hmdJas39 = require("%rGui/planeHmds/hmdJas39.nut")
let hmdA10c = require("%rGui/planeHmds/hmdA10c.nut")
let hmdTopOwl = require("%rGui/planeHmds/hmdTopOwl.nut")
let hmdTornado = require("%rGui/planeHmds/hmdTornado.nut")
let hmdTyphoon = require("%rGui/planeHmds/hmdTyphoon.nut")
let hmdRafale = require("%rGui/planeHmds/hmdRafale.nut")
let { isInVr } = require("%rGui/style/screenState.nut")
let { IPoint2, Point2, Point3 } = require("dagor.math")

let hmdF15cBaz = createScriptComponent("%rGui/planeHmds/hmdF15cBazMsip.das", {
  fontId = Fonts.hud
})
let hmdF106 = createScriptComponent("%rGui/planeHmds/hmdF106.das")

let hmdSetting = Watched({
  isShelZoom = false,
  isVtas = false,
  isF16c = false,
  isF15cBaz = false
  isAh64 = false,
  isJas39 = false,
  isMetric = false,
  isTornado = false,
  isA10c = false,
  isTopOwl = false,
  isTyphoon = false,
  isRafale = false,
  isF106 = false,
})

function hmdSettingsUpd(blk) {
  hmdSetting.set({
    isShelZoom = blk.getBool("hmdShelZoom", false),
    isVtas = blk.getBool("hmdVtas", false),
    isF16c = blk.getBool("hmdF16c", false),
    isF15cBaz = blk.getBool("hmdF15cBaz", false),
    isAh64 = blk.getBool("hmdAH64", false),
    isMetric = blk.getBool("isMetricHmd", false),
    isJas39 = blk.getBool("hmdJas39", false),
    isA10c = blk.getBool("hmdA10c", false),
    isTopOwl = blk.getBool("hmdTopOwl", false),
    isTornado = blk.getBool("hmdTornado", false),
    isTyphoon = blk.getBool("hmdTyphoon", false),
    isRafale = blk.getBool("hmdRafale", false),
    isF106 = blk.getBool("hmdF106", false)
  })
}

let isVisible = Computed(@() (HmdVisibleAAM.get() || HmdSensorVisible.get() || HmdVisible.get()) && !HmdBlockIls.get())
let planeHmd = @(width, height) function() {
  let { isShelZoom, isVtas, isF16c, isF15cBaz, isAh64, isMetric, isJas39, isA10c, isTopOwl, isTornado, isTyphoon, isRafale, isF106 } = hmdSetting.get()
  return {
    watch = [hmdSetting, isVisible]
    children = isVisible.get() ? [
      (isShelZoom ? hmdShelZoom(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null),
      (isF16c ? hmdF16c(width, height, isMetric) : null),
      (isF15cBaz ? hmdF15cBaz(width, height) : null),
      (isAh64 ? hmdAH64(width, height) : null),
      (isJas39 ? hmdJas39(width, height, isMetric) : null),
      (isA10c ? hmdA10c(width, height) : null),
      (isTopOwl ? hmdTopOwl(width, height) : null),
      (isTornado ? hmdTornado(width, height) : null),
      (isTyphoon ? hmdTyphoon(width, height) : null),
      (isRafale ? hmdRafale(width, height) : null),
      (isF106 ? hmdF106(width, height) : null)
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
  worldOffset   = Point3(0.0, 0.0, 50.0 * HmdFovMult.get() * screenAspectRatio)
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
  children = isVisible.get() ? planeHmdElement : null
}

return {
  planeHmdElem = root
  hmdSettingsUpd
}