require ecs
require soundHash
require soundEvent
require sound_utils.modules.sound_player_common


[es(tag=sound, on_appear, track=(is_watched_sound, sound_preset__isLoaded, isAlive, isDowned, hasConcussedSound))]
def concussion_sound_appear(evt : Event;
                            hasConcussedSound : bool;
                            isAlive : bool;
                            @shared_comp human_voice_sound__path : Object;
                            @shared_comp human_voice_sound__descs : Object;
                            sound_tags : Object;
                            is_watched_sound : bool;
                            sound_preset__isLoaded : bool;
                            isDowned : bool;
                            transform : float3x4;
                            var sound_event_group : SoundEventGroup&)
  if hasConcussedSound && is_watched_sound && sound_preset__isLoaded && isAlive && !isDowned
    if !has_sound(sound_event_group, sound_hash("concussed"))
      sound_player_common::play("concussed", human_voice_sound__path, human_voice_sound__descs, sound_tags, is_watched_sound, transform[3], sound_hash("concussed"), sound_event_group)
  else
    reject_sound(sound_event_group, sound_hash("concussed"))
