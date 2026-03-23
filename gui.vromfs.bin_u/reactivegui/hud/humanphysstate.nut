from "%rGui/globals/ui_library.nut" import *

let { isHumanAiming, isHumanHoldBreathShowHint
} = require("%rGui/hud/state/human_phys_es.nut")
let { humanCurGunStaticInfo, humanCurGunInfo, humanCurGunModeInfo
} = require("%rGui/hud/state/human_gun_info_es.nut")

let { canHoldBreath, canScopeChange, canSightChange } = require("%appGlobals/hud/humanPhysState.nut")

let isWeaponHaveAmmo = Computed(@() humanCurGunStaticInfo.get()?.haveAmmo ?? false)
let isWeaponHasVariableScope = Computed(@()
  humanCurGunModeInfo.get()?.mods.scope?.isVariableScope ?? false)
let isWeaponModHasSwitchableSights = Computed(@()
  humanCurGunModeInfo.get()?.modWeapon?.hasSwitchableSights
  ?? humanCurGunInfo.get()?.hasSwitchableSights
  ?? false)

let showHoldBrief = keepref(Computed(@() isHumanHoldBreathShowHint.get()))

let showScopeChange = keepref(Computed(@()
  isHumanAiming.get()
  && isWeaponHasVariableScope.get()
  && isWeaponHaveAmmo.get()
))

let showSightChange = keepref(Computed(@()
  isHumanAiming.get()
  && isWeaponModHasSwitchableSights.get()
  && ((humanCurGunModeInfo.get()?.modWeapon?.isModActive ?? false)
    || (humanCurGunInfo.get()?.hasSwitchableSights ?? false))
))

showHoldBrief.subscribe(@(v) canHoldBreath.set(v) )
showScopeChange.subscribe(@(v) canScopeChange.set(v) )
showSightChange.subscribe(@(v) canSightChange.set(v) )