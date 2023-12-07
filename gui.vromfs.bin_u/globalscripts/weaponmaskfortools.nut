//Need recalculate wpCost if change values of mask for exist weapons
enum WeaponMaskForTools {
  MACHINE_GUN_MASK      = 0x000001,
  CANNON_MASK           = 0x000002,
  GUNNER_MASK           = 0x000004,
  BOMB_MASK             = 0x000008,
  TORPEDO_MASK          = 0x000010,
  ROCKET_MASK           = 0x000020,
  ATGM_MASK             = 0x000040,
  AAM_MASK              = 0x000080,
  MINE_MASK             = 0x000100,
  GUIDED_BOMB_MASK      = 0x000200,
  ADDITIONAL_GUN_MASK   = 0x000400,

  ALL_BOMBS_MASK        = 0x000208,
  ALL_ROCKETS_MASK      = 0x0000E0
}

function validateWeaponMask() {
  let {WeaponMask} = require("wtSharedEnums")
  let {logerr} = require("dagor.debug")

  foreach (k, v in WeaponMask) {
    if (k not in WeaponMaskForTools || v != WeaponMaskForTools[k]) {
      logerr($"WeaponMask for tools differs from native WeaponMask: {k}")
      return false
    }

  }
  foreach (k, v in WeaponMaskForTools) {
    if (k not in WeaponMaskForTools || v != WeaponMaskForTools[k]) {
      logerr($"WeaponMaskForTools for tools differs from native WeaponMask: {k}")
      return false
    }
  }
  println("Success check for WeaponMask")
  return true
}

if (__name__ == "__main__")
  validateWeaponMask()

return {validateWeaponMask, WeaponMaskForTools}