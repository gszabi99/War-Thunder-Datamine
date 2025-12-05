require ecs
require %game.events

[es(tag=render, no_order, REQUIRE=cockpitEntity)]
def reset_current_entity_with_scope_eid_es(info : ParallelUpdateFrameDelayed;
                                           var attached_gun_scope__currentEid : EntityId&)
  attached_gun_scope__currentEid = INVALID_ENTITY_ID


[es(tag=render, after=reset_current_entity_with_scope_eid_es,
  before=update_camera_common_aim_parameters_es, REQUIRE=cockpitEntity)]
def update_human_entity_with_scope_eid_es(info : ParallelUpdateFrameDelayed;
                                          human_weap__currentGunModEids : EidList;
                                          human_weap__currentGunEid : EntityId;
                                          var attached_gun_scope__currentEid : EntityId&)
  
  
    

  if get_bool(human_weap__currentGunEid, "gunmod__lensActive") ?? false
    attached_gun_scope__currentEid = human_weap__currentGunEid
  else
    for eid in human_weap__currentGunModEids
      if get_bool(eid, "gunmod__lensActive") ?? false
        attached_gun_scope__currentEid = eid
        break


[es(tag=render, after=reset_current_entity_with_scope_eid_es,
  before=update_camera_common_aim_parameters_es, REQUIRE=(cockpitEntity, planeCockpit))]
def update_plane_entity_with_scope_eid_es(info : ParallelUpdateFrameDelayed;
                                          eid : EntityId;
                                          var attached_gun_scope__currentEid : EntityId&)
  attached_gun_scope__currentEid = eid
