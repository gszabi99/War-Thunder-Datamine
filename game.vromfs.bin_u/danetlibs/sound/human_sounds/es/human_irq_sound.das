require app
require ecs
require ecs.safe
require soundHash
require soundEvent
require sound_utils.modules.sound_utils_events
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_sounds_events
require common_sounds.modules.common_sounds_events
require human_sounds.modules.human_voice_effect_common


[es(tag=sound, REQUIRE=humanSound, REQUIRE_NOT=deadEntity)]
def human_irq_sound(evt : CmdSoundIrq;
                    sound_preset__isLoaded : bool;
                    human_sound__prefix : string = "";
                    var sound_event_group : SoundEventGroup&;
                    @shared_comp sound_irqs : Object;
                    var sound_irqs__cooldown : Object&;
                    is_watched_sound : bool;
                    sound_tags : Object;
                    transform : float3x4)

  if evt.irqType != sound_hash("") || !sound_preset__isLoaded
    return
  let path = get_desc(sound_irqs, evt.irq)
  if path == null
    return
  if apply_cooldown(sound_irqs__cooldown, path?.cooldown ?? 0., evt.irq, get_sync_time())
    return
  let handle = play_path(*path, sound_tags, is_watched_sound, transform[3], false, 0., human_sound__prefix, 4)
  if handle != invalid_sound_event_handle()
    add_sound(sound_event_group, sound_hash(""), handle)


[es(tag=sound, REQUIRE=humanSound, REQUIRE_NOT=deadEntity)]
def human_irq_sound_voicefx(evt : CmdSoundVoicefxIrq;
                            eid : EntityId;
                            sound_preset__isLoaded : bool;
                            var sound_event_group : SoundEventGroup&;
                            @shared_comp human_voice_sound__path : Object;
                            @shared_comp human_voice_sound__irqs : Object;
                            human_speech__locale : string = "";
                            is_watched_sound : bool;
                            sound_tags : Object;
                            transform : float3x4)
  if sound_preset__isLoaded
    let desc = get_desc(human_voice_sound__irqs, evt.irq)
    if desc == null
      return
    let phrase = desc?.phrase ?? ""
    if !empty(phrase)
      sendEvent(eid, CmdHumanVoiceEffect(phrase = phrase))
    else
      play_voice(evt.irq, human_voice_sound__path, human_voice_sound__irqs, sound_tags, is_watched_sound, transform[3], sound_hash(""), sound_event_group, human_speech__locale)
