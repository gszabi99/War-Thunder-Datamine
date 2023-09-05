from "%rGui/globals/ui_library.nut" import *

let { IlsVisible, IlsPosSize, CannonMode, RocketMode, BombCCIPMode,
        BlkFileName, BombingMode } = require("planeState/planeToolsState.nut")
let DataBlock = require("DataBlock")
let { TrackerVisible } = require("rocketAamAimState.nut")
let { compassWrap, generateCompassMark } = require("planeIlses/ilsCompasses.nut")

let { AVQ7Basic, AVQ7BombingMode, AVQ7CCIPMode } = require("planeIlses/ilsAVQ7.nut")
let ASP17 = require("planeIlses/ilsASP17.nut")
let buccaneerHUD = require("planeIlses/ilsBuccaneer.nut")
let { basic410SUM, SUMCCIPMode, SumAAMMode, SumBombingSight, SUMGunReticle } = require("planeIlses/ils410Sum.nut")
let LCOSS = require("planeIlses/ilsLcoss.nut")
let { J7EAdditionalHud, ASP23ModeSelector } = require("planeIlses/ilsASP23.nut")
let swedishEPIls = require("planeIlses/ilsEP.nut")
let ShimadzuIls = require("planeIlses/ilsShimadzu.nut")
let TCSF196 = require("planeIlses/ilsTcsf196.nut")
let J8IIHK = require("planeIlses/ilsJ8IIhk.nut")
let KaiserA10 = require("planeIlses/ilsKaiserA10.nut")
let F14 = require("planeIlses/ilsF14Tomcat.nut")
let mig17 = require("planeIlses/ilsMig17pf.nut")
let TCSFVE130 = require("planeIlses/ilsTcsfVE130.nut")
let SU145 = require("planeIlses/ilsSu145.nut")
let Ils31 = require("planeIlses/ils31.nut")
let MarconiAvionics = require("planeIlses/ilsMarconiAvionics.nut")
let Tornado = require("planeIlses/ilsTornado.nut")
let Elbit = require("planeIlses/ilsElbit967.nut")
let StockHeliIls = require("heliIls.nut")
let Ils28K = require("planeIlses/ils28k.nut")

let ilsSetting = Computed(function() {
  let res = {
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
    isF14 = false
    isMig17pf = false
    isTcsfVe130 = false
    isSu145 = false
    isIls31 = false
    isIls28K = false
    isMarconi = false
    isTornado = false
    isElbit = false
    hasPointDesignator = false
  }
  if (BlkFileName.value == "")
    return res
  let blk = DataBlock()
  let fileName = $"gameData/flightModels/{BlkFileName.value}.blk"
  if (!blk.tryLoad(fileName))
    return res
  return {
    isASP17 = blk.getBool("ilsASP17", false)
    isAVQ7 = blk.getBool("ilsAVQ7", false)
    haveAVQ7CCIP = blk.getBool("ilsHaveAVQ7CCIP", false)
    haveAVQ7Bombing = blk.getBool("ilsHaveAVQ7CCRP", false)
    isBuccaneerIls = blk.getBool("isBuccaneerIls", false)
    is410SUM1Ils = blk.getBool("is410SUM1Ils", false)
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
    isF14 = blk.getBool("ilsF14", false)
    isMig17pf = blk.getBool("ilsMig17pf", false)
    isTcsfVe130 = blk.getBool("ilsTCSFVE130", false)
    isSu145 = blk.getBool("ilsSU145", false)
    isIls31 = blk.getBool("ils31", false)
    isIls28K = blk.getBool("ils28K", false)
    isMarconi = blk.getBool("ilsMarconiAvionics", false)
    isTornado = blk.getBool("ilsTornado", false)
    isElbit = blk.getBool("ilsElbit967", false)
    hasPointDesignator = blk.getBool("havePointOfInterestDesignator", false)
  }
})

let CCIPMode = Computed(@() RocketMode.value || CannonMode.value || BombCCIPMode.value)

