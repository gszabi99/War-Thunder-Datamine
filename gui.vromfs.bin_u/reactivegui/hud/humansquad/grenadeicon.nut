from "%rGui/globals/ui_library.nut" import *
let { commonIconColor } = require("%rGui/style/colors.nut")

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

let grenadeColoredIconNames = {
  fougasse = "frag_grenade.avif"
  smoke = "smoke_grenade.avif"
  stun = "stun_grenade.avif"
}

let grenadeIcon = @(gType, size) Picture("ui/gameuiskin#{0}:{1}:{1}:P"
  .subst(grenadeIconNames?[gType] ?? grenadeIconNames.fougasse, size))

let grenadeIconColored = @(gType, size) Picture("ui/gameuiskin#{0}:{1}:{1}:P"
  .subst(grenadeColoredIconNames?[gType] ?? grenadeColoredIconNames.fougasse, size))

let mkGrenadeIcon = @(grenadeType, size, color = commonIconColor) grenadeType == null ? null
  : {
      rendObj = ROBJ_IMAGE
      size = [size, size]
      image = grenadeIcon(grenadeType, size)
      color
    }

let getGrenadeType = @(grenades)
  grenades.reduce(@(a, b)
    (GRENADES_ORDER?[a] ?? 0) <= (GRENADES_ORDER?[b] ?? 0) ? a : b)

return {
  grenadeIcon
  grenadeIconColored
  mkGrenadeIcon
  getGrenadeType
}