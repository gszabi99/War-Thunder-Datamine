require ecs
require ecs.safe
require ecs.common
require app
require soundEvent
require soundHash

require %appGame.wt_events
require %appGame.infantry.es.hitpoints_common
require sound_utils.modules.sound_player_common
require strings


def damage_type_to_sound_path(damage_type : int)
  if damage_type == int(DamageType.DM_MELEE) || damage_type == int(DamageType.DM_BACKSTAB)
    return "hit_dmgMelee"
  if damage_type == int(DamageType.DM_EXPLOSION)
    return "hit_dmgExplosion"
  if damage_type == int(DamageType.DM_HOLD_BREATH)
    return "hit_dmgAsphyxiation"
  if damage_type == int(DamageType.DM_GAS)
    return "hit_dmgGas"
  return ""


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)


def play_shatter_sounds(var count : int; var delay_first_next_last : float3; pos : float3; human_hit_sound__paths, sound_tags : Object; is_watched_sound : bool)
  let obj = human_hit_sound__paths["shatter"] ?as Object
  if obj != null
    var path : string
    if get_option_path(obj, sound_tags, is_watched_sound, path)
      while count-- != 0
        delayed_oneshot(path, pos, delay_first_next_last.x)
        delay_first_next_last.x = delay_first_next_last.y
        delay_first_next_last.y = delay_first_next_last.z


def get_max_net_delay_threshold()
  return 3.

[es(tag=sound, REQUIRE_NOT=shootingRangeDummy)]
def human_hit_sound(evt : CmdHumanHitNetSound;
                    sound_preset__isLoaded : bool;
                    @shared_comp human_hit_sound__paths : Object;
                    human_hit_sound__shattersDelayFirstNextLast : float3;
                    is_watched_sound : bool;
                    sound_tags : Object;
                    var sound_event_group : SoundEventGroup&;
                    dm_parts__type : StringList const?;
                    dm_parts__partsArmor : FloatList const?;
                    isAlive : bool;
                    transform : float3x4;
                    human_hit_sound__prefix = "infantry/")
  if get_sync_time() > evt.time + get_max_net_delay_threshold() || !sound_preset__isLoaded
    return

  assume hitPos = transform[3]
  var overrideOffenderPath = false
  query(evt.offender) <| $ [es] (@shared_comp offender_hits_human_sound__path : Object)
    sound_player_common::play_path(offender_hits_human_sound__path, sound_tags, is_watched_sound, hitPos)
    overrideOffenderPath = true
  if overrideOffenderPath
    return

  if evt.damageType != int(DamageType.DM_PROJECTILE)
    var name, path : string
    
    
    
    
    if empty(path)
      path = damage_type_to_sound_path(evt.damageType)

    var pathObj = !empty(path) ? (human_hit_sound__paths[path] ?as Object) : null
    if pathObj != null
      let collNodeId = evt.collNodeId
      if dm_parts__type != null && uint(collNodeId) < uint(length(*dm_parts__type))
        let part = get_desc(*pathObj, "part_{(*dm_parts__type)[collNodeId]}")
        pathObj = part != null ? part : pathObj

      if get_option_path(pathObj, sound_tags, is_watched_sound, path)
        if empty(name)
          name = (*pathObj).name ?? ""
        if !starts_with(path, "[")
          path =  "{human_hit_sound__prefix}{apply_watched_prefix(path, is_watched_sound)}"
        var handle = play_name_path_impl(name, path, hitPos, false)
        if evt.damageType == int(DamageType.DM_MELEE) || evt.damageType == int(DamageType.DM_BACKSTAB)
          if isAlive && is_armored(dm_parts__partsArmor, collNodeId, sound_tags)
            set_var_optional(handle, "armored", 1.)
        let localPos = inverse(transform) * hitPos
        if keyoff(handle)
          add_sound(sound_event_group, sound_hash("hit"), localPos, handle, 4)
          
          
          
        else
          abandon(handle)

    
    if evt.damageType == int(DamageType.DM_EXPLOSION)
      let maxShatters = 3
      let numShatters = min(evt.shatterCount, maxShatters)
      if numShatters > 0
        play_shatter_sounds(numShatters, human_hit_sound__shattersDelayFirstNextLast, transform[3], human_hit_sound__paths, sound_tags, is_watched_sound)


[es(tag=sound, REQUIRE=(humanSound, is_watched_sound, isAlive, sound_preset__isLoaded), track=(is_watched_sound, isAlive, sound_preset__isLoaded))]
def human_hit_sound_release_immediately(evt : Event;
                                        var sound_event_group : SoundEventGroup&)
  release_sound(sound_event_group, sound_hash("hit"))
