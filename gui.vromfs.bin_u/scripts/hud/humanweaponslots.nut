enum WeaponSlots {
  EWS_PRIMARY 
  EWS_SECONDARY
  EWS_TERTIARY
  EWS_MELEE

  EWS_NUM
}

let weaponSlotsKeys = {
  [WeaponSlots.EWS_PRIMARY] = "primary",
  [WeaponSlots.EWS_SECONDARY] = "secondary",
  [WeaponSlots.EWS_TERTIARY] = "tertiary",
  [WeaponSlots.EWS_MELEE] = "melee",

}

return freeze({
  EWS_PRIMARY = WeaponSlots.EWS_PRIMARY
  EWS_SECONDARY = WeaponSlots.EWS_SECONDARY
  EWS_TERTIARY = WeaponSlots.EWS_TERTIARY
  EWS_MELEE = WeaponSlots.EWS_MELEE

  weaponSlotsKeys
})