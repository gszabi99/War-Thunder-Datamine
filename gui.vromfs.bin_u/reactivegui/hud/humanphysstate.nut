from "%rGui/hud/state/human_phys_es.nut" import isHumanAiming, isHumanHoldBreathShowHint
from "%rGui/hud/state/human_gun_info_es.nut" import humanCurGunStaticInfo, humanCurGunInfo, humanCurGunModeInfo
from "%rGui/hud/state/human_bipod_es.nut" import isBipodEnabled, isBipodAdsFocused
from "%appGlobals/hud/humanPhysState.nut" import canHoldBreath, canScopeChange, canSightChange, canBipodFocus
from "%rGui/globals/ui_library.nut" import *

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