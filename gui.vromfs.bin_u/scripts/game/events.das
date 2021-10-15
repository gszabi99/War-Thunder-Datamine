module events shared
require ecs
require dm

[cpp_event(unicast)]
struct EventOnStartShooting
  weaponIdx: int

[cpp_event(unicast)]
struct EventOnMetaPartDamage
  partId: PartId
  metapartNo: int
  damage: float
