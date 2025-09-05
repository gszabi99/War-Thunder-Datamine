require ecs
require Unit
require soundEvent
require soundSystem
require DagorSystem
require app
require DagorConsole
require Sound

[es(tag=gameClient, tag=sound, no_order)]
def sound_point_update_client_es(act : UpdateStageInfoAct;
                                 transform : float3x4;
                                 sound_point__event_name : string;
                                 sound_point__vol : float;
                                 var sound_point__event : SoundEvent&;
                                 sound_point__near_dist : float)

  if length(transform[3] - get_listener_pos()) < sound_point__near_dist
    if !is_playing(sound_point__event)
      sound_point__event |> play(sound_point__event_name, transform[3])
      if sound_point__vol != 1.
        set_volume(sound_point__event, sound_point__vol)
  elif is_playing(sound_point__event)
    abandon(sound_point__event)

[es(on_appear, tag=gameClient, tag=sound)]
def sound_point_constant_init(evt : Event;
                              var sound_point__length : float&;
                              sound_point__event_name : string)
  sound_point__length = float(get_length(sound_point__event_name))
  if (!is_mod_enabled() && sound_point__event_name != "" && sound_point__length <= 0.f)
    logerr("sound point {sound_point__event_name} has zero length")


[es(on_appear, tag=gameClient, tag=sound)]
def sound_radio_localized(evt : Event;
                          var sound_radio_localized__lang : int&)
  let gameLang = string(get_game_language())
  if gameLang == "Russian"
    sound_radio_localized__lang = 1
  elif gameLang == "Chinese"
    sound_radio_localized__lang = 2
  else
    sound_radio_localized__lang = 0

[es(tag=gameClient, tag=sound, no_order)]
def sound_radio_localized_update_client_es(act : UpdateStageInfoAct;
                                           sound_point__event : SoundEvent;
                                           sound_radio_localized__lang : int)
  if is_playing(sound_point__event)
    sound_point__event |> set_var_optional("lang", float(sound_radio_localized__lang))


[es(tag=gameClient, tag=sound, no_order)]
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
      sound_point__event |> play(sound_point__event_name, transform[3])
      sound_point__event |> set_timeline_position(int(sound_point__timeline_pos))
      if sound_point__vol != 1.
        set_volume(sound_point__event, sound_point__vol)
  elif is_playing(sound_point__event)
    sound_point__timeline_pos = float(sound_point__event |> get_timeline_position())
    abandon(sound_point__event)

[es(tag=gameClient, tag=sound, no_order)]
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
      sound_point__event |> play(sound_point__event_name, transform[3])
      if sound_point__vol != 1.
        set_volume(sound_point__event, sound_point__vol)
      sound_point_one_shot_played = true
  if sound_point_one_shot_played && !is_playing(sound_point__event)
    abandon(sound_point__event)
    destroyEntity(eid)

