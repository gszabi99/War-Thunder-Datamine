module post_production_common shared
require ecs
require ecs.common
require ecs.soa_template


[soa_template]
struct PostProductionEntity
  replay_post_production__creationTime : float
  replay_post_production__template : string
  replay_post_production__transform : float3x4
  replay_post_production__isAutoDestroy : bool
