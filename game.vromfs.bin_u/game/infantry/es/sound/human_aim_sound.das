require ecs
require ecs.common
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, track=human_net_phys__isAiming)]
def human_aim_sound(evt : Event;
                    sound_preset__isLoaded : bool;
                    human_net_phys__isAiming : bool;
                    human_weap__currentGunEid : EntityId;
                    var sound_event_group : SoundEventGroup&;
                    sound_tags : Object;
                    is_watched_sound : bool;
                    transform : float3x4)
  if sound_preset__isLoaded
    query(human_weap__currentGunEid) <| $ [es] (@shared_comp gun_aim_sound__onPath : Object; @shared_comp gun_aim_sound__offPath : Object)
      sound_player_common::play_path(human_net_phys__isAiming ? gun_aim_sound__onPath : gun_aim_sound__offPath, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)
  if is_watched_sound
    set_var_global("aiming", human_net_phys__isAiming ? 1. : 0.)
