from "%rGui/globals/ui_library.nut" import *

let opticAtgmSight = require("%rGui/opticAtgmSight.nut")
let heliStockCamera = require("%rGui/planeCockpit/mfdHeliCamera.nut")
let shkval = require("%rGui/planeCockpit/mfdShkval.nut")
let shkvalKa52 = require("%rGui/planeCockpit/mfdShkvalKa52.nut")
let tads = require("%rGui/planeCockpit/mfdTads.nut")
let platan = require("%rGui/planeCockpit/mfdPlatan.nut")
let { IsMfdSightHudVisible, MfdSightPosSize } = require("%rGui/airState.nut")
let hudUnitType = require("%rGui/hudUnitType.nut")
let { createScriptComponent } = require("%rGui/utils/builders.nut")
let litening2 = require("%rGui/planeCockpit/mfdLitening2.nut")

let damocles = createScriptComponent("%rGui/planeCockpit/mfdDamocles.das", {
  fontId = Fonts.hud
  isMetricUnits = true
})

let mi35ACC = createScriptComponent("%rGui/planeCockpit/mfdMi35ACC.das", {
  fontId = Fonts.hud
  english = false
})
let mi35ACCEn = createScriptComponent("%rGui/planeCockpit/mfdMi35ACC.das", {
  fontId = Fonts.hud
  english = true
})

let mfdCameraSetting = Watched({
  isShkval = false
  isShkvalKa52 = false
  isTads = false
  isTadsApache = false
  isPlatan = false
  isDamocles = false
  isLitening2 = false
  isMi35 = false
  lineWidthScale = 1.0
  fontScale = 1.0
})

function mfdCameraSettingUpd(blk) {
  mfdCameraSetting.set({
    isShkval = blk.getBool("mfdCamShkval", false)
    isShkvalKa52 = blk.getBool("mfdCamShkvalKa52", false)
    isTads = blk.getBool("mfdCamTads", false)
    isTadsApache = blk.getBool("mfdCamTadsApache", false)
    isPlatan = blk.getBool("mfdCamPlatan", false)
    isDamocles = blk.getBool("mfdCamDamocles", false)
    isLitening2 = blk.getBool("mfdCamLitening2", false)
    isMi35 = blk.getBool("mfdMi35", false)
    isMi35en = blk.getBool("mfdMi35en", false)

    lineWidthScale = blk.getReal("mfdCamLineScale", 1.0)
    fontScale = blk.getReal("mfdCamFontScale", 1.0)
  })
}

let planeMfdCamera = @(width, height) function() {
  let {isShkval, isShkvalKa52, isTads, isTadsApache, lineWidthScale, fontScale, isPlatan, isDamocles, isLitening2, isMi35, isMi35en} = mfdCameraSetting.get()
  return {
    watch = mfdCameraSetting
    children = [
      isShkval ? shkval(width, height, lineWidthScale, fontScale) :
      isShkvalKa52 ? shkvalKa52(width, height) :
      isTads ? tads(width, height, false) :
      isTadsApache ? tads(width, height, true) :
      isPlatan ? platan(width, height) :
      isDamocles ? damocles(width, height) :
      isLitening2 ? litening2(width, height, fontScale, lineWidthScale) :
      isMi35 ? mi35ACC(width, height) :
      isMi35en ? mi35ACCEn(width, height) :
      hudUnitType.isHelicopter() ? heliStockCamera : opticAtgmSight(width, height, 0, 0)
    ]
  }
}

let planeMfdCameraSwitcher = @() {
  watch = [IsMfdSightHudVisible, MfdSightPosSize]
  pos = [MfdSightPosSize.get()[0], MfdSightPosSize.get()[1]]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IsMfdSightHudVisible.get() ? [ planeMfdCamera(MfdSightPosSize.get()[2], MfdSightPosSize.get()[3])] : null
}

return {
  planeMfdCameraSwitcher
  mfdCameraSettingUpd
}