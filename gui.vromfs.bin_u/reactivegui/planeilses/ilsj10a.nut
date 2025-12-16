from "%rGui/globals/ui_library.nut" import *
let { getDasScriptByPath } = require("%rGui/utils/cacheDasScriptForView.nut")
let { getLangId } = require("dagor.localize")

let ilsJ10aBase = {
  rendObj = ROBJ_DAS_CANVAS
  script = getDasScriptByPath("%rGui/planeIlses/ilsJ10a.das")
  drawFunc = "render"
  setupFunc = "setup"
  fontId = Fonts.hud
  isMetricUnits = true
}

function ilsJ10a(width, height) {
  return ilsJ10aBase.__merge({
    size = [width, height]
    ilsFovDegX = 14.5
    ilsFovDegY = 14.5
    langId = getLangId("English")
  })
}

function ilsJ10c(width, height) {
  return ilsJ10aBase.__merge({
    size = [width, height]
    ilsFovDegX = 21.05
    ilsFovDegY = 21.05
    langId = getLangId("English")
  })
}

function ilsJf17(width, height) {
  return ilsJ10aBase.__merge({
    size = [width, height]
    ilsFovDegX = 15.6
    ilsFovDegY = 15.6
    langId = getLangId("English")
  })
}

return {
  ilsJ10a,
  ilsJ10c,
  ilsJf17
}
