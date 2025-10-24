from "%rGui/globals/ui_library.nut" import *

let { createScriptComponentWithPos } = require("%rGui/utils/builders.nut")
let { CustomPages, CustomPagesBlk } = require("%rGui/planeState/planeToolsState.nut")
let ah64Flt = require("%rGui/planeCockpit/ah64FltPage.nut")
let ah64Wpn = require("%rGui/planeCockpit/ah64WpnPage.nut")
let {f15cWpn, f15jWpn} = require("%rGui/planeCockpit/f15cWpnPage.nut")
let su27Pod = require("%rGui/planeCockpit/mfdSu27Pod.nut")
let ef2000Wpn = require("%rGui/planeCockpit/ef2000WpnPage.nut")
let planeAttitude = require("%rGui/planeCockpit/planeAttitude.nut")
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")
let { copy } = require("%sqStdLibs/helpers/u.nut")
let { logerr } = require("dagor.debug")
let BaeHawkFlt = require("%rGui/planeCockpit/BaeHawkFltPage.nut")

let fa18cRadarAzEl = createScriptComponentWithPos("%rGui/planeCockpit/mfdfa18cRadarAzEl.das", {
  fontId = Fonts.hud
})
let rafaleWpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdRafaleWpn.das", { fontId = Fonts.hud })
let f18Wpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdF18Wpn.das", { fontId = Fonts.ah64 })
let su30smWpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdSu30smWpn.das", { fontId = Fonts.hud })
let f2aWpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdF2aWpn.das", { fontId = Fonts.hud })

let mi35acc = createScriptComponentWithPos("%rGui/planeCockpit/mfdMi35ACC.das", { fontId = Fonts.hud })

let mi35accEn = createScriptComponentWithPos("%rGui/planeCockpit/mfdMi35ACC.das", { fontId = Fonts.hud, english = true })
let f5ThWpn = createScriptComponentWithPos("%rGui/planeCockpit/mfdF5ThWpn.das", { fontId = Fonts.hud})
let f5ThWpnDclt = createScriptComponentWithPos("%rGui/planeCockpit/mfdF5ThWpn.das", { fontId = Fonts.hud, declutter = true })

function f5ThAviaHorizont(pos, size) {
  return {
    rendObj = ROBJ_DAS_CANVAS
    pos
    size
    script = getDasScriptByPath("%rGui/planeCockpit/mfdF5thHorizont.das")
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
        size = [ph(75), ph(50)]
        script = getDasScriptByPath("%rGui/planeCockpit/mfdF5thHorizont.das")
        drawFunc = "draw_small"
        setupFunc = "setup"
        horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask.avif")
        font = Fonts.hud
        fontSize = 16
      }
      {
        rendObj = ROBJ_DAS_CANVAS
        size = [ph(75), ph(50)]
        pos = [0, ph(50)]
        script = getDasScriptByPath("%rGui/planeCockpit/mfdF5thEngine.das")
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

let mi35flt = createScriptComponentWithPos("%rGui/planeCockpit/mfdMi35FLT.das",
 {
  fontId = Fonts.hud
  horMask = Picture($"!ui/gameuiskin#mfd_horizont_mask_circular.avif")
})
let mi35fltEn = createScriptComponentWithPos("%rGui/planeCockpit/mfdMi35FLT.das",
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
    script = getDasScriptByPath("%rGui/planeCockpit/mfdSu30devices.das")
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
    script = getDasScriptByPath("%rGui/planeCockpit/mfdSu30Radar.das")
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
  mi35accEn,
  mi35fltEn,
  f5ThWpn,
  f5ThWpnDclt,
  f5ThAviaHorizont,
  f5ThEngine,
  BaeHawkFlt
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
    size = flex()
    children = pages
  }
}

return { mfdCustomPages, customPageSettingsUpd }