module human_voice_effect_common shared

require ecs
require ecs.safe


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