let planeIls = @(width, height) function() {

  let { isAVQ7, haveAVQ7Bombing, haveAVQ7CCIP, isASP17, isBuccaneerIls,
    is410SUM1Ils, isLCOSS, isASP23, haveJ7ERadar, isEP12, isEP08, isShimadzu, isIPP2_53,
    isTCSF196, isJ8HK, isKaiserA10, isF14, isMig17pf, isTcsfVe130, isSu145, isIls31,
    isMarconi, isTornado, isElbit, isIls28K, hasPointDesignator } = ilsSetting.value
  let isStockHeli = !(isASP17 || isAVQ7 || isBuccaneerIls || is410SUM1Ils || isLCOSS ||
      isASP23 || isEP12 || isEP08 || isShimadzu || isIPP2_53 || isTCSF196 || isJ8HK ||
      isKaiserA10 || isF14 || isMig17pf || isTcsfVe130 || isSu145 || isIls31 || isMarconi ||
      isTornado || isElbit || isIls28K)
  return {
    watch = [BombingMode, CCIPMode, TrackerVisible, ilsSetting]
    children = [
      (isAVQ7 ? AVQ7Basic(width, height) : null),
      (haveAVQ7Bombing && BombingMode.value ? AVQ7BombingMode(width, height) : null),
      (haveAVQ7CCIP && CCIPMode.value ? AVQ7CCIPMode(width, height) : null),
      (isAVQ7 && (!BombingMode.value || !haveAVQ7Bombing) &&
       (!CCIPMode.value || !haveAVQ7CCIP) ? compassWrap(width, height, 0.1, generateCompassMark) : null),
      (isASP17 ? ASP17(width, height, hasPointDesignator) : null),
      (isBuccaneerIls ? buccaneerHUD(width, height) : null),
      (is410SUM1Ils ? basic410SUM(width, height) : null),
      (is410SUM1Ils && CCIPMode.value ? SUMCCIPMode(width, height) : null),
      (is410SUM1Ils && TrackerVisible.value ? SumAAMMode(width, height) : null),
      (is410SUM1Ils && BombingMode.value ? SumBombingSight(width, height) : null),
      (is410SUM1Ils && !BombingMode.value && !CCIPMode.value ? SUMGunReticle(width, height) : null),
      (isLCOSS ? LCOSS(width, height) : null),
      (isASP23 || isIPP2_53 ? ASP23ModeSelector(width, height, isIPP2_53) : null),
      (haveJ7ERadar && (!BombingMode.value || !haveAVQ7Bombing) &&
       (!CCIPMode.value || !haveAVQ7CCIP) ? J7EAdditionalHud(width, height) : null),
      (isEP08 || isEP12 ? swedishEPIls(width, height, isEP08) : null),
      (isShimadzu ? ShimadzuIls(width, height) : null),
      (isTCSF196 ? TCSF196(width, height) : null),
      (isJ8HK ? J8IIHK(width, height) : null),
      (isKaiserA10 ? KaiserA10(width, height) : null),
      (isF14 ? F14(width, height) : null),
      (isMig17pf ? mig17(width, height) : null),
      (isTcsfVe130 ? TCSFVE130(width, height) : null),
      (isSu145 ? SU145(width, height) : null),
      (isIls31 ? Ils31(width, height) : null),
      (isMarconi ? MarconiAvionics(width, height) : null),
      (isTornado ? Tornado(width, height) : null),
      (isElbit ? Elbit(width, height) : null),
      (isIls28K ? Ils28K(width, height) : null),
      (isStockHeli ? StockHeliIls() : null)
    ]
  }
}

let planeIlsSwitcher = @() {
  watch = IlsVisible
  halign = ALIGN_LEFT
  valign = ALIGN_TOP
  size = SIZE_TO_CONTENT
  children = IlsVisible.value ? [ planeIls(IlsPosSize[2], IlsPosSize[3])] : null
}

return planeIlsSwitcher