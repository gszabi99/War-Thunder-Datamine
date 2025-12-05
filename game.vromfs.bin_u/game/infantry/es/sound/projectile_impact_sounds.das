require ecs
require ecs.safe
require math
require math.base
require %appGame.infantry.es.team_common
require %appGame.infantry.es.hit_result_common
require %appGame.infantry.es.hitpoints_common

require %appGame.wt_events
require %game.dm.dm_events
require %game.unit.unit_proximity_damage_events
require human_net_speech.modules.human_net_speech_request_common
require sound_utils.modules.sound_player_common
require soundEvent
require soundSystem
require soundHash
require strings
require PropsManager
require BallisticsProps
require Weapon


def is_armored(parts_armor : FloatList const?; node_id : int; sound_tags : Object)
  return parts_armor != null ? (node_id >= 0 && node_id < length(*parts_armor) && (*parts_armor)[node_id] != 0.) : read_sound_tag("armored", sound_tags)

[es(tag=sound, after=on_entity_hit, REQUIRE_NOT=shootingRangeDummy)]
def projectile_impact_sounds_on_intersected_entity_with_hp(evt : EventOnHitEntity;
                                                           @shared_comp entity_intersected_with_projectile_sound__paths : Object;
                                                           is_watched_sound : bool = false;
                                                           human_sound__prefix : string = "infantry/";
                                                           sound_tags : Object;
                                                           dm_parts__type : StringList const?;
                                                           projectile_sound__shellCaliberThreshold : float;
                                                           dm_parts__partsArmor : FloatList const?)
  let projectile__stopped : bool = evt.impactRes == int(ImpactResult.STOP)
  let projectile__exploded : bool = false

  let projPropsId = PropsId(evt.packedProjPropsId)
  get_props_ProjBallisticsProperties(projPropsId) <| $(props : ProjBallisticsProperties)
    let isShell = props.caliber >= projectile_sound__shellCaliberThreshold

    assume __paths = entity_intersected_with_projectile_sound__paths

    let bulletShellPath = isShell ? (__paths.shell ?as Object) : (__paths.bullet ?as Object)
    var path = projectile__exploded ? (bulletShellPath?.exploded ?as Object) : projectile__stopped ? (bulletShellPath?.stopped ?as Object) : bulletShellPath
    path = path != null ? path : bulletShellPath

    if path != null

      if dm_parts__type != null && uint(evt.collNodeId) < uint(length(*dm_parts__type))
        let part = get_desc(*path, "part_{(*dm_parts__type)[evt.collNodeId]}")
        path = part != null ? part : path

      if sound_banks_is_master_preset_loaded()
        var handle = sound_player_common::play_path(*path, sound_tags, is_watched_sound, evt.pos, false, 0.f, human_sound__prefix)
        if is_armored(dm_parts__partsArmor, evt.collNodeId, sound_tags)
          set_var_optional(handle, "armored", 1.)
        abandon(handle)
