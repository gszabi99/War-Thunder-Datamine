options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require soundEvent


[req_template]
struct HumanMeleeImpactSound
  human_melee_impact_sound__path : string
  human_weap__gunEids : EidList
  human_weap__currentGunSlot : int
