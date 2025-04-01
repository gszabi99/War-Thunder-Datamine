require ecs

[es(track=(human_weap__currentGunSlot, human_weap__gunMods, human_weap__gunEids))]
def human_weap_update_current_gun_es(evt : Event;
                                     human_weap__currentGunSlot : int;
                                     var human_weap__currentGunEid : EntityId&;
                                     var human_weap__currentGunModEids : EidList&;
                                     human_weap__gunMods : Array;
                                     human_weap__gunEids : EidList)
  let slot = human_weap__currentGunSlot
  human_weap__currentGunEid = slot >= 0 ? human_weap__gunEids[slot] : ecs::INVALID_ENTITY_ID;
  if has(human_weap__currentGunEid, "onlyIntegratedGunMod")
    clear(human_weap__currentGunModEids)
    push(human_weap__currentGunModEids, human_weap__currentGunEid)
  elif slot >= 0
    let gunModEids = get_ecs_EidList(human_weap__gunMods[slot]);
    resize(human_weap__currentGunModEids, length(*gunModEids))
    for i in iter_range(*gunModEids)
      human_weap__currentGunModEids[i] = (*gunModEids)[i]
  else
    clear(human_weap__currentGunModEids)
