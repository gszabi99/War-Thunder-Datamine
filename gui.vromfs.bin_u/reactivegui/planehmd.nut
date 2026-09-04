import "%rGui/planeHmds/hmdShel.nut" as hmdShel
import "%rGui/planeHmds/hmdSura.nut" as hmdSura
import "%rGui/planeHmds/hmdVtas.nut" as hmdVtas
import "%rGui/planeHmds/hmdJhmcsGen1.nut" as hmdJhmcsGen1
import "%rGui/planeHmds/hmdIhadss.nut" as hmdIhadss
import "%rGui/planeHmds/hmdCobraHmd.nut" as hmdCobraHmd
import "%rGui/planeHmds/hmdScorpionHmcs.nut" as hmdScorpionHmcs
import "%rGui/planeHmds/hmdTopOwl.nut" as hmdTopOwl
import "%rGui/planeHmds/hmdStrikerHmd.nut" as hmdStrikerHmd
import "%rGui/planeHmds/hmdStrikerHss.nut" as hmdStrikerHss
import "%rGui/planeHmds/hmdTargo.nut" as hmdTargo
import "%rGui/planeHmds/hmdZ10.nut" as hmdZ10
from "%rGui/utils/builders.nut" import createScriptComponent
from "%rGui/rocketAamAimState.nut" import HmdVisibleAAM, HmdFovMult
from "%rGui/radarState.nut" import HmdSensorVisible
from "%rGui/planeState/planeToolsState.nut" import HmdVisible, HmdBlockIls, HmdBrightnessMult
from "%rGui/globals/panelIds.nut" import PNL_ID_HMD, PNL_ID_INVALID
from "%rGui/style/screenState.nut" import isInVr
from "hudState" import setHeadMountedSystemPanelId
from "dagor.math" import IPoint2, Point2, Point3
from "%rGui/globals/ui_library.nut" import *

let hmdDashGen3 = createScriptComponent("%rGui/planeHmds/hmdDashGen3.das", {
  fontId = Fonts.hud
})
let hmdF106 = createScriptComponent("%rGui/planeHmds/hmdF106.das")
let hmdAh56 = createScriptComponent("%rGui/planeHmds/hmdAh56.das")
let hmdHssReticle = createScriptComponent("%rGui/planeHmds/hmdHssReticle.das")
let hmdScorpionHmd = createScriptComponent("%rGui/planeHmds/hmdScorpionHmd.das", { fontId = Fonts.hud })
let hmdJhmcsGen2 = createScriptComponent("%rGui/planeHmds/hmdJhmcsGen2.das", {
  fontId = Fonts.hud
})
let hmdTkxGen1 = createScriptComponent("%rGui/planeHmds/hmdTkxGen1.das", {
  fontId = Fonts.hud
})
let hmdKaiser = createScriptComponent("%rGui/planeHmds/hmdKaiser.das", {
  fontId = Fonts.hud
})
let hmdMig35 = createScriptComponent("%rGui/planeHmds/hmdMig35.das", {
  fontId = Fonts.hud
})

let hmdSetting = Watched({
  isShel = false,
  isSura = false,
  isVtas = false,
  isJhmcsGen1 = false,
  isDashGen3 = false
  isIhadss = false,
  isCobraHmd = false,
  isMetric = false,
  isStrikerHmd = false,
  isScorpionHmcs = false,
  isTopOwl = false,
  isStrikerHss = false,
  isScorpionHmd = false,
  isF106 = false,
  isAh56 = false,
  isHssReticle = false,
  isTargo = false,
  isJhmcsGen2 = false,
  isZ10 = false,
  isTkxGen1 = false,
  isKaiser = false,
  isMig35 = false,
})

