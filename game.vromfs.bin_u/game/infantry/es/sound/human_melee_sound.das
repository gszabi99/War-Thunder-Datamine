require ecs
require app
require ecs.safe
require ecs.common
require soundEvent
require soundHash
require sound_utils.modules.sound_player_common
require human_sounds.modules.human_sounds_events
require %game.sound.sound_events
require %game.events
require DagorRandom
require strings
require soundSystem

[cpp_event(unicast)]
struct CmdSoundMeleeIrq
  irq : string


def play_sound(name : string;
               path_obj : Object;
               sound_tags : Object;
               delay : float;
               is_watched_sound : bool;
               var sound_event_group : SoundEventGroup&;
               transform : float3x4;
               human_sound__prefix : string = "")
  var path : string
  if sound_player_common::get_option_path(path_obj, sound_tags, is_watched_sound, path)
    let handle = soundEvent::delayed_play(name, "{human_sound__prefix}{apply_watched_prefix(path, is_watched_sound)}", transform[3], delay)
    add_sound(sound_event_group, sound_hash(""), handle)


def human_melee_sound_delay_debug(delay : int;
                                  weapon : Object const?;
                                  sound_tags : Object;
                                  is_watched_sound : bool;
                                  var sound_event_group : SoundEventGroup&;
                                  transform : float3x4;
                                  human_sound__prefix : string)
  play_sound("", *weapon, sound_tags, float(delay) * 0.001, is_watched_sound, sound_event_group, transform, human_sound__prefix)


def take_a_chance(chance : int)
  return rnd_int(1, 100) <= chance


[es(tag=sound)]
def human_melee_sound_irq(evt : CmdSoundMeleeIrq;
                          eid : EntityId;
                          human_melee_sound__cooldown : float;
                          var human_melee_sound__nextTime : float&;
                          @shared_comp human_melee_sound__irqs : Object;
                          sound_tags : Object;
                          var sound_event_group : SoundEventGroup&;
                          is_watched_sound : bool;
                          human_weap__gunEids : EidList const?;
                          human_weap__currentGunSlot : int const?;
                          transform : float3x4;
                          human_sound__prefix : string = "infantry/")
  if get_sync_time() < human_melee_sound__nextTime
    return
  human_melee_sound__nextTime = get_sync_time() + human_melee_sound__cooldown

  if !is_watched_sound && !should_play(transform[3])
    return
  let gun = human_weap__gunEids != null && human_weap__currentGunSlot != null && *human_weap__currentGunSlot >= 0 ? (*human_weap__gunEids)[*human_weap__currentGunSlot] : INVALID_ENTITY_ID
  let meleeType : string = get_string(gun, "meleeSoundType", "hands")
  if empty(meleeType)
    return

  let irqObj = get_ecs_object(human_melee_sound__irqs, evt.irq)
  let weapon = (irqObj?.weapons ?as Object)?[meleeType] ?as Object
  if weapon == null
    return







  play_sound("", *weapon, sound_tags, float((*weapon).delay ?? 0) * 0.001, is_watched_sound, sound_event_group, transform, human_sound__prefix)

  if take_a_chance((*weapon).voiceChance ?? 100)
    sendEvent(eid, CmdHumanVoiceEffect(phrase = "melee"))

  let secondary = (*weapon).secondary ?as Object
  if secondary != null





    play_sound("", *secondary, sound_tags, float((*secondary).delay ?? 0) * 0.001, is_watched_sound, sound_event_group, transform, human_sound__prefix)
