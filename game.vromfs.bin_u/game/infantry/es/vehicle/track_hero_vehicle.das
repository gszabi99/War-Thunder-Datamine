require ecs


def clear_other_hero_vehicles(except_eid : EntityId)
  query() <| $ [es(REQUIRE=heroVehicle)] (eid : EntityId)
    if eid != except_eid
      removeSubTemplate(eid, "heroVehicle")


[es(tag=gameClient, REQUIRE=(watchedByPlr, unit_tag__tank), on_appear)]
def hero_tank_set_hero_vehicle_es(evt : Event; eid : EntityId)
  clear_other_hero_vehicles(eid)
  if !has(eid, "heroVehicle")
    addSubTemplate(eid, "heroVehicle")

[es(tag=gameClient, REQUIRE=(watchedByPlr, unit_tag__tank), on_disappear)]
def hero_tank_clear_hero_vehicle_es(evt : Event; eid : EntityId)
  if has(eid, "heroVehicle")
    removeSubTemplate(eid, "heroVehicle")


[es(tag=gameClient, REQUIRE=(watchedByPlr, unit_tag__human),
    track=human_anim__vehicleSelected, on_appear)]
def hero_human_track_vehicle_es(evt : Event;
                                human_anim__vehicleSelected : EntityId)
  clear_other_hero_vehicles(human_anim__vehicleSelected)
  if human_anim__vehicleSelected != INVALID_ENTITY_ID
    addSubTemplate(human_anim__vehicleSelected, "heroVehicle")

[es(tag=gameClient, REQUIRE=(watchedByPlr, unit_tag__human), on_disappear)]
def hero_human_clear_vehicle_es(evt : Event;
                                human_anim__vehicleSelected : EntityId)
  if human_anim__vehicleSelected != INVALID_ENTITY_ID
    removeSubTemplate(human_anim__vehicleSelected, "heroVehicle")
