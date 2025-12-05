require ecs
require soundSystem
require soundEvent
require weapon_sounds.modules.weapon_sounds_events
require sound_utils.modules.sound_physmat_common
require sound_utils.modules.sound_occlusion_common


[es(tag=sound)]
def human_melee_impact_sound(evt : CmdStartActionSfx;
                             human_melee_impact_sound__path : string;
                             human_weap__gunEids : EidList const?;
                             human_weap__currentGunSlot = -1)
  if has(evt.targetEid, "humanHitSound") || has(evt.targetEid, "human")
    return
  let smid = max(0, get_human_melee_impact_sound_material_id(evt.pmid))
  var path = human_melee_impact_sound__path
  if human_weap__gunEids != null && human_weap__currentGunSlot >= 0 && human_weap__currentGunSlot < length(*human_weap__gunEids)
    let gunEid = (*human_weap__gunEids)[human_weap__currentGunSlot]
    query(gunEid) <| $ [es] (meleeImpactSoundPath : string)
      path = meleeImpactSoundPath
  oneshot("[mat={smid}]{path}", prevent_wall_sound_occlusion(evt.pos, evt.norm, get_listener_pos()))