function hmdSettingsUpd(blk) {
  hmdSetting.set({
    isShel = blk.getBool("hmdShel", false),
    isSura = blk.getBool("hmdSura", false),
    isVtas = blk.getBool("hmdVtas", false),
    isJhmcsGen1 = blk.getBool("hmdJhmcsGen1", false),
    isDashGen3 = blk.getBool("hmdDashGen3", false),
    isIhadss = blk.getBool("hmdIhadss", false),
    isMetric = blk.getBool("isMetricHmd", false),
    isCobraHmd = blk.getBool("hmdCobraHmd", false),
    isScorpionHmcs = blk.getBool("hmdScorpionHmcs", false),
    isTopOwl = blk.getBool("hmdTopOwl", false),
    isStrikerHmd = blk.getBool("hmdStrikerHmd", false),
    isStrikerHss = blk.getBool("hmdStrikerHss", false),
    isScorpionHmd = blk.getBool("hmdScorpionHmd", false),
    isF106 = blk.getBool("hmdF106", false),
    isAh56 = blk.getBool("hmdAh56", false),
    isHssReticle = blk.getBool("hmdHssReticle", false),
    isTargo = blk.getBool("hmdTargo", false),
    isJhmcsGen2 = blk.getBool("hmdJhmcsGen2", false),
    isZ10 = blk.getBool("hmdZ10", false),
    isTkxGen1 = blk.getBool("hmdTkxGen1", false),
    isKaiser = blk.getBool("hmdKaiser", false),
    isMig35 = blk.getBool("hmdMig35", false),
  })
}

let isVisible = Computed(@() (HmdVisibleAAM.get() || HmdSensorVisible.get() || HmdVisible.get()) && !HmdBlockIls.get())
let planeHmd = @(width, height) function() {
  let { isShel, isSura, isVtas, isJhmcsGen1, isDashGen3, isIhadss, isMetric, isCobraHmd, isScorpionHmcs, isTopOwl, isStrikerHmd, isStrikerHss,
    isScorpionHmd, isF106, isAh56, isHssReticle, isTargo, isJhmcsGen2, isZ10, isTkxGen1, isKaiser, isMig35} = hmdSetting.get()
  return {
    watch = [hmdSetting, isVisible]
    children = isVisible.get() ? [
      (isShel ? hmdShel(width, height) : null),
      (isSura ? hmdSura(width, height) : null),
      (isVtas ? hmdVtas(width, height) : null),
      (isJhmcsGen1 ? hmdJhmcsGen1(width, height, isMetric) : null),
      (isDashGen3 ? hmdDashGen3(width, height) : null),
      (isIhadss ? hmdIhadss(width, height) : null),
      (isCobraHmd ? hmdCobraHmd(width, height, isMetric) : null),
      (isScorpionHmcs ? hmdScorpionHmcs(width, height) : null),
      (isTopOwl ? hmdTopOwl(width, height) : null),
      (isStrikerHmd ? hmdStrikerHmd(width, height) : null),
      (isStrikerHss ? hmdStrikerHss(width, height) : null),
      (isScorpionHmd ? hmdScorpionHmd(width, height) : null),
      (isF106 ? hmdF106(width, height) : null),
      (isAh56 ? hmdAh56(width, height) : null),
      (isHssReticle ? hmdHssReticle(width, height) : null),
      (isTargo ? hmdTargo(width, height) : null),
      (isJhmcsGen2 ? hmdJhmcsGen2(width, height) : null),
      (isZ10 ? hmdZ10(width, height) : null),
      (isTkxGen1 ? hmdTkxGen1(width, height) : null),
      (isKaiser ? hmdKaiser(width, height) : null),
      (isMig35 ? hmdMig35(width, height) : null),
    ] : null
  }
}

const pnlDistanceMeters = 100.0
const pnlWidthPx = hdpx(1920)
const pnlHeightPx = hdpx(1080)
const pnlAspectRatio = pnlWidthPx / pnlHeightPx
const pnlHeightMeters = 80.0
const pnlWidthMeters = pnlHeightMeters * pnlAspectRatio
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

const screenAspectRatio = sw(100) / sh(100)
let screenHmdLayout = @() {
  watch = [HmdFovMult, HmdBrightnessMult]
  worldAnchor   = PANEL_ANCHOR_HEAD
  worldGeometry = PANEL_GEOMETRY_RECTANGLE
  worldOffset   = Point3(0.0, 0.0, 50.0 * HmdFovMult.get() * screenAspectRatio)
  worldSize     = Point2(100 * screenAspectRatio, 100)
  canvasSize    = IPoint2(sw(100), sh(100))
  renderAfterAA = true

  worldCanBePointedAt = false
  worldBrightness = 200. * HmdBrightnessMult.get()
  worldRenderFeatures = PANEL_RENDER_ALWAYS_ON_TOP

  size   = SIZE_TO_CONTENT
  halign = ALIGN_CENTER
  valign = ALIGN_CENTER
  children = HmdBrightnessMult.get() > 0.0 ? planeHmd(sw(100), sh(100)) : null
}

let planeHmdElement = {
  size = FLEX
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