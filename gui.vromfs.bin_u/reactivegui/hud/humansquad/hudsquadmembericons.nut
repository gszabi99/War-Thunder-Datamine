from "%rGui/hud/humanSquad/mineIcon.nut" import mkMineIcon
from "%rGui/style/colors.nut" import deadIconColor
from "%rGui/globals/ui_library.nut" import *

let mkMineIconByMember = @(member, size, getPicture, color = null) member.isAlive && member.mineType != null
  ? mkMineIcon(member.mineType, size, getPicture, color)
  : null

let deaths = @(iconSize, getPicture) freeze({
  rendObj = ROBJ_IMAGE
  size = iconSize
  vplace = ALIGN_CENTER
  hplace = ALIGN_CENTER
  color = deadIconColor
  image = getPicture($"ui/gameuiskin#nockdown.svg:{iconSize}:{iconSize}:P")
})

let mkStatusIcon = @(member, iconSize, getPicture) {
  size = FLEX
  children = member.isAlive
    ? null
    : deaths(iconSize, getPicture)
}


return freeze({
  mkMineIcon = mkMineIconByMember
  mkStatusIcon
})