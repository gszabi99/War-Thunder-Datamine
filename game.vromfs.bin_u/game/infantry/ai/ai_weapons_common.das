module ai_weapons_common shared
require daslib/enum_trait

require ecs

enum SpecialAIWeaponType
  NON_SPECIAL = 0
  ROCKET_LAUNCHERS = 1
  PISTOLS = 2
  ANTI_TANK_RIFLES = 3
  FLAME_THROWERS = 4
  ATGM_MPADS_LAUNCHERS = 5

let SPECIAL_AI_WEAPON_TYPE_NAMES = typeinfo enum_names(type<SpecialAIWeaponType>)


def check_ai_gun_has_min_ammo(gun_eid : EntityId; min_ammo : int)
  var availableAmmo = 0
  query(gun_eid) <| $ [es] (gun__totalAmmo : int = 0; gun__ammo : int = 0)
    availableAmmo = gun__totalAmmo + gun__ammo
  return availableAmmo >= min_ammo

def check_ai_gun_has_spec_ai_type(gun_eid : EntityId; spec_ai_type : int)
  var result = false
  query(gun_eid) <| $ [es] (specialAIWeaponType : int = 0)
    if specialAIWeaponType == spec_ai_type
      result = true
  return result
