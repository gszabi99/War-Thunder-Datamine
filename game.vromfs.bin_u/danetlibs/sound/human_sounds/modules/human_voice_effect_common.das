module human_voice_effect_common shared

require ecs
require ecs.safe
require soundEvent
require sound_utils.modules.sound_player_common


def get_top_active_effect(active_effects : Object; all_ordered_effects : StringList) : string
  for effect in all_ordered_effects
    if active_effects[string(effect)] ?? false
      return string(effect)
  return ""


def has_human_voice_effect(active_effects : Object; effect : string) : bool
  return active_effects[effect] ?? false


def set_human_voice_effect(name : string; enable : bool; var active_effects : Object&; all_ordered_effects : StringList)
  if enable != (active_effects[name] ?? false)
    let isTop = name == get_top_active_effect(active_effects, all_ordered_effects)
    active_effects |> set(name, enable)
    return isTop || name == get_top_active_effect(active_effects, all_ordered_effects)
  return false


def set_human_voice_effect(name : string; enable : bool; var active_effects : Object&)
  if enable != (active_effects[name] ?? false)
    active_effects |> set(name, enable)


def raise_human_voice_effect(name : string; var active_effects : Object&)
  set_human_voice_effect(name, true, active_effects)


def clear_human_voice_effect(name : string; var active_effects : Object&)
  set_human_voice_effect(name, false, active_effects)


def get_voice_loc_path(human_voice_sound__path : Object&; locale : string) : Object const?
  return human_voice_sound__path["loc_{locale}"] ?as Object


def play_voice(desc_id : string;
               path_obj : Object;
               descs : Object;
               tags : Object;
               is_watched_sound : bool;
               pos : float3;
               locale : string;
               is_abandon : bool = true)
  let locPath = get_voice_loc_path(path_obj, locale)
  return play(desc_id, locPath != null ? *locPath : path_obj, descs, tags, is_watched_sound, pos, is_abandon)

def play_voice(desc_id : string;
               path_obj : Object;
               descs : Object;
               tags : Object;
               is_watched_sound : bool;
               pos : float3;
               id : uint;
               var group : SoundEventGroup&;
               locale : string)
  let locPath = get_voice_loc_path(path_obj, locale)
  return play(desc_id, locPath != null ? *locPath : path_obj, descs, tags, is_watched_sound, pos, id, group)
