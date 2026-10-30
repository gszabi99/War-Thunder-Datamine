from "%rGui/style/colors.nut" import commonIconColor
from "%rGui/globals/ui_library.nut" import *

let mineIconNames = {
  antitank_mine = "mine_antitank.svg"
  antipersonnel_mine = "mine_antipersonnel.svg"
  tnt_exploder = "grenade_tnt_block.svg"
}

let mineIconName = @(gType, size) "ui/gameuiskin#{0}:{1}:{2}:P"
  .subst(mineIconNames?[gType] ?? mineIconNames.antitank_mine, size, size)

let mineIcon = @(gType, size) Picture(mineIconName(gType, size))

let mkMineIcon = @(mineType, size, getPicture, color = commonIconColor) mineType == null ? null
  : {
      rendObj = ROBJ_IMAGE
      size = size
      image = getPicture(mineIconName(mineType, size))
      tint = color
    }

return freeze({
  mineIcon
  mkMineIcon
})
