from "%rGui/globals/ui_library.nut" import *

let { scope } = require("%rGui/planeRwrs/rwrL150.nut")

let migBarColor = Color(0, 50, 200, 255)
let migWhite = Color(255, 255, 255, 255)

const MIG_BAR_THICK   = 6.0
const MIG_FRAME_SCALE = 190.0
const MIG_FRAME_OFS   = 0.0
const MIG_SIDE_OFS    = 67.0
const MIG_SCOPE_SCALE = 0.828
const MIG_LABELS_Y    = 25.0
let MIG_LABELS_X = [-33.0, -22.0, -11.0, 0.0, 11.0, 22.0]

function createMigFrame(displaySize, fontScale) {
  let dw = displaySize[0]
  let dh = displaySize[1]
  let fw = (MIG_FRAME_SCALE * 0.01 * dw).tointeger()
  let fh = (MIG_FRAME_SCALE * 0.01 * dh).tointeger()
  let ofs = (MIG_FRAME_OFS * 0.01 * dw).tointeger()
  let barH = (MIG_BAR_THICK * 0.01 * fh).tointeger()
  let barW = (MIG_BAR_THICK * 0.01 * dw).tointeger()
  return {
    size = [fw, fh]
    pos = [ofs, ofs]
    hplace = ALIGN_CENTER
    vplace = ALIGN_CENTER
    children = [
      {
        size = [fw, barH]
        rendObj = ROBJ_SOLID
        color = migBarColor
        halign = ALIGN_CENTER
        valign = ALIGN_CENTER
        children = ["ПИЛ", "ТО", "РЭП", "ОПС", "СИСТ", "ИЛС"].map(@(text, i) {
          rendObj = ROBJ_TEXT
          text
          font = Fonts.hud
          fontSize = (fontScale * 14).tointeger()
          color = migWhite
          hplace = ALIGN_CENTER
          vplace = ALIGN_CENTER
          pos = [pw(MIG_LABELS_X[i]), ph(MIG_LABELS_Y)]
        })
      }
      {
        size = [fw, barH]
        rendObj = ROBJ_SOLID
        color = migBarColor
        vplace = ALIGN_BOTTOM
      }
      {
        size = [barW, fh]
        pos = [(fw * 0.5 - MIG_SIDE_OFS * 0.01 * dw - barW).tointeger(), 0]
        rendObj = ROBJ_SOLID
        color = migBarColor
      }
      {
        size = [barW, fh]
        pos = [(fw * 0.5 + MIG_SIDE_OFS * 0.01 * dw).tointeger(), 0]
        rendObj = ROBJ_SOLID
        color = migBarColor
      }
    ]
  }
}

function tws(posWatched, sizeWatched, scale, style) {
  let fontScale = style?.grid.fontScale ?? 1.0
  return @() {
    watch = [posWatched, sizeWatched]
    size = sizeWatched.get()
    pos = posWatched.get()
    halign = ALIGN_CENTER
    valign = ALIGN_CENTER
    children = [
      scope(sizeWatched.get(), scale * MIG_SCOPE_SCALE, style)
      createMigFrame(sizeWatched.get(), fontScale)
    ]
  }
}

return tws
