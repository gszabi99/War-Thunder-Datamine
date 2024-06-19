require ecs
require Unit
require soundEvent
require soundSystem
require DagorSystem

[es(tag=gameClient, tag=sound)]
def sound_point_update_client_es(act : UpdateStageInfoAct;
                                 transform : float3x4;
                                 sound_point__event_name : string;
                                 sound_point__vol : float;
                                 var sound_point__event : SoundEvent&;
                                 sound_point__near_dist : float)

  if length(transform[3] - get_listener_pos()) < sound_point__near_dist
    if !is_playing(sound_point__event)
      sound_point__event |> play(sound_point__event_name, transform[3], sound_point__vol)
  elif is_playing(sound_point__event)
    abandon(sound_point__event)

[es(on_appear, tag=gameClient, tag=sound)]
def sound_point_constant_init(evt : Event;
                              eid : EntityId;
                              var sound_point__length : float&;
                              sound_point__event_name : string)
  sound_point__length = float(get_length(sound_point__event_name))
  if (sound_point__length <= 0.f)
    logerr("sound point {sound_point__event_name} has zero length")
    destroyEntity(eid)

[es(tag=gameClient, tag=sound)]
def sound_point_constant_update_client_es(act : UpdateStageInfoAct;
                                          transform : float3x4;
                                          sound_point__length : float;
                                          sound_point__event_name : string;
                                          var sound_point__event : SoundEvent&;
                                          sound_point__vol : float;
                                          var sound_point__timeline_pos : float&;
                                          sound_point__near_dist : float)
  sound_point__timeline_pos += act.dt * 1000.f
  if (sound_point__timeline_pos >= sound_point__length)
    sound_point__timeline_pos = 0.f
  if length(transform[3] - get_listener_pos()) < sound_point__near_dist
    if !is_playing(sound_point__event)
      sound_point__event |> play(sound_point__event_name, transform[3], sound_point__vol)
      sound_point__event |> set_timeline_position(int(sound_point__timeline_pos))
  elif is_playing(sound_point__event)
    sound_point__timeline_pos = float(sound_point__event |> get_timeline_position())
    abandon(sound_point__event)

[es(tag=gameClient, tag=sound)]
def sound_point_one_shot_update_client_es(act : UpdateStageInfoAct;
                                          eid : EntityId;
                                          transform : float3x4;
                                          sound_point__event_name : string;
                                          var sound_point_one_shot_played : bool&;
                                          sound_point__vol : float;
                                          var sound_point__event : SoundEvent&;
                                          sound_point__near_dist : float)
  if length(transform[3] - get_listener_pos()) < sound_point__near_dist
    if !sound_point_one_shot_played
      sound_point__event |> play(sound_point__event_name, transform[3], sound_point__vol)
      sound_point_one_shot_played = true
  if sound_point_one_shot_played && !is_playing(sound_point__event)
    abandon(sound_point__event)
    destroyEntity(eid)