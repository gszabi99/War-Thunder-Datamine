module gun_reload_common shared
require daslib/enum_trait



enum GunReloadState
  NONE
  LOOP_PREPARE
  LOOP_EMPTY_CHAMBER
  LOOP_BULLET_MULTIPLE
  LOOP_BULLET_SINGLE
  LOOP_POST

let GUN_RELOAD_STATE_NAMES = typeinfo enum_names(type<GunReloadState>)

bitfield GunReloadStateFlags
  None
  CanLoop
  CanInterrupt
