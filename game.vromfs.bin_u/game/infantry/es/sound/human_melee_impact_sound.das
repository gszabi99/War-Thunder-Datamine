require ecs
require soundEvent
require soundSystem
require strings
require sound_utils.modules.sound_physmat_common
require sound_utils.modules.sound_occlusion_common


[cpp_event(unicast)]
struct CmdStartActionSfx
  pos : float3
  norm : float3
  pmid : int


[es(tag=sound)]
def human_melee_impact_sound(evt : CmdStartActionSfx;
                             sound_preset__isLoaded : bool;
                             human_weap__currentGunEid : EntityId;
                             human_sound__prefix : string = "infantry/")
  if !sound_preset__isLoaded || !should_play(evt.pos)
    return
  let path = get_string(human_weap__currentGunEid, "meleeImpactSoundPath", "")
  if empty(path)
    return

  let smid = get_human_melee_impact_sound_material_id(evt.pmid)
  if smid < 0
    return

  oneshot("[mat={smid}]{human_sound__prefix}{path}", prevent_wall_sound_occlusion(evt.pos, evt.norm, get_listener_pos()))
