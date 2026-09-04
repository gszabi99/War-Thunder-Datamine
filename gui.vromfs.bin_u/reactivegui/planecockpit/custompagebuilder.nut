import "%rGui/planeCockpit/instrumentsPage/ah64FltPage.nut" as ah64Flt
import "%rGui/planeCockpit/weaponPage/ah64WpnPage.nut" as ah64Wpn
import "%rGui/planeCockpit/targetingPage/mfdSu27Pod.nut" as su27Pod
import "%rGui/planeCockpit/weaponPage/ef2000WpnPage.nut" as ef2000Wpn
import "%rGui/planeCockpit/instrumentsPage/planeAttitude.nut" as planeAttitude
import "%rGui/planeCockpit/instrumentsPage/BaeHawkFltPage.nut" as BaeHawkFlt
import "%rGui/planeCockpit/instrumentsPage/mfdF16cAttitude.nut" as f16cAttitude
from "%rGui/utils/builders.nut" import createScriptComponentWithPos
from "%rGui/planeState/planeToolsState.nut" import CustomPages, CustomPagesBlk
from "%rGui/planeCockpit/weaponPage/f15cWpnPage.nut" import f15cWpn, f15jWpn
from "%rGui/utils/cacheDasScriptForView.nut" import getDasScriptByPath
from "%sqStdLibs/helpers/u.nut" import copy
from "dagor.math" import E3DCOLOR
from "dagor.debug" import logerr
from "%rGui/globals/ui_library.nut" import *

let fa18cRadarAzEl = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdfa18cRadarAzEl.das", {
  fontId = Fonts.hud
})
let rafaleWpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdRafaleWpn.das", { fontId = Fonts.hud })
let f18Wpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdF18Wpn.das", { fontId = Fonts.ah64 })
let su30smWpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdSu30smWpn.das", { fontId = Fonts.hud })
let f2aWpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdF2aWpn.das", { fontId = Fonts.hud })

let mi35acc = createScriptComponentWithPos("%rGui/planeCockpit/targetingPage/mfdMi35ACC.das", { fontId = Fonts.hud })

