options no_aot
require ecs
require ecs.verify_common
require ecs.verify_macro


[es(tag=server, on_event=VerifyEcsTemplates)]
def human_sounds_net_verify_ecs_templates(evt : Event)
  req_template({
    "human_collision_scrape_net_sound__physmatNames" => ecs_type_hash(type<SharedStringList>),
    "human_collision_scrape_net_sound__physmatIds" => ecs_type_hash(type<IntList>),
    "human_net_phys__torsoContactMatId" => ecs_type_hash(type<int>),
    "human_collision_scrape_sound__descIdx" => ecs_type_hash(type<int>)
  })
