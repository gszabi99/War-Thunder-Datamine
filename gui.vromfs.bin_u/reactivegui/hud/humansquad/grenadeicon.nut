from "%rGui/style/colors.nut" import commonIconColor
from "%rGui/globals/ui_library.nut" import *

let GRENADES_ORDER = {
  antitank = 0
  tnt_block = 1
  flash = 2
  impact = 3
  incendiary = 4
  fougasse = 5
  flame = 6
  smoke = 7
  flare = 8
  wall_bomb = 99
}

let grenadeIconNames = {
  antitank = "grenade_antitank.svg"
  fougasse = "grenade_fougasse.svg"
  impact = "grenade_impact.svg"
  incendiary = "grenade_incendiary.svg"
  flame = "grenade_flame.svg"
  tnt_block = "grenade_tnt_block.svg"
  smoke = "grenade_smoke.svg"
  flare = "grenade_flare.svg"
  flash = "grenade_flash.svg"
  wall_bomb = "grenade_antitank.svg"
}

let grenadeIconName = @(gType, size) "ui/gameuiskin#{0}:{1}:{1}:P"
  .subst(grenadeIconNames?[gType] ?? grenadeIconNames.fougasse, size)

let mkGrenadeIcon = @(grenadeType, size, getPicture, color = commonIconColor) grenadeType == null ? null
  : {
      rendObj = ROBJ_IMAGE
      size = size
      image = getPicture(grenadeIconName(grenadeType, size))
      color
    }

let getGrenadeType = @[pure, nodiscard](grenades)
  grenades.reduce(@(a, b)
    (GRENADES_ORDER?[a] ?? 0) <= (GRENADES_ORDER?[b] ?? 0) ? a : b)

return freeze({
  grenadeIconName
  mkGrenadeIcon
  getGrenadeType
})