from "%rGui/globals/ui_library.nut" import *
let { commonIconColor } = require("%rGui/style/colors.nut")

let mineIconNames = {
  antitank_mine = "mine_antitank.svg"
  antipersonnel_mine = "mine_antipersonnel.svg"
  tnt_exploder = "grenade_tnt_block.svg"
}

let mineIcon = @(gType, size) Picture("ui/gameuiskin#{0}:{1}:{2}:P"
  .subst(mineIconNames?[gType] ?? mineIconNames.antitank_mine, size, size))

let mkMineIcon = @(mineType, size, color = commonIconColor) mineType == null ? null
  : {
      rendObj = ROBJ_IMAGE
      size = [size, size]
      image = mineIcon(mineType, size)
      tint = color
    }

return {
  mineIcon
  mkMineIcon
}
