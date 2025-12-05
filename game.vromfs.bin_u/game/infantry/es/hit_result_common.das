module hit_result_common shared
require ecs.enum_macro

[export_enum]
enum HitResult : int
  HIT_RES_NONE
  HIT_RES_NORMAL
  HIT_RES_DOWNED
  HIT_RES_KILLED
