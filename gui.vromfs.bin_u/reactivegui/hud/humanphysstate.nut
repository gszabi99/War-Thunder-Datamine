from "%rGui/globals/ui_library.nut" import *

let { isHumanAiming, isHumanHoldBreathShowHint
} = require("%rGui/hud/state/human_phys_es.nut")
let { humanCurGunStaticInfo, humanCurGunInfo, humanCurGunModeInfo
} = require("%rGui/hud/state/human_gun_info_es.nut")
let { isBipodEnabled, isBipodAdsFocused } = require("%rGui/hud/state/human_bipod_es.nut")

let { canHoldBreath, canScopeChange, canSightChange, canBipodFocus
} = require("%appGlobals/hud/humanPhysState.nut")

let isWeaponHaveAmmo = Computed(@() humanCurGunStaticInfo.get()?.haveAmmo ?? false)
let isWeaponHasVariableScope = Computed(@()
  humanCurGunModeInfo.get()?.mods.scope.isVariableScope ?? false)
let isWeaponModHasSwitchableSights = Computed(@()
  humanCurGunModeInfo.get()?.activeModWeapon.hasSwitchableSights
  ?? humanCurGunInfo.get()?.hasSwitchableSights
  ?? false)

let isAdsActive = Computed(@()
  isBipodEnabled.get() ? isBipodAdsFocused.get() : isHumanAiming.get())

let showHoldBrief = keepref(Computed(@()
  isHumanHoldBreathShowHint.get()
  && (!isBipodEnabled.get() || isBipodAdsFocused.get())
))

let showScopeChange = keepref(Computed(@()
  isAdsActive.get()
  && isWeaponHasVariableScope.get()
  && isWeaponHaveAmmo.get()
))

let showSightChange = keepref(Computed(@()
  isAdsActive.get()
  && isWeaponModHasSwitchableSights.get()
  && ((humanCurGunModeInfo.get()?.activeModWeapon?.isModActive ?? false)
    || (humanCurGunInfo.get()?.hasSwitchableSights ?? false))
))

let showBipodFocus = keepref(Computed(@()
  isBipodEnabled.get() && !isBipodAdsFocused.get()))

showHoldBrief.subscribe(@(v) canHoldBreath.set(v) )
showScopeChange.subscribe(@(v) canScopeChange.set(v) )
showSightChange.subscribe(@(v) canSightChange.set(v) )
showBipodFocus.subscribe(@(v) canBipodFocus.set(v) )