require ecs
require soundHash
require soundEvent
require human_sounds.modules.human_sounds_events
require sound_utils.modules.sound_utils_events
require common_sounds.modules.common_sounds_events
require sound_utils.modules.sound_player_common


[es(tag=sound, REQUIRE=humanSound, REQUIRE_NOT=deadEntity)]
def human_irq_sound(evt : CmdSoundIrq;
                    sound_preset__isLoaded : bool;
                    human_sound__prefix : string = "";
                    var sound_event_group : SoundEventGroup&;
                    @shared_comp sound_irqs : Object;
                    is_watched_sound : bool;
                    sound_tags : Object;
                    transform : float3x4)
  if evt.irqType == sound_hash("") && sound_preset__isLoaded
    sound_player_common::play_path(evt.irq, sound_irqs, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group, human_sound__prefix)


[es(tag=sound, REQUIRE=humanSound, REQUIRE_NOT=deadEntity)]
def human_irq_sound_voicefx(evt : CmdSoundVoicefxIrq;
                            sound_preset__isLoaded : bool;
                            var sound_event_group : SoundEventGroup&;
                            @shared_comp human_voice_sound__path : Object;
                            @shared_comp human_voice_sound__irqs : Object;
                            is_watched_sound : bool;
                            sound_tags : Object;
                            transform : float3x4)
  if sound_preset__isLoaded
    sound_player_common::play(evt.irq, human_voice_sound__path, human_voice_sound__irqs, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group)
