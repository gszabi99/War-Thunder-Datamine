from "%rGui/globals/ui_library.nut" import *

let { IlsVisible, IlsPosSize } = require("%rGui/planeState/planeToolsState.nut")
let { createScriptComponent } = require("%rGui/utils/builders.nut")

let { ilsAVQ7 } = require("%rGui/planeIlses/ilsAVQ7.nut")
let ASP17 = require("%rGui/planeIlses/ilsASP17.nut")
let buccaneerHUD = require("%rGui/planeIlses/ilsBuccaneer.nut")
let ilsSum410 = require("%rGui/planeIlses/ils410Sum.nut")
let ilsSeaHarrier = require("%rGui/planeIlses/ilsSeaHarrier.nut")
let { LCOSS, ASG23 } = require("%rGui/planeIlses/ilsLcoss.nut")
let { J7EAdditionalHud, ASP23ModeSelector } = require("%rGui/planeIlses/ilsASP23.nut")
let swedishEPIls = require("%rGui/planeIlses/ilsEP.nut")
let ShimadzuIls = require("%rGui/planeIlses/ilsShimadzu.nut")
let TCSF196 = require("%rGui/planeIlses/ilsTcsf196.nut")
let J8IIHK = require("%rGui/planeIlses/ilsJ8IIhk.nut")
let KaiserA10 = require("%rGui/planeIlses/ilsKaiserA10.nut")
let F14 = require("%rGui/planeIlses/ilsF14Tomcat.nut")
let mig17 = require("%rGui/planeIlses/ilsMig17pf.nut")
let TCSFVE130 = require("%rGui/planeIlses/ilsTcsfVE130.nut")
let SU145 = require("%rGui/planeIlses/ilsSu145.nut")
let Ils31 = require("%rGui/planeIlses/ils31.nut")
let MarconiAvionics = require("%rGui/planeIlses/ilsMarconiAvionics.nut")
let Tornado = require("%rGui/planeIlses/ilsTornado.nut")
let Elbit = require("%rGui/planeIlses/ilsElbit967.nut")
let StockHeliIls = require("%rGui/heliIls.nut")
let Ils28K = require("%rGui/planeIlses/ils28k.nut")
let ilsF15a = require("%rGui/planeIlses/ilsF15a.nut")
let ilsF15e = require("%rGui/planeIlses/ilsF15e.nut")
let ilsEP17 = require("%rGui/planeIlses/ilsEP17.nut")
let ilsAmx = require("%rGui/planeIlses/ilsAmx.nut")
let KaiserVDO = require("%rGui/planeIlses/ilsKaiserVDO.nut")
let ilsKai24p = require("%rGui/planeIlses/ilsKai24p.nut")
let ilsF20 = require("%rGui/planeIlses/ilsF20.nut")
let ilsF117 = require("%rGui/planeIlses/ilsF117.nut")
let ilsSu34 = require("%rGui/planeIlses/ilsSu34.nut")
let {IlsTyphoon} = require("%rGui/planeIlses/ilsTyphoon.nut")

let ilsRafale = createScriptComponent("%rGui/planeIlses/ilsRafale.das", {
  fontId = Fonts.hud
  isMetricUnits = true
  ilsFovDeg = 17.4
})

let ilsF18 = createScriptComponent("%rGui/planeIlses/ilsF18.das", {
  fontId = Fonts.hud
  ilsFovDeg = 17.6
})
let ilsCth3022Su30 = createScriptComponent("%rGui/planeIlses/ilsCth3022Su30.das", {
  fontId = Fonts.ils31
  fontIdLatin = Fonts.hud
})

let ilsF106 = createScriptComponent("%rGui/planeCockpit/F106Radar.das", {
  fontId = Fonts.hud
  setupFunc = "setup_radar_data"
  drawFunc = "draw_radar_hud_reflector"
})

