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
let { litening2, mfdCamLitening2SettingsUpd } = require("%rGui/planeCockpit/mfdLitening2.nut")

let eurocopter = createScriptComponent("%rGui/planeCockpit/mfdCamEurocopter.das", {
  fontId = Fonts.hud
  fontScale = 1.0
  lineWidthScale = 1.0
})

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

let atlis2 = createScriptComponent("%rGui/planeCockpit/mfdAtlis2.das", {
  fontId = Fonts.hud
  isMetricUnits = true
})

let atflir = createScriptComponent("%rGui/planeCockpit/mfdCamAtflir.das", {
  fontId = Fonts.hud
})

let lantirn = createScriptComponent("%rGui/planeCockpit/mfdCamLantirn.das", {
  fontId = Fonts.hud
})

let f4Agm65 = createScriptComponent("%rGui/planeCockpit/mfdF4Agm65Cam.das", {
  fontId = Fonts.hud
  vignette = Picture("!ui/gameuiskin#mfd_f4_agm65_vignetting_high.avif")
})

let oraoCam = createScriptComponent("%rGui/planeCockpit/mfdOraoTvCam.das", {
  fontId = Fonts.hud
})

let yak130Kab = createScriptComponent("%rGui/planeCockpit/mfdYak130Kab.das", {
  fontId = Fonts.ils31
})

let b52hEvs = createScriptComponent("%rGui/planeCockpit/mfdCamB52hEvs.das", {
  fontId = Fonts.hud
  fontScale = 1.0
  lineWidthScale = 1.0
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
  isMi35en = false
  isAtlis2 = false
  isAtflir = false
  isEurocopter = false
  isLantirn = false
  isF4Agm65 = false
  isOraoCam = false
  isB52hEvs = false
  isYak130Kab = false
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
    isAtlis2 = blk.getBool("mfdCamAtlis2", false)
    isAtflir = blk.getBool("mfdCamAtflir", false)
    isEurocopter = blk.getBool("mfdCamEurocopter", false)
    isLantirn = blk.getBool("mfdCamLantirn", false)
    isF4Agm65 = blk.getBool("mfdCamF4Agm65", false)
    isOraoCam = blk.getBool("mfdCamOrao", false)
    isB52hEvs = blk.getBool("mfdCamB52hEvs", false)
    isYak130Kab = blk.getBool("mfdCamYak130Kab", false)

    lineWidthScale = blk.getReal("mfdCamLineScale", 1.0)
    fontScale = blk.getReal("mfdCamFontScale", 1.0)
  })

  if (mfdCameraSetting.get().isLitening2)
    mfdCamLitening2SettingsUpd(blk)
}

let planeMfdCamera = @(width, height) function() {
  let {isShkval, isShkvalKa52, isTads, isTadsApache, lineWidthScale, fontScale, isPlatan, isDamocles, isLitening2,
    isMi35, isMi35en, isAtlis2, isAtflir, isEurocopter, isLantirn, isF4Agm65, isOraoCam, isB52hEvs, isYak130Kab} = mfdCameraSetting.get()
  return {
    watch = mfdCameraSetting
    children = [
      isShkval ? shkval(width, height, lineWidthScale, fontScale) :
      isShkvalKa52 ? shkvalKa52.root(width, height) :
      isTads ? tads.root(width, height, false) :
      isTadsApache ? tads.root(width, height, true) :
      isPlatan ? platan(width, height) :
      isDamocles ? damocles(width, height) :
      isLitening2 ? litening2(width, height, fontScale, lineWidthScale) :
      isMi35 ? mi35ACC(width, height) :
      isMi35en ? mi35ACCEn(width, height) :
      isAtlis2 ? atlis2(width, height) :
      isAtflir ? atflir(width, height) :
      isEurocopter ? eurocopter(width, height) :
      isLantirn ? lantirn(width, height) :
      isF4Agm65 ? f4Agm65(width, height) :
      isOraoCam ? oraoCam(width, height) :
      isB52hEvs ? b52hEvs(width, height) :
      isYak130Kab ? yak130Kab(width, height) :
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
  mfdCameraSetting
}