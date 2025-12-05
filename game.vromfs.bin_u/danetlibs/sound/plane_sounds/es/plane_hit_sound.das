require ecs
require ecs.common
require sound_utils.modules.sound_player_common
require sound_utils.modules.sound_control_common
require vehicle_sounds_net.modules.vehicle_sounds_net_events
require soundSystem
require soundEvent
require soundHash
require CollRes
require DagorSystem
require DagorMath


def convert_caliber_to_(v : float; r : float4)
  return cvt(v, r.x, r.y, r.z, r.w)


def on_hit(caliber : float; local_pos : float3;
           path_id : string;
           @shared_comp plane_hit_sound__paths : Object;
           sound_tags : Object;
           is_watched_sound : bool;
           transform : float3x4;
           sound_control__state : int;
           caliber_to_dist : float4;
           caliber_to_var : float4;
           var group : SoundEventGroup&)
  let maxDist = convert_caliber_to_(caliber, caliber_to_dist)
  if have_sound(sound_control__state) && (is_watched_sound || length_sq(get_listener_pos() - transform * local_pos) < maxDist * maxDist)
    var handle = sound_player_common::play_path(path_id, plane_hit_sound__paths, sound_tags, is_watched_sound, transform * local_pos, false)
    set_var(handle, "cal", convert_caliber_to_(caliber, caliber_to_var))
    if is_watched_sound
      add_sound(group, sound_hash(""), local_pos, handle, 4)
    else
      abandon(handle)


[es(tag=sound, REQUIRE=watchedByPlr)]
def plane_hit_sound_projectile(evt : CmdPlayProjectileHitSound; human_anim__vehicleSelected : EntityId)
  query(human_anim__vehicleSelected) <| $ [es] (@shared_comp plane_hit_sound__paths : Object;
                                                sound_tags : Object;
                                                is_watched_sound : bool;
                                                transform : float3x4;
                                                sound_control__state : int;
                                                plane_hit_sound__caliberToDist : float4;
                                                plane_hit_sound__caliberToVar : float4;
                                                var sound_event_group : SoundEventGroup&;
                                                plane_hit_sound__canopyNodeIds : IntList const?)
    on_hit(evt.caliber, evt.localHitPos,
          (plane_hit_sound__canopyNodeIds != null && find_index(*plane_hit_sound__canopyNodeIds, evt.nodeId) >= 0) ? "hitGlass" : "hit",
          plane_hit_sound__paths,
          sound_tags,
          is_watched_sound,
          transform,
          sound_control__state,
          plane_hit_sound__caliberToDist,
          plane_hit_sound__caliberToVar,
          sound_event_group)


[es(tag=sound)]
def plane_hit_sound_ricochet(evt : CmdPlayProjectileRicochetSound; human_anim__vehicleSelected : EntityId)
  query(human_anim__vehicleSelected) <| $ [es] (@shared_comp plane_hit_sound__paths : Object;
                                                sound_tags : Object;
                                                is_watched_sound : bool;
                                                transform : float3x4;
                                                sound_control__state : int;
                                                plane_hit_sound__caliberToDist : float4;
                                                plane_hit_sound__caliberToVar : float4;
                                                var sound_event_group : SoundEventGroup&)
    on_hit(evt.caliber, evt.localHitPos,
          "ricochet",
          plane_hit_sound__paths,
          sound_tags,
          is_watched_sound,
          transform,
          sound_control__state,
          plane_hit_sound__caliberToDist,
          plane_hit_sound__caliberToVar,
          sound_event_group)


[es(tag=sound, on_event=EventOnCollisionHit)]
def plane_hit_sound_collision(evt : Event;
                              @shared_comp plane_hit_sound__paths : Object;
                              sound_tags : Object;
                              is_watched_sound : bool;
                              transform : float3x4;
                              sound_control__state : int)
  if have_sound(sound_control__state) && is_watched_sound
    sound_player_common::play_path("collision", plane_hit_sound__paths, sound_tags, is_watched_sound, transform[3])


[es(tag=sound, on_appear)]
def plane_hit_sound_created(evt : Event;
                            eid : EntityId;
                            collres : CollisionResource;
                            plane_hit_sound__canopyNodes : StringList;
                            var plane_hit_sound__canopyNodeIds : IntList&)
  for nodeName in plane_hit_sound__canopyNodes
    let nodeIdx = collres_get_node_index_by_name(collres, string(nodeName))
    if nodeIdx < 0
      logerr("Canopy node {nodeName} was not found in {eid} <{getEntityTemplateName(eid)}>")
    else
      push(plane_hit_sound__canopyNodeIds, nodeIdx)
