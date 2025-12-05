from "%rGui/globals/ui_library.nut" import *

let { isHumanAiming, isHumanHoldBreathShowHint
} = require("%rGui/hud/state/human_phys_es.nut")
let { humanCurGunStaticInfo, humanCurGunModeInfo
} = require("%rGui/hud/state/human_gun_info_es.nut")

let { canHoldBreath, canScopeChange } = require("%appGlobals/hud/humanPhysState.nut")

let isWeaponHaveAmmo = Computed(@() humanCurGunStaticInfo.get()?.haveAmmo ?? false)
let isWeaponHasVariableScope = Computed(@()
  humanCurGunModeInfo.get()?.mods.scope?.isVariableScope ?? false)

let showHoldBrief = keepref(Computed(@() isHumanHoldBreathShowHint.get()))

let showScopeChange = keepref(Computed(@()
  isHumanAiming.get()
  && isWeaponHasVariableScope.get()
  && isWeaponHaveAmmo.get()
))

showHoldBrief.subscribe(@(v) canHoldBreath.set(v) )
showScopeChange.subscribe(@(v) canScopeChange.set(v) )