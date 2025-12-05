require ecs
require app 
require soundHash
require soundEvent
require vehicle_sounds_net.modules.vehicle_sounds_net_events
require sound_utils.modules.sound_player_common
require DngNet


[es(tag=sound, on_event=(EventExplosionFatal, EventCrashExplosionFatal))]
def vehicle_damage_sound_explosion_fatal(evt : Event;
                                         sound_preset__isLoaded : bool;
                                         @shared_comp vehicle_damage_sound__paths : Object;
                                         sound_tags : Object;
                                         is_watched_sound : bool;
                                         transform : float3x4)
  if sound_preset__isLoaded
    sound_player_common::play_path("destroy", vehicle_damage_sound__paths, sound_tags, is_watched_sound, transform[3])


[es(tag=sound, track=isExploded, REQUIRE=vehicleSound)]
def vehicle_damage_sound_explode(evt : Event; eid : EntityId;
                                 isExploded : bool)
  if isExploded
    send_net_event(eid, CmdPlayVehicleDamageSound(hash = sound_hash("destroy"), time = get_sync_time()))
