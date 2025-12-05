require ecs
require app 
require soundEvent
require soundHash
require soundSystem
require sound_utils.modules.sound_player_common
require sound_utils_net.modules.sound_desc_common
require vehicle_sounds_net.modules.vehicle_sounds_net_events


let MAX_NET_LATENCY = 2.

[es(tag=sound, REQUIRE=vehicleSoundControlEnabled)]
def play_vehicle_damage_sound(evt : CmdPlayVehicleDamageSound;
                              @shared_comp vehicle_damage_sound__paths : Object;
                              sound_tags : Object;
                              is_watched_sound : bool;
                              transform : float3x4;
                              var sound_event_group : SoundEventGroup&)
  if get_sync_time() < evt.time + MAX_NET_LATENCY
    let path = find_desc_by_hash(evt.hash, vehicle_damage_sound__paths)
    if path != null
      let handle = sound_player_common::play_path(*path, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)
      set_var_optional(handle, "damage", evt.relHp)
    else
      sound_debug("there is no path '{evt.hash}' in vehicle_damage_sound__paths")
