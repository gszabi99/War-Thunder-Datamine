from "%rGui/globals/ui_library.nut" import *
from "string" import format
let mkTankSight = require("%rGui/tankSight.nut")
let extWatched = require("globals/extWatched.nut")

const BG_IMAGES_COUNT = 4
const BG_IMAGE_SRC_TEMPLATE = "ui/images/tank_sight_preview_%d_%s.avif:0:P"

let bgImageIdx = Watched(0)
let isNightVision = extWatched("isTankSightNightVisionPreview", false)
let isThermal = extWatched("isTankSightThermalPreview", false)

let getBgImageSrc = @(imageIdx, isNv, isTh)
  format(BG_IMAGE_SRC_TEMPLATE, imageIdx + 1, isNv || isTh ? "night" : "day")

let bgImageSrc = Computed(@() getBgImageSrc(bgImageIdx.get(), isNightVision.get(), isThermal.get()))

function mkPreviewImg(imgIdx) {
  let stateFlags = Watched(0)
  let isCurImgBg = Computed(@() imgIdx == bgImageIdx.get())

  return @() {
    watch = [isCurImgBg, stateFlags]
    size = [hdpx(192), hdpx(108)]
    rendObj = ROBJ_BOX
    borderWidth = hdpx(1)
    padding = hdpx(1)
    borderColor = isCurImgBg.get() || (stateFlags.get() & S_HOVER)
      ? 0xFFFFFFFF
      : 0x99999999

    behavior = Behaviors.Button
    onElemState = @(v) stateFlags.set(v)
    onClick = @() bgImageIdx.set(imgIdx)

    children = @() {
      watch = [stateFlags, isNightVision, isCurImgBg]
      size = flex()
      opacity = isCurImgBg.get() ? 1
        : stateFlags.get() & S_HOVER ? 0.8
        : 0.5
      rendObj = ROBJ_IMAGE
      image = Picture(getBgImageSrc(imgIdx, isNightVision.get(), isThermal.get()))
      transitions = [{ prop = AnimProp.opacity, duration = 0.15, easing = OutCubic }]
    }
  }
}

let previewBgImagesComp = {
  pos = [0, hdpx(880)]
  rendObj = ROBJ_BOX
  flow = FLOW_HORIZONTAL
  gap = hdpx(12)
  children = array(BG_IMAGES_COUNT).map(@(_, idx) mkPreviewImg(idx))
}

let backgroundImgComp = @() {
  watch = bgImageSrc
  size = flex()
  rendObj = ROBJ_IMAGE
  image = Picture(bgImageSrc.get())
}

let tankSightPreview = {
  size = flex()
  rendObj = ROBJ_BOX
  fillColor = 0xff000000
  halign = ALIGN_CENTER
  children = [
    backgroundImgComp
    {
      rendObj = ROBJ_CROSSHAIR_PREVIEW
      size = flex()
    }
    mkTankSight(true)
    previewBgImagesComp
  ]
}

return tankSightPreview