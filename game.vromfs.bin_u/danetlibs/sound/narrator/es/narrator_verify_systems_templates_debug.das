options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro
require soundEvent

[req_template]
struct Narrator
  narrator__event : SoundEvent
  narrator__queue : ecs::Array
  narrator__history : ecs::Object
