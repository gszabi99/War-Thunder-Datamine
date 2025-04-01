require ecs


[es(tag=server, on_disappear)]
def human_weap_destroy_es(evt : Event;
                          var human_weap__gunEids : EidList&;
                          var human_weap__gunMods : Array&)
  for i in iter_range(human_weap__gunEids)
    destroyEntity(human_weap__gunEids[i])
    human_weap__gunEids[i] = INVALID_ENTITY_ID
  for i in iter_range(human_weap__gunMods)
    var gunModEids = getRW_ecs_EidList(human_weap__gunMods[i])
    for gunMod in *gunModEids
      destroyEntity(gunMod)
    clear(*gunModEids)
