require ecs
require ecs.safe
require soundEvent
require soundSystem
require sound_utils.modules.sound_player_common
require %appGame.infantry.es.sound.gun_sound_common
require strings

def gather_gun_shot_paths(shot_path : Object; is_watched : bool; var paths : array<string>&)
  for idx in range(0, get_num_option_paths(shot_path))
    paths |> push(make_gun_shot_sound_grain_path_str(shot_path, idx, is_watched))


def gather_gun_reload_paths(reload_path : Object; is_watched : bool; var paths : array<string>&)
  for it in reload_path
    let irqObj = it.value as Object
    if irqObj != null
      for idx in range(0, get_num_option_paths(*irqObj))
        paths |> push(make_final_path_str(*irqObj, idx, is_watched))


def human_preload_gun_sounds(gun_eid : EntityId;
                             is_watched : bool;
                             var preload : SoundEventsPreload&)
  var paths : array<string>

  if sound_banks_is_master_preset_loaded()
    query(gun_eid) <| $ [es] (@shared_comp gun_sound__shotPath : Object)
      gather_gun_shot_paths(gun_sound__shotPath, is_watched, paths)

  if !empty(paths)
    preload |> sound_events_load(paths)



[es(tag=sound, on_appear, track=(human_weap__currentGunEid, human_attached_gun__attachedGunEid), REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity, on_event=EventOnMasterSoundPresetLoaded)]
def human_gun_sounds_preload(evt : Event;
                             human_weap__currentGunEid : EntityId;
                             human_attached_gun__attachedGunEid : EntityId;
                             var human_gun_sounds_preload : SoundEventsPreload&)

  let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
  human_preload_gun_sounds(gunEid, true, human_gun_sounds_preload)


[es(tag=sound, on_appear, track=gun__owner)]
def human_gun_sounds_preload_on_gun_appear(evt : Event;
                                           eid : EntityId;
                                           gun__owner : EntityId)

  query(gun__owner) <| $ [es(REQUIRE=watchedByPlr, REQUIRE_NOT=deadEntity)] (human_weap__currentGunEid : EntityId;
                                                                             human_attached_gun__attachedGunEid : EntityId;
                                                                             var human_gun_sounds_preload : SoundEventsPreload&)

    let gunEid = human_attached_gun__attachedGunEid != INVALID_ENTITY_ID ? human_attached_gun__attachedGunEid : human_weap__currentGunEid
    if gunEid == eid
      human_preload_gun_sounds(gunEid, true, human_gun_sounds_preload)