let ilsSetting = Watched({
  isASP17 = false
  isAVQ7 = false
  haveAVQ7CCIP = false
  haveAVQ7Bombing = false
  haveJ7ERadar = false
  isBuccaneerIls = false
  is410SUM1Ils = false
  isLCOSS = false
  isASP23 = false
  isEP12 = false
  isEP08 = false
  isShimadzu = false
  isIPP2_53 = false
  isTCSF196 = false
  isJ8HK = false
  isKaiserA10 = false
  isKaiserA10c = false
  isF14 = false
  isMig17pf = false
  isTcsfVe130 = false
  isSu145 = false
  isSeaHarrierIls = false
  isIls31 = false
  isIls28K = false
  isMarconi = false
  isTornado = false
  isElbit = false
  isASG23 = false
  isF15a = false
  isEP17 = false
  isAmx = false
  isVDO = false
  isKai24p = false
  isF20 = false
  isChinaLang = false
  isMetric = false
  isF15e = false
  isF117 = false
  isSu34 = false
  isTyphoon = false
  isIlsRafale = false
  isIlsF18 = false
  isIlsCth3022Su30 = false
  isIlsF106 = false
})

function ilsSettingsUpd(blk) {
  ilsSetting.set({
    isASP17 = blk.getBool("ilsASP17", false)
    isAVQ7 = blk.getBool("ilsAVQ7", false)
    haveAVQ7CCIP = blk.getBool("ilsHaveAVQ7CCIP", false)
    haveAVQ7Bombing = blk.getBool("ilsHaveAVQ7CCRP", false)
    isBuccaneerIls = blk.getBool("isBuccaneerIls", false)
    is410SUM1Ils = blk.getBool("is410SUM1Ils", false)
    isSeaHarrierIls = blk.getBool("ilsSeaHarrier", false)
    isLCOSS = blk.getBool("ilsLCOSS", false)
    isASP23 = blk.getBool("ilsASP23", false)
    haveJ7ERadar = blk.getBool("ilsHaveJ7ERadar", false)
    isEP12 = blk.getBool("ilsEP12", false)
    isEP08 = blk.getBool("ilsEP08", false)
    isShimadzu = blk.getBool("ilsShimadzu", false)
    isIPP2_53 = blk.getBool("ilsIPP_2_53", false)
    isTCSF196 = blk.getBool("ilsTCSF196", false)
    isJ8HK = blk.getBool("ilsJ8HK", false)
    isKaiserA10 = blk.getBool("ilsKaiserA10", false)
    isKaiserA10c = blk.getBool("ilsKaiserA10c", false)
    isF14 = blk.getBool("ilsF14", false)
    isMig17pf = blk.getBool("ilsMig17pf", false)
    isTcsfVe130 = blk.getBool("ilsTCSFVE130", false)
    isSu145 = blk.getBool("ilsSU145", false)
    isIls31 = blk.getBool("ils31", false)
    isIls28K = blk.getBool("ils28K", false)
    isMarconi = blk.getBool("ilsMarconiAvionics", false)
    isTornado = blk.getBool("ilsTornado", false)
    isElbit = blk.getBool("ilsElbit967", false)
    isASG23 = blk.getBool("ilsASG23", false)
    isF15a = blk.getBool("ilsF15a", false)
    isEP17 = blk.getBool("ilsEP17", false)
    isAmx = blk.getBool("ilsAmx", false)
    isVDO = blk.getBool("ilsKaiserVDO", false)
    isKai24p = blk.getBool("ilsKai24p", false)
    isF20 = blk.getBool("ilsF20", false)
    isChinaLang = blk.getBool("chinaLang", false)
    isMetric = blk.getBool("isMetricIls", false)
    isF15e = blk.getBool("ilsF15e", false)
    isF117 = blk.getBool("ilsF117", false)
    isSu34 = blk.getBool("ilsSu34", false)
    isTyphoon = blk.getBool("ilsTyphoon", false)
    isIlsRafale = blk.getBool("ilsRafale", false)
    isIlsF18 = blk.getBool("ilsF18", false)
    isIlsCth3022Su30 = blk.getBool("ilsCth3022Su30", false)
    isIlsF106 = blk.getBool("isIlsF106", false)
  })
}

