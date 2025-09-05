from "%rGui/globals/ui_library.nut" import *
from "string" import format
let mkTankSight = require("%rGui/tankSight.nut")
let extWatched = require("%rGui/globals/extWatched.nut")

let PREVIEW_IMAGE_WIDTH = hdpx(192)
let PREVIEW_IMAGE_HEIGHT = hdpx(108)

const BG_IMAGES_COUNT = 4
const BG_IMAGE_SRC_TEMPLATE = "ui/images/sight_menu_bg/tank_sight_preview_%d_%s.avif:0:P"
let PREVIEW_IMAGE_SRC_TEMPLATE
  = $"ui/images/sight_menu_bg/tank_sight_preview_sm_%d_%s.avif:{PREVIEW_IMAGE_WIDTH}:{PREVIEW_IMAGE_HEIGHT}:P"

let bgImageIdx = Watched(0)
let bgImagePostfix = extWatched("tankSightBgImageModePostfix", "day")
let isPreviewMode = extWatched("tankSightIsPreviewMode", false)

let getBgImageSrc = @(imageIdx, postfix)
  format(BG_IMAGE_SRC_TEMPLATE, imageIdx + 1, postfix)
let getBgPreviewImageSrc = @(imageIdx, postfix)
  format(PREVIEW_IMAGE_SRC_TEMPLATE, imageIdx + 1, postfix)

let bgImageSrc = Computed(@() getBgImageSrc(bgImageIdx.get(), bgImagePostfix.get()))

function mkPreviewImg(imgIdx) {
  let stateFlags = Watched(0)
  let isCurImgBg = Computed(@() imgIdx == bgImageIdx.get())

  return @() {
    watch = [isCurImgBg, stateFlags]
    size = [PREVIEW_IMAGE_WIDTH, PREVIEW_IMAGE_HEIGHT]
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
      watch = [stateFlags, isCurImgBg, bgImagePostfix]
      size = flex()
      opacity = isCurImgBg.get() ? 1
        : stateFlags.get() & S_HOVER ? 0.8
        : 0.5
      rendObj = ROBJ_IMAGE
      image = Picture(getBgPreviewImageSrc(imgIdx, bgImagePostfix.get()))
      transitions = [{ prop = AnimProp.opacity, duration = 0.15, easing = OutCubic }]
    }
  }
}

let previewBgImagesComp = @() {
  watch = isPreviewMode
  pos = [0, hdpx(880)]
  rendObj = ROBJ_BOX
  flow = FLOW_HORIZONTAL
  gap = hdpx(12)
  children = !isPreviewMode.get()
    ? array(BG_IMAGES_COUNT).map(@(_, idx) mkPreviewImg(idx))
    : null
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
    previewBgImagesComp
    mkTankSight(true)
  ]
}

return tankSightPreview