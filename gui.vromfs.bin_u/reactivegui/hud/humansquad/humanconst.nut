from "%rGui/globals/ui_library.nut" import *

let healthBlockWidth = shHud(5)
let heroStateWidth = shHud(18)
let actionBarItemHeight = shHud(10)
let actionBarItemWidth = shHud(9)
let weaponBlockGap = shHud(1)
let healthStateBlockGap = shHud(1.5)

const humanBarInnerPadding = [ evenPx(3), evenPx(3) ]

return {
  healthBlockWidth
  heroStateWidth
  humanBarInnerPadding
  actionBarItemHeight
  actionBarItemWidth
  weaponBlockGap
  healthStateBlockGap
}