let planeIls = @(width, height) function() {
  let { isAVQ7, haveAVQ7Bombing, haveAVQ7CCIP, isASP17, isBuccaneerIls,
    is410SUM1Ils, isSeaHarrierIls, isLCOSS, isASP23, haveJ7ERadar, isEP12, isEP08, isShimadzu, isIPP2_53,
    isTCSF196, isJ8HK, isKaiserA10, isF14, isMig17pf, isTcsfVe130, isSu145, isIls31,
    isMarconi, isTornado, isElbit, isIls28K, isASG23, isF15a, isEP17, isAmx, isVDO,
    isKai24p, isF20, isChinaLang, isMetric, isKaiserA10c, isF15e, isF117, isSu34, isTyphoon,
    isIlsRafale, isIlsF18, isIlsCth3022Su30, isIlsF106 } = ilsSetting.get()
  let isStockHeli = !(isASP17 || isAVQ7 || isBuccaneerIls || is410SUM1Ils || isSeaHarrierIls || isLCOSS ||
      isASP23 || isEP12 || isEP08 || isShimadzu || isIPP2_53 || isTCSF196 || isJ8HK ||
      isKaiserA10 || isF14 || isMig17pf || isTcsfVe130 || isSu145 || isIls31 || isMarconi ||
      isTornado || isElbit || isIls28K || isASG23 || isF15a || isEP17 || isAmx || isVDO || isKai24p ||
      isF20 || isKaiserA10c || isF15e || isF117 || isSu34 || isTyphoon || isIlsRafale || isIlsF18 || isIlsCth3022Su30 || isIlsF106)
  return {
    watch = ilsSetting
    children = [
      (isAVQ7 ? ilsAVQ7(width, height, haveAVQ7Bombing, haveAVQ7CCIP) : null),
      (isASP17 ? ASP17(width, height) : null),
      (isBuccaneerIls ? buccaneerHUD(width, height) : null),
      (is410SUM1Ils ? ilsSum410(width, height) : null),
      (isSeaHarrierIls ? ilsSeaHarrier(width, height) : null),
      (isLCOSS ? LCOSS(width, height, haveAVQ7Bombing) : null),
      (isASG23 ? ASG23(width, height) : null),
      (isASP23 || isIPP2_53 ? ASP23ModeSelector(width, height, isIPP2_53) : null),
      (haveJ7ERadar ? J7EAdditionalHud(width, height) : null),
      (isEP08 || isEP12 ? swedishEPIls(width, height, isEP08) : null),
      (isShimadzu ? ShimadzuIls(width, height) : null),
      (isTCSF196 ? TCSF196(width, height) : null),
      (isJ8HK ? J8IIHK(width, height) : null),
      (isKaiserA10 ? KaiserA10(width, height, false) : null),
      (isF14 ? F14(width, height) : null),
      (isMig17pf ? mig17(width, height) : null),
      (isTcsfVe130 ? TCSFVE130(width, height) : null),
      (isSu145 ? SU145(width, height) : null),
      (isIls31 ? Ils31(width, height, isChinaLang) : null),
      (isMarconi ? MarconiAvionics(width, height) : null),
      (isTornado ? Tornado(width, height) : null),
      (isElbit ? Elbit(width, height) : null),
      (isIls28K ? Ils28K(width, height) : null),
      (isF15a ? ilsF15a(width, height) : null),
      (isEP17 ? ilsEP17(width, height, isMetric) : null),
      (isAmx ? ilsAmx(width, height) : null),
      (isVDO ? KaiserVDO(width, height) : null),
      (isKai24p ? ilsKai24p(width, height) : null),
      (isF20 ? ilsF20(width, height) : null),
      (isKaiserA10c ? KaiserA10(width, height, true) : null),
      (isF15e ? ilsF15e(width, height) : null),
      (isF117 ? ilsF117(width, height) : null),
      (isSu34 ? ilsSu34(width, height) : null),
      (isTyphoon ? IlsTyphoon(width, height) : null),
      (isStockHeli ? StockHeliIls() : null),
      (isIlsRafale ? ilsRafale(width, height) : null),
      (isIlsF18 ? ilsF18(width, height) : null),
      (isIlsCth3022Su30 ? ilsCth3022Su30(width, height) : null),
      (isIlsF106 ? ilsF106(width, height) : null)
    ]
  }
}

let planeIlsSwitcher = @() {
  watch = [IlsVisible, ilsSetting]
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IlsVisible.get() ? [ planeIls(IlsPosSize[2], IlsPosSize[3])] : null
}

return {
  planeIlsSwitcher
  ilsSettingsUpd
}