let mi35accEn = createScriptComponentWithPos("%rGui/planeCockpit/targetingPage/mfdMi35ACC.das", { fontId = Fonts.hud, english = true })
let f5ThWpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdF5ThWpn.das", { fontId = Fonts.hud})
let f5ThWpnDclt = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdF5ThWpn.das", { fontId = Fonts.hud, declutter = true })
let fa18Engine = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdFA18Engine.das", { fontId = Fonts.hud })
let europeanAviaHorizont = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdEuropeanHorizont.das", { fontId = Fonts.hud, isMetricUnits = false })
let mfdYak130Horizont = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/MfdYak130Horizont.das", { fontId = Fonts.ils31, fontSize = 16, horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask_2.avif") })
let mfdYak130Compass = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdYak130Compass.das", { fontId = Fonts.ils31, fontSize = 16 })
let mfdYak130Kab = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdYak130Kab.das", { fontId = Fonts.ils31, fontSize = 16 })
let f101Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/F101Radar.das", {
  fontId = Fonts.hud
})
let mfdMig21Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdMig21Radar.das", {
  fontId = Fonts.ussr_ils
})
let mfdF104Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdF104Radar.das", {
  fontId = Fonts.hud
})
let mfdF102Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdF102Radar.das", {
  fontId = Fonts.hud
})
let mfdSu15Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdSu15Radar.das", {
  fontId = Fonts.hud
})
let mfdF1Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdF1Radar.das", {
  fontId = Fonts.ils31
})
let mfdMirageF1Radar = createScriptComponentWithPos("%rGui/planeCockpit/radarPage/mfdMirageF1Radar.das", {
  fontId = Fonts.ils31
})
let mfdMig29additionalAH = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdMig29additionalAH.das", { fontId = Fonts.hud, fontSize = 14, horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif") })
let m346FaWpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdM346FaWpn.das", { fontId = Fonts.hud })
let yak130Wpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdYak130Wpn.das", {
  fontId = Fonts.hud
  stationFontId = Fonts.ils31
  aamPic = Picture($"!ui/gameuiskin#aam.svg")
  aamBgPic = Picture($"!ui/gameuiskin#aam_bg.svg")
  bombsPic = Picture($"!ui/gameuiskin#bombs.svg")
  bombsBgPic = Picture($"!ui/gameuiskin#bombs_bg.svg")
  rocketsPic = Picture($"!ui/gameuiskin#rockets.svg")
  rocketsBgPic = Picture($"!ui/gameuiskin#rockets_bg.svg")
  kabPic = Picture($"!ui/gameuiskin#kab.svg")
  kabBgPic = Picture($"!ui/gameuiskin#kab_bg.svg")
  ptbPic = Picture($"!ui/gameuiskin#ptb.svg")
  yakPic = Picture($"ui/gameuiskin#yak_130.svg:400:483")
})
let mfdOraoInstruments = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdOraoInstruments.das", { fontId = Fonts.hud })
let mfdOraoHorizonCompass = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdOraoHorizonCompass.das", { fontId = Fonts.hud, horMask = Picture($"!ui/gameuiskin#mfd_f4_agm65.avif") })
let mfdOraoEngineSmall = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdOraoEngineSmall.das", { fontId = Fonts.hud })
let z19Eng = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdZ19Eng.das", { fontId = Fonts.hud })
let z19Pfd = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdZ19Pfd.das", { fontId = Fonts.hud, horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif") })
let mfdMig29Horizont = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdMig29Horizont.das", {
  fontId = Fonts.ils31, fontSize = 16
})
let mfdSu35J16Horizon = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdSu35J16Horizon.das", {
  fontId = Fonts.ils31, fontSize = 14,
  altDevImage = Picture($"!ui/gameuiskin#mfd_altitude.avif"),
  spdDevImage = Picture($"!ui/gameuiskin#mfd_speed.avif"),
  varioDevImage = Picture($"!ui/gameuiskin#mfd_vario.avif"),
  horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
})
let mfdMigCompass = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdMigCompass.das", {
  fontId = Fonts.ils31, fontSize = 16
})
let mfdKa52Wpn = createScriptComponentWithPos("%rGui/planeCockpit/weaponPage/mfdKa52Wpn.das", {
  fontId = Fonts.ils31
})
function mfdKa52Compass(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/mfdKa52Compass.das")
    drawFunc = "render"
    setupFunc = "setup"
    fontId = Fonts.ils31
  }
}

function f5ThAviaHorizont(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/mfdF5thHorizont.das")
    drawFunc = "draw"
    setupFunc = "setup"
    horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
    font = Fonts.hud
  }
}

function f5ThEngine(pos, size) {
  return {
    pos
    size
    children = [
      {
        rendObj = ROBJ_DAS_CANVAS
        size = const [ph(75), ph(50)]
        script = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/mfdF5thHorizont.das")
        drawFunc = "draw_small"
        setupFunc = "setup"
        horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
        font = Fonts.hud
        fontSize = 16
      }
      {
        rendObj = ROBJ_DAS_CANVAS
        size = const [ph(75), ph(50)]
        pos = const [0, ph(50)]
        script = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/mfdF5thEngine.das")
        drawFunc = "draw"
        setupFunc = "setup"
        font = Fonts.hud
        fontSize = 16
        rpmTex = Picture($"!ui/gameuiskin#mfd_f_5th_rpm.avif")
        temperatureTex = Picture($"!ui/gameuiskin#mfd_f_5th_temperature.avif")
      }
    ]
  }
}

let mfdKa52Instruments = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdKa52Instruments.das",
 {
  fontId = Fonts.hud
  horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
})

