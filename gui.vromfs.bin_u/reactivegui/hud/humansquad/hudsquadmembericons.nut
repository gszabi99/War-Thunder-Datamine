from "%rGui/hud/humanSquad/mineIcon.nut" import mkMineIcon
from "%rGui/style/colors.nut" import deadIconColor
from "%rGui/globals/ui_library.nut" import *

let mkMineIconByMember = @(member, size, color = null) member.isAlive && member.mineType != null
  ? mkMineIcon(member.mineType, size, color)
  : null

let deaths = @(iconSize) freeze({
  rendObj = ROBJ_IMAGE
  size = [iconSize, iconSize]
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  color = deadIconColor
  image = Picture($"ui/gameuiskin#nockdown.svg:{iconSize}:{iconSize}:P")
})

let mkStatusIcon = @(member, iconSize) {
  size = FLEX
  children = member.isAlive
    ? null
    : deaths(iconSize)
}


return {
  mkMineIcon = mkMineIconByMember
  mkStatusIcon
}