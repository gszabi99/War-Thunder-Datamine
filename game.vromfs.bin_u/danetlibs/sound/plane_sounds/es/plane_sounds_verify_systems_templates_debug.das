options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require DngPlane
require soundEvent


[req_template]
struct PlaneSoundsRequiredComponents
  plane_net_phys : PlaneActor
  transform : float3x4
  isAlive : bool
  sound_control__state : int