let mi35flt = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdMi35FLT.das",
 {
  fontId = Fonts.hud
  horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask_circular.avif")
})
let mi35fltEn = createScriptComponentWithPos("%rGui/planeCockpit/instrumentsPage/mfdMi35FLT.das",
 {
  fontId = Fonts.hud
  horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask_circular.avif")
  english = true
})

function su30Devices(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/mfdSu30devices.das")
    drawFunc = "draw"
    setupFunc = "setup"
    altDevImage = Picture($"!ui/gameuiskin#mfd_altitude.avif")
    spdDevImage = Picture($"!ui/gameuiskin#mfd_speed.avif")
    varioDevImage = Picture($"!ui/gameuiskin#mfd_vario.avif")
    horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
  }
}

function su30RadarElevation(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = getDasScriptByPath("%rGui/planeCockpit/radarPage/mfdSu30Radar.das")
    drawFunc = "draw_radar_hud"
    setupFunc = "setup_radar_data"
    color = Color(10, 202, 10, 250)
    isElevationMode = true
    font = Fonts.hud
  }
}



function yellow(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 255, 0)
  }
}

function red(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(255, 0, 0)
  }
}

function blue(pos, size) {
  return {
    rendObj = ROBJ_SOLID
    pos = pos
    size = size
    color = Color(0, 0, 255)
  }
}

function hsiPage(pos, size) {
  return {
    pos
    size
    rendObj   = ROBJ_DAS_CANVAS
    script    = getDasScriptByPath("%rGui/planeCockpit/instrumentsPage/hsi.das")
    drawFunc  = "render"
    setupFunc = "setup"
    lineColor = E3DCOLOR(0xFFFFFFFF)
    fontId    = Fonts.hud
    fontSize  = 14
    lineWidth = 1.5
  }
}

let pageByName = {
  yellow,
  red,
  blue,
  ah64Flt,
  ah64Wpn,
  f15cWpn,
  su27Pod,
  f15jWpn,
  ef2000Wpn,
  rafaleWpn,
  fa18cRadarAzEl,
  su30Devices,
  f18Wpn,
  su30smWpn,
  su30RadarElevation,
  planeAttitude,
  f2aWpn,
  mi35acc,
  mi35flt,
  mfdKa52Instruments,
  mi35accEn,
  mi35fltEn,
  f5ThWpn,
  f5ThWpnDclt,
  f5ThAviaHorizont,
  f5ThEngine,
  BaeHawkFlt,
  fa18Engine,
  europeanAviaHorizont,
  mfdMig29additionalAH,
  m346FaWpn,
  yak130Wpn,
  mfdYak130Horizont,
  mfdYak130Compass,
  mfdYak130Kab,
  f101Radar,
  mfdMig21Radar,
  mfdF104Radar,
  mfdF102Radar,
  mfdSu15Radar,
  mfdF1Radar,
  mfdMirageF1Radar,
  hsiPage,
  f16cAttitude,
  mfdOraoInstruments,
  mfdOraoHorizonCompass,
  mfdOraoEngineSmall,
  z19Eng,
  z19Pfd,
  mfdMig29Horizont,
  mfdSu35J16Horizon,
  mfdMigCompass,
  mfdKa52Compass,
  mfdKa52Wpn,
}

function customPageSettingsUpd(page_blk) {
  let pageName = page_blk?.pageName ?? ""
  if (pageName != "") {
    CustomPagesBlk.mutate(@(v) v[pageName] <- copy(page_blk))
  }
}

function mfdCustomPages() {
  let pages = []

  foreach (name, pos in CustomPages.get()) {
    if (name != null && pageByName?[name] != null) {
      let page = pageByName[name]([pos.x, pos.y], [pos.z, pos.w])
      if (name in CustomPagesBlk.get())
        page.blk <- CustomPagesBlk.get()[name]
      pages.append(page)
    }
    else
      logerr($"MFD custom page not found: {name}")
  }
  return {
    watch = [CustomPages, CustomPagesBlk]
    size = FLEX
    children = pages
  }
}

return { mfdCustomPages, customPageSettingsUpd }