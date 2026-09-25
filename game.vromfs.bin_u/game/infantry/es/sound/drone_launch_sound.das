require ecs
require soundEvent
require sound_utils_net.modules.sound_desc_common


[es(tag=sound, track=drone_launcher_anim__launchInProgress)]
def drone_launch_sound(evt : Event;
                       gun__owner : EntityId;
                       drone_launcher_anim__launchInProgress : bool;
                       drone_launch_sound__path : string)
  if !drone_launcher_anim__launchInProgress || empty(drone_launch_sound__path)
    return
  query(gun__owner) <| $ [es] (is_watched_sound : bool;
                               transform : float3x4;
                               human_sound__prefix : string = "infantry/")
    oneshot("{human_sound__prefix}{get_watched_sound_event_folder(is_watched_sound)}/{drone_launch_sound__path}", transform[3])
