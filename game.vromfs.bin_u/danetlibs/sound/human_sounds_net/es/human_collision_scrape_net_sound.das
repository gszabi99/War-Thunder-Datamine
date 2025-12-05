require ecs
require ecs.common
require PhysMat


[es(tag=server, on_appear)]
def human_collision_scrape_net_sound_appear(evt : Event;
                                            @shared_comp human_collision_scrape_net_sound__physmatNames : StringList;
                                            var human_collision_scrape_net_sound__physmatIds : IntList&)
  human_collision_scrape_net_sound__physmatIds |> resize(length(human_collision_scrape_net_sound__physmatNames))
  for idx, name in human_collision_scrape_net_sound__physmatIds, human_collision_scrape_net_sound__physmatNames
    idx = get_material_id(string(name))


[es(tag=server, track=(human_net_phys__torsoContactMatId, isAlive))]
def human_collision_scrape_net_sound_track(evt : Event;
                                           human_net_phys__torsoContactMatId : int;
                                           human_collision_scrape_net_sound__physmatIds : IntList;
                                           var human_collision_scrape_sound__descIdx : int&;
                                           isAlive : bool)
  human_collision_scrape_sound__descIdx = isAlive ? find_index(human_collision_scrape_net_sound__physmatIds, human_net_phys__torsoContactMatId) : -1
